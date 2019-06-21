#!/usr/bin/env ruby
# typed: ignore
#
# PLATIN tool set
#
# Simple visualizer (should be expanded to do proper report generation)
#
require 'json'

require 'set'
require 'platin'
require 'analysis/scopegraph'
require 'tools/visualize'
require 'tools/visualize-ilp'
require 'tools/visualisationserver'

include PML

begin
  require 'rubygems'
  require 'graphviz'
rescue Exception => details
  warn "Failed to load library graphviz"
  info "  ==> gem1.9.1 install ruby-graphviz"
  die "Failed to load required ruby libraries"
end

class ILPVisualisation < Visualizer

  INFEASIBLE_COLOUR = 'red'
  INFEASIBLE_FILL   = '#e76f6f'
  WORST_CASE_PATH_COLOUR = '#f00000'

  attr_reader :ilp

  def initialize(ilp, levels)
    @ilp = ilp
    @levels = levels
    @graph = nil
    @mapping = {}
    @subgraph = {}
    @functiongraphs = {}
    @srchints = {}
  end

  def get_subgraph(variable)
    level = get_level(variable)
    graph = subgraph_by_level(level)

    if variable.respond_to?(:function) && variable.function
      fun = variable.function
      if @functiongraphs.has_key?(fun)
        graph = @functiongraphs[fun]
      else
        sub = graph.subgraph("cluster_function_#{@functiongraphs.size}")
        @functiongraphs[fun] = sub
        sub[:label] = fun.inspect
        graph = sub
      end
    end
    graph
  end

  def subgraph_by_level(level)
    entry = @subgraph[level]
    return entry if entry
    sub = @graph.subgraph("cluster_#{level}")
    @subgraph[level] = sub
    sub[:label] = level
    sub
  end

  def get_level(var)
    if var.respond_to?(:level)
      return var.level
    elsif var.respond_to?(:function) && var.function.respond_to?(:level)
      return var.function.level
    else
      STDERR.puts "Cannot infer level for #{var}"
      return "unknown"
    end
  end

  def get_srchint(variable)
    if variable.respond_to?(:src_hint)
      src_hint = variable.src_hint
      return nil if src_hint.nil?

      file, _, line = src_hint.rpartition(':')
      assert("Failed to parse src_hint #{src_hint}, expecting file:line") { file && line}
      hint = {
        :file => file,
        :line => line,
      }

      if variable.respond_to?(:function)
        hint[:function] = variable.function.to_s
      end

      return hint
    end
    nil
  end

  def add_srchint(id, var)
    # sourcehints
    unless @srchints.has_key?(id)
      hint = get_srchint(var)
      @srchints[id] = hint unless hint.nil?
    end

    hint
  end

  def get_srchints
    @srchints
  end

  def to_label(var)
    l = []
    if var.respond_to?(:qname)
      l << "<U>#{var.qname}</U>"
    end
    if var.respond_to?(:mapsto)
      l << "<B>#{var.mapsto}</B>"
    end
    if var.respond_to?(:src_hint)
      l << var.src_hint
    end
    if var.respond_to?(:loopheader?) && var.loopheader?
      l << '<I>loopheader</I>'
    end
    str = l.join("<BR/>");
    # return "unknown" if str.empty?
    if str.empty?
      # return var.class.name
      return var.to_s
    end
    return '<' + str + '>'
  end

  def add_node(variable)
    key = variable
    node = @mapping[key]
    return node if node

    g = get_subgraph(variable)

    nname = "n" + @mapping.size.to_s
    node = g.add_nodes(nname, :id => nname, :label => to_label(variable), :tooltip => variable.to_s)
    @mapping[key] = node

    add_srchint(nname, variable)

    case variable
    when Function
      node[:shape] = "cds"
      entry = add_node(variable.entry_block)
      @graph.add_edges(node, entry, :style => 'bold')
    when Block
      node[:shape] = "box"
    when Instruction
      node[:shape] = "ellipse"
      block = add_node(variable.block)
      @graph.add_edges(block, node, :style => 'dashed')
    else
      node[:shape] = "Mdiamond"
    end

    node
  end

  def add_edge(edge, cost = nil)
    key = edge
    node = @mapping[key]
    return node if node

    assert("Not an IPETEdge"){edge.is_a?(IPETEdge)}

    src = add_node(edge.source)
    dst = add_node(edge.target)

    ename = "n" + @mapping.size.to_s
    e = @graph.add_edges(src, dst, :id => ename, :tooltip => edge.to_s, :labeltooltip => edge.to_s)
    @mapping[key] = e

    if cost
      e[:label] = cost.to_s
    end

    if edge.cfg_edge?
      e[:style] = "solid"
    elsif edge.call_edge?
      e[:style] = "bold"
    elsif edge.relation_graph_edge?
      e[:style] = "dashed"
    else
      e[:style] = "dotted"
    end
    

    e
  end

  def mark_unbounded(vars)
    vars.each do |v|
      @mapping[v][:color]     = INFEASIBLE_COLOUR
      @mapping[v][:style]     = "filled"
      @mapping[v][:fillcolor] = INFEASIBLE_FILL
    end
  end

  def annotate_freqs(freqmap)
    freqmap.each do |v,f|
      if v.is_a?(IPETEdge)
        # Labelstrings are an own class... Therefore, we have to do strange type
        # conversions here...
        s = @mapping[v][:label]
        s = s ? s.to_ruby.gsub(/(^"|"$)/, "") : ""
        @mapping[v][:label] = "#{f} times \u00d7 #{s} cy"
        if f > 0
          @mapping[v][:color] = WORST_CASE_PATH_COLOUR
          @mapping[v][:fillcolor] = WORST_CASE_PATH_COLOUR
          @mapping[v][:style] = "filled"
        end
      end
    end
  end

  def collect_variables(term)
    vars = Set.new
    term.lhs.each do |vi,c|
      v = @ilp.var_by_index(vi)
      vars.add(v)
    end
    return vars
  end

  def get_constraints
    constraints = []
    # Mapping of constraints to ILP-Vars (== IPETEdges)
    c2v         = []
    # Inverse mapping
    v2c         = {}

    ilp.constraints.each do |c|
      next if c.name =~ /^__debug_upper_bound/

      index = constraints.length
      constraints << { :formula => c.to_s, :name => c.name }
      vals = []
      # If this assertion breaks: merge left and right side
      assert ("We only deal with constant rhs") {c.rhs.is_a?(Fixnum)}
      collect_variables(c).each do |v|
        next unless @mapping.has_key?(v)
        node = add_node(v)
        id = node[:id].to_ruby
        vals << { :id => id, :name => v.to_s }
        (v2c[id] ||= []) << index
      end
      c2v << vals
    end

    return {
      :constraints => constraints,
      :c2v         => c2v,
      :v2c         => v2c,
    }
  end

  def visualize(title, opts = {})
    begin
      require 'graphviz'
    rescue LoadError => e
      STDERR.puts "Failed to load graphviz, disabling ILPVisualisation"
      return nil
    end

    assert("Graph is already drawn") {@graph == nil}

    @graph = GraphViz.digraph(:ILP)

    ilp.variables.each do |v|
      if v.is_a?(IPETEdge)
        add_edge(v, ilp.get_cost(v))
      else
        add_node(v)
      end
    end

    if opts[:unbounded]
      mark_unbounded(opts[:unbounded])
    end

    if opts[:freqmap]
      annotate_freqs(opts[:freqmap])
    end

    [@graph.output(:svg => String), @graph.output(:dot => String)]
  end
end # class ILPVisualisation

def run_visualization_server(ilp, options, freqs)
  vis = ILPVisualisation.new(ilp, [:bitcode, :machinecode, :relationgraph, :gcfg])
  ilp_graph_svg, ilp_graph_dot = vis.visualize("ILP: #{options.analysis_entry}", :unbounded => {}, :freqmap => freqs)
  ilp_dot = "wcec-ilp.dot"
  ilp_svg = "wcec-ilp.svg"
  File.write(ilp_svg, ilp_graph_svg)
  File.write(ilp_dot, ilp_graph_dot)
  info("Written #{ilp_dot} and #{ilp_svg}")
  
  constraints = vis.get_constraints
  srchints    = vis.get_srchints
  
  ilpdata = {
    'ilp.svg' => {
      'content_type' => 'image/svg+xml',
      # 'data' => visualisation[:ilp][:svg],
      'data' => ilp_graph_svg,
    },
    'constraints.json' => {
      'content_type' => 'application/json',
      # 'data' => JSON.generate(visualisation[:ilp][:constraints]),
      'data' => JSON.generate(constraints),
    },
    'srchints.json' => {
      'content_type' => 'application/json',
      # 'data' => JSON.generate(visualisation[:ilp][:srchints]),
      'data' => JSON.generate(srchints),
    },
  }
  
  assetdir = File.realpath(File.join(__dir__, '..', '..', 'assets'))
  assert ("Not a directory #{assetdir}") { File.directory? (assetdir) }
  
  # TODO:
  options.source_path = '/'
  options.server_bind_addr = 'localhost'
  options.server_port = 2342
  
  server = VisualisationServer::Server.new( \
                      :ilp, \
                      { \
                          :entrypoint => options.analysis_entry \
                        , :srcroot => options.source_path  \
                        , :assets  => assetdir \
                        , :data    => ilpdata  \
                      }, \
                      :BindAddress => options.server_bind_addr, \
                      :Port => options.server_port \
  )
  
  # puts "Starting server, use <Ctrl-C> to return to REPL"
  puts "Listening at http://#{options.server_bind_addr}:#{options.server_port}/"
  server.start
end
