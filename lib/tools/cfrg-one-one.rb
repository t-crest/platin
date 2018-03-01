#!/usr/bin/env ruby
#
# PLATIN tool set
#
# Simple check for 1:1 mappings in CFRGs
#
require 'set'
require 'platin'
require 'analysis/scopegraph'
include PML

begin
  require 'rubygems'
  require 'graphviz'

rescue Exception => details
  warn "Failed to load library graphviz"
  info "  ==> gem1.9.1 install ruby-graphviz"
  die "Failed to load required ruby libraries"
end

class RGVisualizer
  attr_reader :options

  def generate(g,outfile)
    debug(options, :visualize) { "Generating #{outfile}" }
    g.output( options.graphviz_format.to_sym => "#{outfile}" )
    info("#{outfile} ok") if options.verbose
  end

  def initialize(options); @options = options; end

  def visualize(rg)
    nodes = {}
    g = GraphViz.new( :G, type: :digraph )
    g.node[:shape] = "rectangle"

    # XXX: update me
    rg = rg.data if rg.kind_of?(RelationGraph)

    name = "#{rg['src'].inspect}/#{rg['dst'].inspect}"
    rg['nodes'].each do |node|
      bid = node['name']
      label = "#{bid} #{node['type']}"
      label << " #{node['src-block']}" if node['src-block']
      label << " #{node['dst-block']}" if node['dst-block']
      nodes[bid] = g.add_nodes(bid.to_s, label: label)
    end
    rg['nodes'].each do |node|
      bid = node['name']
      (node['src-successors'] || []).each do |sid|
        g.add_edges(nodes[bid],nodes[sid])
      end
      (node['dst-successors'] || []).each do |sid|
        g.add_edges(nodes[bid],nodes[sid], style: 'dotted')
      end
    end
    g
  end
end

class OneOneCheck
  # use either GraphViz::Constants::FORMATS or Constants::FORMATS, depending on which
  # of those is defined by ruby-graphviz
  #                                                        graphviz >= 1.2.2              graphviz < 1.2.2
  VALID_FORMATS = defined?(GraphViz::Constants::FORMATS) ? GraphViz::Constants::FORMATS : Constants::FORMATS

  def self.default_targets(pml, entryfunc)
    entry = pml.machine_functions.by_label(entryfunc)
    pml.machine_functions.reachable_from(entry.name).first.reject do |f|
      f.label =~ /printf/
    end.map do |f|
      f.label
    end
  end

  def self.is_one_one(rg)
    nodes = {}

    # XXX: update me
    rg = rg.data if rg.kind_of?(RelationGraph)

    rg['nodes'].each do |node|
      bid = node['name']

      srcsucc = node['src-successors'] || []
      dstsucc = node['dst-successors'] || []

      # if the number of successors does not match, we're not having a 1:1 mapping
      # this might be the case for if-conversions etc.
      return false if srcsucc.count != dstsucc.count

      (node['src-successors'] || []).each do |ssid|
        found = false
        (node['dst-successors'] || []).each do |dsid|
          found = true if ssid == dsid
        end

        return false if !found
      end
    end

    true
  end

  def self.run(pml, options)
    outdir  = options.outdir || "."
    entry   = options.entry || "main"
    targets = options.functions || OneOneCheck.default_targets(pml, entry)
    options.graphviz_format ||= "png"
    suffix = "." + options.graphviz_format

    targets.each do |target|

      # Visualize relation graph
      begin
        rg = pml.data['relation-graphs'].find { |f| f['src']['function'] == target or f['dst']['function'] == target }
        raise Exception.new("Relation Graph not found") unless rg

        is11 = is_one_one(rg)
        puts "[OneOneCheck] #{target}: #{is11}"

        if !is11
          file = File.join(outdir, target + ".rg.non11" + suffix)
          rgv = RGVisualizer.new(options)
          rgv.generate(rgv.visualize(rg),file)
        end

      rescue Exception => detail
        puts "Failed to visualize relation graph of #{target}: #{detail}"
        raise detail if options.raise_on_error
      end
    end
    statistics("ONEONECHECK","Generated rg graphs" => targets.length) if options.stats
  end

  def self.add_options(opts)
    opts.on("-f","--function FUNCTION,...","Name of the function(s) to check") { |f| opts.options.functions = f.split(/\s*,\s*/) }
    opts.on("-O","--outdir DIR","Output directory for image files") { |d| opts.options.outdir = d }
    opts.on("-e","--entry FUNC","PML entry function") { |f| opts.options.entry = f }
  end
end

if __FILE__ == $PROGRAM_NAME
SYNOPSIS = <<EOF if __FILE__ == $PROGRAM_NAME
Check if the control-flow relation graph is a 1:1 mapping between bc and mc
EOF
  options, args = PML::optparse([],"", SYNOPSIS) do |opts|
    opts.needs_pml
    opts.callstring_length
    OneOneCheck.add_options(opts)
  end
  OneOneCheck.run(PMLDoc.from_files(options.input, options), options)
end
