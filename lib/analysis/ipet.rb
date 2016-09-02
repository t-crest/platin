#
# platin tool set
#
# IPET module
#
require 'core/utils'
require 'core/pml'
require 'analysis/ilp'
require 'set'
module PML

# This exception is raised if indirect calls could not be resolved
# during analysis
class UnresolvedIndirectCall < Exception
  def initialize(callsite)
    super("Unresolved Indirect Call: #{callsite.inspect}")
    @callsite = callsite
  end
end

#
# A control-flow refinement provides additional,
# context-sensitive information about the control-flow,
# that is useful to prune callgraphs, CFGs etc.
#
# Currently, two refinements are implement
#
# (1) in scope main or locally, frequency==0 => dead code (infeasible)
# (2) in scope main or locally, cs calls one of targets => refine calltarget sets
#
# +entry+:: analysis entry (a Function)
# +flowfacts+:: a list of flowfacts to process
# +level+:: either machinecode or bitcode
#
class ControlFlowRefinement
  def initialize(entry, level)
    @entry, @level = entry, level
    @infeasible, @calltargets = {}, {}
  end

  def add_flowfact(flowfact)
    return unless flowfact.level == @level
    return unless flowfact.globally_valid?(@entry)
    # add calltargets
    scope,cs,targets = flowfact.get_calltargets
    if scope
      add_calltargets(ContextRef.new(cs.instruction, scope.context), targets.map { |t| t.function})
    end
    # set infeasible blocks
    scope,bref = flowfact.get_block_infeasible
    if scope
      set_infeasible(ContextRef.new(bref.block, scope.context))
    end
  end

  # returns true if +block+ is infeasible in the given +context+
  # XXX: use context trees
  def infeasible_block?(block, context = Context.empty)
    dict = @infeasible[block]
    return false unless dict
    dict[Context.empty] || (! context.empty? && dict[context])
  end

  # returns the set of possible calltargets for +callsite+ in +context+
  # XXX: use context trees
  def calltargets(callsite, context = Context.empty)
    static_fs  = callsite.called_functions
    static_set = Set[*static_fs] if static_fs

    dict = @calltargets[callsite]
    global_set = @calltargets[callsite][Context.empty] if dict
    ctx_set    = @calltargets[callsite][context] unless context.empty? if dict
    sets = [ctx_set,global_set,static_set].compact
    raise UnresolvedIndirectCall.new(callsite) if sets.empty?
    sets.inject { |a,b| a.intersection(b) }
  end

  def dump(io=$stderr)
    io.puts "INFEASIBLE"
    io.puts
    @infeasible.each { |ref,val|
      io.puts "#{ref.inspect} #{val.inspect}"
    }
    io.puts "CALLTARGETS"
    io.puts
    @calltargets.each { |cs,ts|
      io.puts "#{cs}: #{ts}"
    }
  end

private

  def add_calltargets(callsite_ref, targets)
    add_refinement(callsite_ref, Set[targets], @calltargets) { |oldval,newval|
      oldval.intersection(newval)
    }
  end

  # set block infeasible, and propagate infeasibility
  # XXX: ad-hoc propagation, does not consider loop contexts
  def set_infeasible(block_ref)
    block, ctx = block_ref.programpoint, block_ref.context
    worklist = [block]
    while ! worklist.empty?
      block = worklist.pop
      add_refinement(ContextRef.new(block, ctx), true, @infeasible) { |oldval, _| true }
      block.successors.each { |bsucc|
        next if infeasible_block?(bsucc, ctx)
        if bsucc.predecessors.all? { |bpred| infeasible_block?(bpred, ctx) || bsucc.backedge_target?(bpred) }
          worklist.push(bsucc)
        end
      }
      block.predecessors.each { |bpred|
        next if infeasible_block?(bpred, ctx)
        if bpred.successors.all? { |bsucc| infeasible_block?(bsucc, ctx) }
          worklist.push(bpred)
        end
      }
    end
  end

  def add_refinement(reference, value, dict)
    pp_dict    = (dict[reference.programpoint] ||= {})
    ctx        = reference.context
    newval = if oldval = pp_dict[ctx]
               yield [oldval, value]
             else
               value
             end
    pp_dict[ctx] = newval
  end

end

#
# IPETEdges are either:
# - edges beween CFG blocks
# - call edges
# - edges between relation graph nodes
class IPETEdge
  attr_reader :qname,:source,:target, :level
  attr_writer :static_context
  def initialize(edge_source, edge_target, level)
    @source,@target,@level = edge_source, edge_target, level.to_sym
    arrow = {:bitcode => "~>", :machinecode => "->", :gcfg=>"+>"}[@level]
    fname, tname = [@source, @target].map {|n|
      n.kind_of?(Symbol) ? n.to_s : n.qname
    }
    @qname = "#{fname}#{arrow}#{tname}"
    # The context is a object that has a static_context attribute (e.g., an Atomic Basic Block)
    @static_context = nil
  end
  def backedge?
    return false if target == :exit
    # If we look at a GCFG edge, the backedge property is defined by
    # the underlying machine basic block structure
    if gcfg_edge?
      t = target.abb.get_region(:dst).entry_node
      s = source.abb.get_region(:dst).exit_node
      return t.backedge_target?(s)
    end
    target.backedge_target?(source)
  end
  def cfg_edge?
    return false unless source.kind_of?(Block)
    return false unless :exit == target || target.kind_of?(Block)
    true
  end
  def gcfg_edge?
    if source.kind_of?(GCFGNode) and (target == :exit || target.kind_of?(GCFGNode))
      return true
    end
  end
  # function of source
  def function
    source.function
  end
  def cfg_edge
    assert("IPETEdge#cfg_edge: not a edge between blocks") { cfg_edge? }
    (:exit == target) ? source.edge_to_exit : source.edge_to(target)
  end
  def gcfg_edge
    assert("IPETEdge#cfg_edge: not a edge between blocks") { gcfg_edge? }
    (:exit == target) ? source.edge_to_exit : source.edge_to(target)
  end
  def call_edge?
    source.kind_of?(Instruction) || target.kind_of?(Function)
  end
  def relation_graph_edge?
    source.kind_of?(RelationNode) || target.kind_of?(RelationNode)
  end
  def static_context(key = nil)
    return @static_context.static_context[key] if @static_context and key
    return @static_context.static_context if @static_context
    return nil
  end
  def is_entry_in_static_context(key)
    if key == "function"
      return self.source == self.function.entry_block if function
    elsif key == "abb"
      return gcfg_edge?
    end

  end

  def to_s
    arrow = {:bitcode => "~>", :machinecode => "->", :gcfg=>"+>"}[@level]
    "#{@source}#{arrow}#{:exit == @target ? 'exit' : @target}"
  end
  def inspect
    to_s
  end
  def hash;  @qname.hash ; end
  def ==(other); qname == other.qname ; end
  def eql?(other); self == other; end
end


class IPETModel
  attr_reader :builder, :ilp, :level
  attr_accessor :block_frequency_override, :sum_incoming_override
  def initialize(builder, ilp, level)
    @builder, @ilp, @level = builder, ilp, level
    @sum_incoming_override = Hash.new {|hsh, key| hsh[key] = [] }
    @sum_outgoing_override = Hash.new {|hsh, key| hsh[key] = [] }
    @block_frequency_override = {}
  end

  def infeasible?(block, context = Context.empty)
    builder.refinement[@level].infeasible_block?(block, context)
  end

  def calltargets(cs, context = Context.empty)
    builder.refinement[@level].calltargets(cs, context)
  end

  # high-level helpers
  def assert_less_equal(lhs, rhs, name, tag)
    assert(lhs, "less-equal", rhs, name, tag)
  end
  def assert_equal(lhs, rhs, name, tag)
    assert(lhs, "equal", rhs, name, tag)
  end
  def assert(lhs, op, rhs, name, tag)
    terms = Hash.new(0)
    rhs_const = 0
    [[lhs,1],[rhs,-1]].each { |ts,sgn|
      ts.to_a.each { |pp, c|
        case pp
        when Instruction
          block_frequency(pp.block, c*sgn).each { |k,v| terms[k]+=v }
        when Block
          block_frequency(pp, c*sgn).each { |k,v| terms[k]+=v }
        when Edge
          edge_frequency(pp, c*sgn).each { |k,v| terms[k] += v }
        when Function
          function_frequency(pp, c*sgn).each { |k,v| terms[k] += v}
        when Loop
          sum_loop_entry(pp,c*sgn).each { |k,v| terms[k] += v }
        when Integer
          rhs_const += pp*(-sgn)
        else
          terms[pp] += c*sgn
        end
      }
    }
    c = ilp.add_constraint(terms, op, rhs_const, name, tag)
  end


  # FIXME: we do not have information on predicated calls ATM.
  # Therefore, we use <= instead of = for call equations
  def add_callsite(callsite, fs)
    # variable for callsite
    add_instruction(callsite)

    # create call edges (callsite -> f) for each called function f
    # the sum of all calledge frequencies is (less than or) equal to the callsite frequency
    # Note: less-than in the presence of predicated calls
    calledges = []
    lhs = [ [callsite, -1] ]
    fs.each do |f|
      calledge = IPETEdge.new(callsite, f, level)
      ilp.add_variable(calledge, level.to_sym)
      calledges.push(calledge)
      lhs.push([calledge, 1])
    end
    ilp.add_constraint(lhs,"less-equal",0,"calledges_#{callsite.qname}",:callsite)

    # return call edges
    calledges
  end

  def add_instruction(instruction)
    return if ilp.has_variable?(instruction)
    # variable for instruction
    ilp.add_variable(instruction, level.to_sym)
    # frequency of instruction = frequency of block
    lhs = [ [instruction,1] ] + block_frequency(instruction.block,-1)
    ilp.add_constraint(lhs, "equal", 0, "instruction_#{instruction.qname}",:instruction)
  end

  # frequency of analysis entry is 1
  def add_entry_constraint(entry_function)
    ilp.add_constraint(function_frequency(entry_function),"equal",1,"structural_entry",:structural)
  end

  # frequency of function is equal to sum of all callsite frequencies
  def add_function_constraint(function, calledges)
    lhs = calledges.map { |e| [e,-1] }
    lhs.concat(function_frequency(function,1))
    ilp.add_constraint(lhs,"equal",0,"callers_#{function}",:callsite)
  end

  # add cost to basic block
  def add_block_cost(block, cost)
    block_frequency(block).each { |edge,c|
      ilp.add_cost(edge, c * cost)
    }
  end

  # frequency of incoming is frequency of outgoing edges
  def add_block_constraint(block)
    return if block.predecessors.empty?
    lhs = sum_incoming(block,-1) + sum_outgoing(block)
    lhs.push [IPETEdge.new(block,:exit,level),1] if block.may_return?
    ilp.add_constraint(lhs,"equal",0,"structural_#{block.qname}",:structural)
  end

  # frequency of incoming is frequency of outgoing edges is 0
  def add_infeasible_block_constraint(block)
    add_block_constraint(block)
    unless block.predecessors.empty?
      ilp.add_constraint(sum_incoming(block),"equal",0,"structural_#{block.qname}_0in",:infeasible)
    end
    unless block.successors.empty?
      ilp.add_constraint(sum_outgoing(block),"equal",0,"structural_#{block.qname}_0out",:infeasible)
    end
  end

  # frequency of incoming edges is frequency of block
  def add_block(block)
    return if ilp.has_variable?(block)
    ilp.add_variable(block)
    lhs = block_frequency(block) + [[block, -1]]
    ilp.add_constraint(lhs,"equal",0,"block_#{block.qname}", :structural)
  end

  def function_frequency(function, factor = 1)
    block_frequency(function.blocks.first, factor)
  end

  def block_frequency(block, factor=1)
    if @block_frequency_override.has_key?(block)
      return @block_frequency_override[block].map {|e| [e, factor] }
    end
    if block.successors.empty? # return exit edge
      [[IPETEdge.new(block,:exit,level),factor]]
    else
      sum_outgoing(block,factor)
    end
  end

  def edge_frequency(edge, factor = 1)
    [[IPETEdge.new(edge.source, edge.target ? edge.target : :exit, level), factor ]]
  end

  def sum_incoming(block, factor=1)
    if @sum_incoming_override.has_key?(block)
      return @sum_incoming_override[block].map {|e| [e, factor] }
    end
    block.predecessors.map { |pred|
      [IPETEdge.new(pred,block,level), factor]
    }
  end

  def sum_outgoing(block, factor=1)
    if @sum_outgoing_override.has_key?(block)
      return @sum_outgoing_override[block].map {|e| [e, factor] }
    end

    block.successors.map { |succ|
      [IPETEdge.new(block,succ,level), factor]
    }
  end

  def sum_loop_entry(loop, factor=1)
    sum_incoming(loop.loopheader,factor).reject { |edge,factor|
      edge.backedge?
    }
  end


  # returns all edges, plus all return blocks
  def each_edge(function)
    function.blocks.each_with_index do |bb,ix|
      next if ix != 0 && bb.predecessors.empty? # data block
      bb.successors.each do |bb2|
        yield IPETEdge.new(bb,bb2,level)
      end
      if bb.may_return?
        yield IPETEdge.new(bb,:exit,level)
      end
    end
  end


end # end of class IPETModel


class GCFGIPETModel
  attr_reader :builder, :ilp, :level
  def initialize(builder, ilp, mc_model, level = :gcfg)
    @builder, @ilp, @level = builder, ilp, level
    @mc_model = mc_model
    @entry_edges = []
  end

  # returns all edges, plus all return blocks
  def each_edge(gcfg_node)
    [:local, :global].each {|level|
      gcfg_node.successors(level).each do |n_gcfg_node|
        yield [IPETEdge.new(gcfg_node,n_gcfg_node,:gcfg), level]
      end
    }
    if gcfg_node.is_sink
      yield [IPETEdge.new(gcfg_node,:exit,:gcfg), :global]
    end
  end
  def edge_costs(gcfg_ipet_edge, cost_block)
    # Costs for the Edge between two GCFG Nodes
    src, dst = gcfg_ipet_edge.source, gcfg_ipet_edge.target
    cost = 0
    cost += src.cost if src.cost
    # Microstructure edges add no additional costs
    return cost if src.microstructure

    if src.abb
      gcfg_ipet_edge.static_context = src.abb

      source_block = src.abb.get_region(:dst).exit_node
      target_block = if dst == :exit
                       :exit
                     elsif dst.abb
                       dst.abb.get_region(:dst).entry_node
                     else
                       :idle
                     end
      if not builder.options.ignore_instruction_timing
        mc_edge = IPETEdge.new(source_block, target_block, :machinecode)
        cost += cost_block.call(mc_edge)
      end
    end
    return cost
  end

  def add_entry_constraint(gcfg)
    @wcet_variable = GlobalProgramPoint.new(gcfg.name)
    @ilp.add_variable(@wcet_variable, :gcfg)

    # Entry variables must add up to 1
    lhs = @entry_edges.map {|e| [e, 1]}
    @ilp.add_constraint(lhs, "equal", 1, "structural_gcfg_entry", :structural)
  end

  def entry_to(node)
    FrequencyVariable.new("gcfg_entry_#{node.qname}")
  end

  # The Node frequency is, like on the machine block level constrained
  # by the Node->Node structure
  def add_node_constraint(node)
    # Calculate all flows that go into this node
    incoming = node.predecessors.map { |p| [IPETEdge.new(p,node,level), -1] }
    # Some nodes have an additional input edge, if they are input nodes
    if node.is_source
      e = self.entry_to(node)
      debug(builder.options, :ipet_global) {"Added entry edge #{e}"}
      @ilp.add_variable(e)
      @entry_edges.push(e)
      incoming.push([e, -1]) if node.is_source
    end

    # Flow out of the Node
    outgoing = node.successors.map { |s| [IPETEdge.new(node, s,level), 1] }
    outgoing.push [IPETEdge.new(node,:exit,level),1] if node.is_sink

    # Add the flow constraint
    ilp.add_constraint(incoming+outgoing,"equal",0,"gcfg_structural_#{node.qname}",:structural)

    # If this variable has a frequency variable, we copy its value into the frequency variable
    if node.frequency_variable
      ilp.add_constraint([[node.frequency_variable, -1]] + outgoing,
                         "equal",0,"frequency_variable_#{node.frequency_variable}_#{node.qname}",
                         :structural)

    end
  end

  def each_intra_abb_edge(abb)
    region = abb.get_region(:dst)
    region.nodes.each do |mbb|
      # Followup Blocks within
      mbb.successors.each {|mbb2|
        if mbb == region.exit_node and mbb2 == region.exit_node
          next
        end
        if region.nodes.member?(mbb2)
          yield IPETEdge.new(mbb, mbb2, :machinecode)
        end
      }
      if mbb == region.exit_node
        yield IPETEdge.new(mbb, :exit, :machinecode)
      end
    end
  end

  def add_abb_contents(abb, cost_block)
    edges = Hash.new { |hsh, key| hsh[key]={:in=>[], :out=>[]} }
    each_intra_abb_edge(abb) { |ipet_edge|
      @ilp.add_variable(ipet_edge)
      # Edges to the ABB-Exit are not assigned a cost, since the cost is added on the ABB/State level:
      cost = 0
      if not builder.options.ignore_instruction_timing and ipet_edge.target != :exit
	cost = cost_block.call(ipet_edge)
	@ilp.add_cost(ipet_edge, cost)
      end
      debug(builder.options, :ipet) {
        "Intra-ABB Edge: #{ipet_edge} = #{cost}"
      }
      # Collect edges
      edges[ipet_edge.source][:out].push(ipet_edge)
      edges[ipet_edge.target][:in].push(ipet_edge)
      # Set the static context
      ipet_edge.static_context = abb
    }

    # The first block is activated as often, as the ABB is left
    edges.each {|bb, e|
      incoming = e[:in].map {|x| [x, 1]}
      outgoing = e[:out].map {|x| [x, -1]}
      # Do not add constraints for entry/exit
      next if incoming.length == 0 or outgoing.length == 0
      ilp.add_constraint(incoming+outgoing, "equal", 0,
                       "abb_flux_#{bb.qname}", :structural)

    }
    # Return number of edges, and the list of outgoing edges for the ABB entry
    [edges.keys.length, edges[abb.get_region(:dst).entry_node][:out]]
  end

  def flow_into_abb(abb, nodes, factor = -1)
    incoming, resumes, suspends = [], [], []

    nodes.each do |node|
      incoming += node.predecessors(:local).map {|p|
        [IPETEdge.new(p, node, :gcfg), factor]
      }
      incoming.push([self.entry_to(node), factor]) if node.is_source

      # Suspend and Return Edges (especially IRQ returns) This is a
      # tricky one!. The Problem with our ABB super structure is, that
      # interrupts generate loops at computation blocks, where the
      # resumes are additional edges into the computation block.
      ##
      # This is double accounting of blocks (especially the deeper
      # calling hierarchies underneath the ABB are bad). Therefore, we
      # only count for resume edges, if no corresponding suspend edge is
      # present.
      resumes += node.predecessors(:global).map {|p| [IPETEdge.new(p, node, :gcfg), -1] }
      suspends += node.successors(:global).map {|p| [IPETEdge.new(node, p, :gcfg), 1] }
    end

    if resumes.length > 0
      debug(builder.options, :ipet_global) {
        "Add IRQ Resume edges: #{abb.name} => resumes: #{resumes} suspends: #{suspends}"
      }
      sos_name = "SOS_#{abb.qname}"
      pos = (sos_name + "_additional_resumes").to_sym
      neg = (sos_name + "_negative_slack").to_sym
      ilp.add_sos1(sos_name, [pos, neg])

      # pos - neg = (resume - suspend) = 0;
      ilp.add_constraint([[pos, 1], [neg, -1]] + resumes + suspends, "equal", 0,
                         "resume_#{abb.qname}", :structural)
      # Sometimes LP Solve is an unhappy beast
      if @ilp.kind_of?(LpSolveILP)
        ilp.add_constraint([[pos, 1]] + resumes , "less-equal", 0,
                           "resume_ilp_happy_#{abb.qname}", :structural)
      end
      incoming += [[pos, factor]]
    end

    incoming
  end

  def add_total_time_variable
    # The gcfg_wcet_constraint assigns the global worst case response
    # time to the @wcet_variable, this variable will hold the maximal
    # cost for this ILP.
    lhs = [[@wcet_variable, -1]]
    rhs = @ilp.costs.map {|e, f| [e, f] }
    @ilp.add_constraint(lhs+rhs, "equal", 0, "global_wcet_equality", :gcfg)
    if @ilp.kind_of?(LpSolveILP)
      @ilp.add_constraint([[@wcet_variable, 1]], "less-equal", 1 << 32, "global_wcet_happy_lp_solve", :gcfg)
    end
  end

  def global_program_point(pp, factor=1)
    [[pp, factor]]
  end

end # end of class GCFGIPETModel

class IPETBuilder
  attr_reader :ilp, :mc_model, :bc_model, :refinement, :call_edges, :options

  def initialize(pml, options, ilp = nil)
    @ilp = ilp
    @mc_model = IPETModel.new(self, @ilp, 'machinecode')
    @gcfg_model = GCFGIPETModel.new(self, @ilp, @mc_model, 'gcfg')

    if options.use_relation_graph
      @bc_model = IPETModel.new(self, @ilp, 'bitcode')
      @pml_level = { :src => 'bitcode', :dst => 'machinecode' }
      @relation_graph_level = { 'bitcode' => :src, 'machinecode' => :dst }
    end

    @ffcount = 0
    @pml, @options = pml, options
  end

  def pml_level(rg_level)
    @pml_level[rg_level]
  end

  def relation_graph_level(pml_level)
    @relation_graph_level[pml_level]
  end

  def get_functions_reachable_from_function(function)
    # compute set of reachable machine functions
    reachable_set(function) do |mf_function|
      # inspect callsites in the current function
      succs = Set.new
      mf_function.callsites.each { |cs|
        next if @mc_model.infeasible?(cs.block)
        @mc_model.calltargets(cs).each { |f|
          assert("calltargets(cs) is nil") { ! f.nil? }
          succs.add(f)
        }
      }
      succs
    end
  end

  # Build basic IPET structure.
  # yields basic blocks, so the caller can compute their cost
  # This Function is only used in the flow fact transformation
  # entry = {'machinecode'=> foo/1, 'bitcode'=> foo}
  def build(entry, flowfacts, opts = { :mbb_variables =>  false }, &cost_block)
    assert("IPETBuilder#build called twice") { ! @entry }
    @entry = entry
    @markers = {}
    @call_edges = []
    @mf_function_callers = Hash.new {|hsh, key| hsh[key] = [] }
    @options.mbb_variables = opts[:mbb_variables]

    # build refinement to prune infeasible blocks and calls
    build_refinement(@entry, flowfacts)

    mf_functions = get_functions_reachable_from_function(@entry['machinecode'])
    mf_functions.each { |mf_function |
      add_function_with_blocks(mf_function, cost_block)
    }

    mf_functions.each do |f|
      add_bitcode_constraints(f) if @bc_model
      add_calls_in_function(f)
    end

    @mc_model.add_entry_constraint(@entry['machinecode'])

    add_global_call_constraints()

    flowfacts.each { |ff|
      debug(@options,:ipet) { "adding flowfact #{ff}" }
      add_flowfact(ff)
    }
  end

  def add_function_with_blocks(mf_function, cost_block)
    # machinecode variables + cost
    @mc_model.each_edge(mf_function) do |ipet_edge|
      @ilp.add_variable(ipet_edge, :machinecode)
      if not @options.ignore_instruction_timing
	cost = cost_block.call(ipet_edge)
	@ilp.add_cost(ipet_edge, cost)
      end
      ipet_edge.static_context = mf_function
    end

    # bitcode variables and markers
    if @bc_model
      add_bitcode_variables(mf_function)
    end

    # Add block constraints
    mf_function.blocks.each_with_index do |block, ix|
      next if block.predecessors.empty? && ix != 0 # exclude data blocks (for e.g. ARM)
      if @mc_model.infeasible?(block)
        @mc_model.add_infeasible_block_constraint(block)
        next
      end
      @mc_model.add_block_constraint(block)
      if @options.mbb_variables
        @mc_model.add_block(block)
      end
    end

    # Return number of added basic blocks
    mf_function.blocks.length
  end

  ################################################################
  # Function Calls
  ################################################################
  def add_calls_in_function(mf_function, forbidden_targets=nil)
    mf_function.blocks.each do |block|
      add_calls_in_block(block, forbidden_targets)
    end
  end

  def add_calls_in_block(mbb, forbidden_targets=nil)
    forbidden_targets = Set.new(forbidden_targets || [])
    mbb.callsites.each do |cs|
      call_targets = @mc_model.calltargets(cs)
      call_targets -= forbidden_targets

      current_call_edges = @mc_model.add_callsite(cs, call_targets)
      current_call_edges.each do |ce|
        ce.static_context = cs.function
        @mf_function_callers[ce.target].push(ce)
      end
      @call_edges += current_call_edges
    end
  end

  def add_global_call_constraints()
    @mf_function_callers.each do |f,ces|
      @mc_model.add_function_constraint(f, ces)
    end
  end


  # Build basic IPET Structure, when a GCFG is present
  def build_gcfg(gcfg, flowfacts, opts={ :mbb_variables =>  false }, &cost_block)
    assert("IPETBuilder#build called twice") { ! @entry }
    @call_edges = []
    @mf_function_callers = Hash.new {|hsh, key| hsh[key] = [] }
    @options.mbb_variables = opts[:mbb_variables]

    # build refinement to prune infeasible blocks and calls
    build_refinement(gcfg, flowfacts)

    # For each function and each ABB we collect the nodes that activate it.
    abb_to_nodes = Hash.new {|hsh, key| hsh[key] = [] }
    function_to_nodes = Hash.new {|hsh, key| hsh[key] = [] }

    # 1. Pass over all states to create the super structure
    #    1.1 Add frequency variables
    #    1.2 Add edge variables for the Node->Node structure
    #    1.3 Collect activated artifacts
    gcfg.nodes.each do |node|
      # 1.1
      if node.frequency_variable
        @ilp.add_variable(node.frequency_variable, :gcfg)
      end

      # 1.2 Every Super-structure edge has a variable
      @gcfg_model.each_edge(node) { |ipet_edge, level|
        @ilp.add_variable(ipet_edge, :gcfg)
        edge_cost = @gcfg_model.edge_costs(ipet_edge, cost_block)
        ipet_edge.static_context = node.abb if node.abb
        @ilp.add_cost(ipet_edge, edge_cost)
        debug(@options, :ipet_global) { "Added edge #{ipet_edge} with cost #{edge_cost}" }
        # Override Incoming Edges for Superstructure blocks. This is
        # required for loop flowfacts on the global level.
        if not ipet_edge.target.kind_of?(Symbol) and ipet_edge.target.abb and ipet_edge.source.abb and
          not ipet_edge.target.microstructure and level == :local
          target_bb = ipet_edge.target.abb.get_region(:dst).entry_node
          @mc_model.sum_incoming_override[target_bb].push(ipet_edge)
        end
      }

      # 1.3 Collect activated artifacts
      abb_to_nodes[node.abb].push(node) if node.abb
      function_to_nodes[node.function].push(node) if node.function
    end

    # 2. Connect the super structure connections
    gcfg.nodes.each do |node|
      @gcfg_model.add_node_constraint(node)
    end
    ## After all node constraints
    @gcfg_model.add_entry_constraint(gcfg)

    #################################################
    ## The ABB Super Structure is now fully in place.

    # 3. Put the executed objects into place
    #    3.1 All ABBs from nodes that are _not_ marked as microstructure
    #    3.2 Collect functions called from the superstructure ABBs
    #    3.3 Collect functions called from GCFG nodes
    #    3.4 Add functions
    full_mfs = Set.new    ## To be added
    gcfg_mfs = Set.new
    gcfg_mbbs = Set.new
    toplevel_abb_count = 0 # statistics

    abb_to_nodes.each { |abb, nodes|
      # 3.1 All ABBs from nodes that are _not_ marked as microstructure
      microstructure = nodes.map { |x| x.microstructure }
      next if microstructure.all?
      assert("Microstructure state of #{abb} is inconsistent") { not microstructure.any? }
      toplevel_abb_count += 1

      # Add blocks within the ABB
      basic_blocks, abb_freq = @gcfg_model.add_abb_contents(abb, cost_block)

      # ABB Freq is the list of edges that have ABB.entry_node as source
      # If this node has an ABB attached, the block frequency of the
      region = abb.get_region(:dst)
      @mc_model.block_frequency_override[region.entry_node] = abb_freq
      if region.entry_node != region.exit_node
        @mc_model.block_frequency_override[region.exit_node] = abb_freq
      end
      debug(@options, :ipet_global) { "Added contents: #{abb} (#{basic_blocks} blocks)" }

      gcfg_mfs.add(abb.function)

      # 3.2 What functions are called from this ABB?
      region.nodes.each { |bb|
        gcfg_mbbs.add(bb)
        bb.callsites.each { |cs|
          next if @mc_model.infeasible?(cs.block)
          @mc_model.calltargets(cs).each { |f|
            assert("calltargets(cs) is nil") { ! f.nil? }
            full_mfs += get_functions_reachable_from_function(f)
          }
        }
      }
    }
    # 3.3 Collect functions called from GCFG nodes
    function_to_nodes.each { |mf, nodes|
      microstructure = nodes.map { |x| x.microstructure }
      next if microstructure.all?
      assert("Microstructure state of #{mf} is inconsistent") { not microstructure.any? }
      full_mfs += get_functions_reachable_from_function(mf)
    }

    ## Interlude: Sanity Check: No function that is called from the
    ## superstructure can be a ABB function
    assert("Functions #{(full_mfs & gcfg_mfs).to_a} part of superstructure and called function") {
      (full_mfs & gcfg_mfs).length == 0
    }

    # 3.4 Add functions
    full_mfs.each do |mf|
      basic_blocks = add_function_with_blocks(mf, cost_block)
      debug(@options, :ipet_global) { "Added contents: #{mf} (#{basic_blocks} blocks)" }
    end

    ##############################################
    # All structures/objects/functions are in place

    # 4. Connect the node frequencies to the underlying object
    #    4.1 to ABB frequencies
    #    4.2 to function frequencies
    abb_to_nodes.each {|abb, nodes|
      mc_entry_block = abb.get_region(:dst).entry_node
      lhs = @mc_model.block_frequency(mc_entry_block)
      rhs = @gcfg_model.flow_into_abb(abb, nodes)
      if abb.frequency_variable
        @ilp.add_variable(abb.frequency_variable, :gcfg)
        @ilp.add_constraint(lhs + [[abb.frequency_variable, -1]], "equal", 0, "abb_freq_var_#{abb.qname}", :gcfg)
      end

      @ilp.add_constraint(lhs+rhs, "equal", 0, "abb_influx_#{abb.qname}", :gcfg)
    }
    #    4.2 to function frequencies
    function_to_nodes.each {|mf, nodes|
      mc_entry_block = mf.entry_block
      lhs = @mc_model.block_frequency(mc_entry_block)
      rhs = @gcfg_model.flow_into_abb(mf, nodes)
      @ilp.add_constraint(lhs+rhs, "equal", 0, "abb_influx_#{mf.qname}", :gcfg)
    }


    # 5. Add missing super-structure connections
    #    5.1 Calls from embedded functions
    #    5.2 Calls from super-structure ABBs
    #    5.3 Add call constraints
    #    5.4 Global timimg variable

    full_mfs.each do |mf|
      add_calls_in_function(mf, forbidden = gcfg_mfs)
    end
    #    5.2 Calls from super-structure ABBs
    gcfg_mbbs.each do |bb|
      add_calls_in_block(bb)
    end
    #    5.3 Add call constraints
    add_global_call_constraints()

    #    5.4 Global timimg variable
    @gcfg_model.add_total_time_variable


    flowfacts.each { |ff|
      debug(@options, :ipet) { "adding flowfact #{ff}" }
      add_flowfact(ff)
    }

    statistics("WCA",
               "gcfg nodes" => gcfg.nodes.length,
               "abbs toplevel" => toplevel_abb_count,
               "abbs microstructure" => abb_to_nodes.length - toplevel_abb_count
               ) if @options.stats


    die("Bitcode contraints are not implemented yet") if @bc_model
 end

  #
  # Add flowfacts
  #
  def add_flowfact(ff, tag = :flowfact)
    model = {'machinecode'=> @mc_model, 'bitcode'=> @bc_model, 'gcfg'=> @gcfg_model}[ff.level]
    raise Exception.new("IPETBuilder#add_flowfact: cannot add bitcode flowfact without using relation graph") unless model
    unless ff.rhs.constant?
      warn("IPETBuilder#add_flowfact: cannot add flowfact with symbolic RHS to IPET: #{ff}")
      return false
    end
    if ff.level == "bitcode"
      begin
        ff = replace_markers(ff)
      rescue Exception => ex
        warn("IPETBuilder#add_flowact: failed to replace markers: #{ex}")
        return false
      end
    end
    lhs, rhs = [], []
    operator = ff.op
    const = 0

    ff.lhs.each { |term|
      unless term.context.empty?
        warn("IPETBuilder#add_flowfact: context sensitive program points not supported: #{ff}")
        return false
      end

      if term.programpoint.kind_of?(Function)
        lhs += model.function_frequency(term.programpoint, term.factor)
      elsif term.programpoint.kind_of?(Block)
        lhs += model.block_frequency(term.programpoint, term.factor)
      elsif term.programpoint.kind_of?(Edge)
        lhs += model.edge_frequency(term.programpoint, term.factor)
      elsif term.programpoint.kind_of?(ConstantProgramPoint)
        # Constant Program Points can be used without declaration.
        # They are used as mere constant within the flowfact
        # expression. They are not eliminated in the flowfact transformation.
        pp = term.programpoint
        if not @ilp.has_variable?(pp)
          @ilp.add_variable(pp)
          @ilp.add_constraint([[pp, 1]], "equal", pp.value, pp.qname, :constant)
        end
        lhs += [[pp, term.factor]]
      elsif term.programpoint.kind_of?(FrequencyVariable)
        lhs += [[term.programpoint, term.factor]]
      elsif term.programpoint.kind_of?(Instruction)
        # XXX: exclusively used in refinement for now
        warn("IPETBuilder#add_flowfact: references instruction, not block or edge: #{ff}")
        return false
      else
        raise Exception.new("IPETBuilder#add_flowfact: Unknown programpoint type: #{term.programpoint.class}")
      end
    }
    scope = ff.scope
    unless scope.context.empty?
      warn("IPETBUilder#add_flowfact: context sensitive scopes not supported: #{ff}")
      return false
    end
    if scope.programpoint.kind_of?(Function)
      rhs += model.function_frequency(scope.programpoint, -ff.rhs.to_i)
    elsif scope.programpoint.kind_of?(Block)
      lhs += model.block_frequency(scope.programpoint, -ff.rhs.to_i)
    elsif scope.programpoint.kind_of?(Loop)
      rhs += model.sum_loop_entry(scope.programpoint, -ff.rhs.to_i)
    elsif scope.programpoint.kind_of?(GlobalProgramPoint)
      rhs += model.global_program_point(scope.programpoint, -1)
    else
      raise Exception.new("IPETBuilder#add_flowfact: Unknown scope type: #{scope.programpoint.class}")
    end

    begin
      name = "ff_#{@ffcount+=1}"
      # Additional Flow Fact Transformations: Minimal/Maximal Interarrival Time
      if ff.op.end_with?("interarrival-time")
        # The Interarrival time is the right hand side constant
        iat = ff.rhs.to_i
        maximal = {"maximal-interarrival-time"=>true,
                   "minimal-interarrival-time"=> false}[ff.op]
        # The LHS for arrival times are arrival counts, therefore, we
        # multiply them with the interrarrival time. For MAXIAT we
        # need the negative sum:
        # K * vec(LHS) - SPAN <= K  (MINIAT)
        # SPAN - K * vec(LHS) <= K  (MAXIAT)

        lhs = lhs.map {|v, f| [v, (maximal ? -iat : iat) * f]}
        rhs = rhs.map {|v, f| [v, (maximal ? -1   : 1  ) * f]}
        debug(@options, :ipet_global) {"#{maximal ? "Maximal" : "Minimal"} IAT: #{lhs+rhs} <= #{const}" }
        operator = 'less-equal'
        const += maximal ? 0 : iat
      end
      ilp.add_constraint(lhs + rhs, operator, const, name, tag)
      name
    rescue UnknownVariableException => detail
      debug(@options,:transform) { " ... skipped constraint: #{detail} #{lhs+rhs} #{operator} #{const}" }
      debug(@options,:ipet) { " ...skipped constraint: #{detail}" }
    end
  end

private

  # build the control-flow refinement (which provides additional
  # flow information used to prune the callgraph/CFG)
  def build_refinement(gcfg_or_hash, ffs)
    @refinement = {}

    entry = gcfg_or_hash.kind_of?(Hash) ? gcfg_or_hash: gcfg_or_hash.get_entry

    entry.each { |level,functions|
      cfr = ControlFlowRefinement.new(functions[0], level)
      ffs.each { |ff|
        next if ff.level != level
        cfr.add_flowfact(ff)
      }
      @refinement[level] = cfr
    }
  end

  # add variables for bitcode basic blocks and relation graph
  # (only if relation graph is available)
  def add_bitcode_variables(machine_function)
    return unless @pml.relation_graphs.has_named?(machine_function.name, :dst)
    rg = @pml.relation_graphs.by_name(machine_function.name, :dst)
    return unless rg.accept?(@options)
    bitcode_function = rg.get_function(:src)
    @bc_model.each_edge(bitcode_function) do |edge|
      @ilp.add_variable(edge, :bitcode)
    end
    each_relation_edge(rg) do |edge|
      @ilp.add_variable(edge, :relationgraph)
    end
    # record markers
    bitcode_function.blocks.each { |bb|
        bb.instructions.each { |i|
            if i.marker
              (@markers[i.marker]||=[]).push(i)
            end
        }
    }
  end

  # replace markers by instructions
  def replace_markers(ff)
    new_lhs = TermList.new([])
    ff.lhs.each { |term|
        if term.programpoint.kind_of?(Marker)
          factor = term.factor
          if ! @markers[term.programpoint.name]
            raise Exception.new("No instructions corresponding to marker #{term.programpoint.name.inspect}")
          end
          @markers[term.programpoint.name].each { |instruction|
              new_lhs.push(Term.new(instruction.block, factor))
            }
        else
          new_lhs.push(term)
        end
      }
    FlowFact.new(ff.scope, new_lhs, ff.op, ff.rhs, ff.attributes)
  end

  # add constraints for bitcode basic blocks and relation graph
  # (only if relation graph is available)
  def add_bitcode_constraints(machine_function)
    return unless @pml.relation_graphs.has_named?(machine_function.name, :dst)
    rg = @pml.relation_graphs.by_name(machine_function.name, :dst)
    return unless rg.accept?(@options)

    bitcode_function = rg.get_function(:src)
    bitcode_function.blocks.each { |block|
      @bc_model.add_block_constraint(block)
    }
    # Our LCTES 2013 paper describes 5 sets of constraints referenced below
    # map from src/dst edge to set of corresponding relation edges (constraint set (3) and (4))
    rg_edges_of_edge   = { :src => {}, :dst => {} }
    # map from progress node to set of outgoing src/dst edges (constraint set (5))
    rg_progress_edges = { }
    each_relation_edge(rg) do |edge|
      rg_level = relation_graph_level(edge.level.to_s)
      source_block = edge.source.get_block(rg_level)
      target_block = (edge.target.type == :exit) ? :exit : (edge.target.get_block(rg_level))

      assert("Bad RG: #{edge}") { source_block && target_block }
      # (3),(4)
      (rg_edges_of_edge[rg_level][IPETEdge.new(source_block,target_block,edge.level)] ||=[]).push(edge)
      # (5)
      if edge.source.type == :entry || edge.source.type == :progress
        rg_progress_edges[edge.source] ||= { :src => [], :dst => [] }
        rg_progress_edges[edge.source][rg_level].push(edge)
      end
    end
    # (3),(4)
    rg_edges_of_edge.each do |_level,edgemap|
      edgemap.each do |edge,rg_edges|
        lhs = rg_edges.map { |rge| [rge,1] } + [[edge,-1]]
        @ilp.add_constraint(lhs, "equal", 0, "rg_edge_#{edge.qname}", :structural)
      end
    end
    # (5)
    rg_progress_edges.each do |progress_node, edges|
      lhs = edges[:src].map { |e| [e,1] } + edges[:dst].map { |e| [e,-1] }
      @ilp.add_constraint(lhs, "equal", 0, "rg_progress_#{progress_node.qname}", :structural)
    end
  end

  # return all relation-graph edges
  def each_relation_edge(rg)
    rg.nodes.each { |node|
      [:src,:dst].each { |rg_level|
        next unless node.get_block(rg_level)
        node.successors(rg_level).each { |node2|
          if node2.type == :exit || node2.get_block(rg_level)
            yield IPETEdge.new(node,node2,pml_level(rg_level))
          end
        }
      }
    }
  end
end # IPETModel

end # module PML
