#
# platin tool set
#
# core library for program representation
#
require 'core/utils'
require 'core/pmlbase'

module PML

  class UnknownFunctionException < Exception
    def initialize(name)
      super("No function named or labelled #{name} in analyzed program")
    end
  end

  # List of functions in the program
  class FunctionList < PMLList
    extend PMLListGen
    pml_name_index_list(:Function,[:address,:label],[])

    # customized constructor
    def initialize(data, opts)
      @opts = opts
      @list = data.map { |f| Function.new(self, f, opts) }
      set_yaml_repr(data)
      build_index
    end

    def by_label_or_name(key, error_if_missing = false)
      by_label(key, false) || by_name(key, error_if_missing)
    end

    # Add empty function
    def add_function(data)
      reset_yaml_repr
      add(Function.new(self, data, @opts))
    end

    # return [rs, unresolved]
    # rs .. list of (known functions) reachable from name
    # unresolved .. set of callsites that could not be resolved
    def reachable_from(name)
      unresolved = Set.new
      rs = reachable_set(by_name(name)) do |f|
        callees = []
        f.callsites.each do |cs|
          cs.callees.each do |n|
            if (f = by_label_or_name(n,false))
              callees.push(f)
            else
              unresolved.add(cs)
            end
          end
        end
        callees
      end
      [rs, unresolved]
    end

    def instruction_by_address(addr)
      if ! @instruction_by_address
        @instruction_by_address = {}
        self.each { |f| f.instructions.each { |i| @instruction_by_address[i.address] = i } }
      end
      @instruction_by_address[addr]
    end
  end

  # List of PML basic blocks in a function
  class BlockList < PMLList
    extend PMLListGen
    pml_name_index_list(:Block)
    # customized constructor
    def initialize(function, data)
      @list = data.map { |b| Block.new(function, b) }
      @list.each_with_index { |block,ix| block.layout_successor = @list[ix + 1] }
      set_yaml_repr(data)
      build_index
    end
  end

  # List of PML instructions in a block
  class InstructionList < PMLList
    extend PMLListGen
    pml_name_index_list(:Instruction)
    # customized constructor
    def initialize(block, data)
      @list = data.map { |i| Instruction.new(block, i) }
      set_yaml_repr(data)
    end

    def [](index)
      index = Integer(index) if index.instance_of? String
      @list[index]
    end
  end

  # References to Program Points (functions, blocks, instructions)
  class ProgramPoint < PMLObject
    include QNameObject
    attr_reader :name
    def address ; data['address'] ; end

    def address=(addr); data['address'] = addr; end

    def ProgramPoint.from_pml(mod, data)
      # markers are special global program points
      return Marker.new(data['marker']) if data['marker']

      # otherwise, it is a function or part of a function
      fname = data['function']
      assert("ProgramPoint.from_pml: no function attribute: #{data}") { fname }
      function = mod.by_name(fname)
      raise UnknownFunctionException.new(fname) unless function

      bname = data['block']
      lname = data['loop']
      iname = data['instruction']
      is_edge = ! data['edgesource'].nil?
      if lname || bname
        block = function.blocks.by_name(lname || bname)
        assert("ProgramPoint.from_pml: no such block: #{lname || bname}") do
          block
        end
        if iname
          instruction = block.instructions[Integer(iname)]
          return instruction
        elsif lname
          return block.loop
        else
          return block
        end
      elsif is_edge
        src = data['edgesource']
        bb_src = function.blocks.by_name(src)
        bb_dst = function.blocks.by_name(data['edgetarget']) if data['edgetarget']
        return Edge.new(bb_src, bb_dst)
      else
        return function
      end
    end
  end

  # Qualified name for loops
  class Loop < ProgramPoint
    attr_reader :function, :loopheader, :qname
    def initialize(block, data = nil)
      die("Loop#initialize: #{block.qname} is not a loop header") unless block.loopheader?
      @loopheader = block
      @function = block.function
      @qname = block.qname
      @blocks = [] # Initialized by Function
      set_yaml_repr(data)
    end

    def loops
      @loopheader.loops
    end

    def blocks
      @blocks
    end

    def add_block(b)
      @blocks.push(b)
    end

    def to_s
      "#<Loop: #{loopheader}>"
    end

    def to_pml_ref
      { 'function' => loopheader.function.name, 'loop' => loopheader.name }
    end

    def Loop.from_qname(functions,qn)
      fn,bn = qn.split('/',2).map { |n| YAML::load(n) }
      functions.by_name(fn).blocks.by_name(bn).loop
    end
  end

  class Edge < ProgramPoint
    attr_reader :source, :target
    def initialize(source, target, data = nil)
      assert("PML::Edge: source and target need to be blocks, not #{source.class}/#{target.class}") do
        source.kind_of?(Block) && (target.nil? || target.kind_of?(Block))
      end
      assert("PML::Edge: source and target function need to match") { target.nil? || source.function == target.function }

      @source, @target = source, target
      @name = "#{source.name}->#{target ? target.name : '' }"
      @qname = "#{source.qname}->#{target ? target.qname : 'exit' }"
      set_yaml_repr(data)
    end

    def ref
      self
    end

    def exitedge?
      target.nil?
    end

    def function
      source.function
    end

    def to_s
      "#{source.to_s}->#{target ? target.qname : 'exit'}"
    end

    def to_pml_ref
      pml = { 'function' => source.function.name,
        'edgesource' => source.name }
      pml['edgetarget'] = target.name if target
      pml
    end
  end

  # Markers; we use @ as marker prefix
  class Marker < ProgramPoint
    attr_reader :name
    def initialize(name, data = nil)
      assert("Marker#new: name must not be nil") { ! name.nil? }
      @name = name
      @qname = "@#{@name}"
      set_yaml_repr(data)
    end

    def function
      # no function associated with marker
      nil
    end

    def to_s
      @qname
    end

    def to_pml_ref
      { 'marker' => @name }
    end
  end

  # PML function arguments
  class ArgumentList < PMLList
    extend PMLListGen
    pml_list(:FunctionArgument,[:name])
    # customized constructor
    def initialize(function, data)
      @list = data.map { |a| FunctionArgument.new(function, a) }
      set_yaml_repr(data)
      build_index
    end
  end

  class FunctionArgument < PMLObject
    def initialize(function, data)
      set_yaml_repr(data)
      @function = function
    end

    def name
      data['name']
    end

    def index
      data['index']
    end

    def maps_to_register?
      registers.length == 1
    end

    def registers
      data['registers']
    end
  end

  class SubFunctionList < PMLList
    extend PMLListGen
    pml_list(:SubFunction,[:name])

    # customized constructor
    def initialize(function, data)
      @list = data.map { |a| SubFunction.new(function, a) }
      set_yaml_repr(data)
      build_index
    end
  end

  class SubFunction < PMLObject
    include QNameObject
    attr_reader :name, :blocks
    def initialize(function, data)
      blocknames = data['blocks']
      assert("subfunction: empty block list") { ! blocknames.empty? }
      @name = data['name']
      @qname = "SF:#{function}/#{name}"
      @function = function
      @blocks = blocknames.map { |bname| function.blocks.by_name(bname) }
      set_yaml_repr(data)
    end

    def to_s
      "#{qname}-#{last.name}"
    end

    def function
      entry.function
    end

    def entry
      @blocks.first
    end

    def last
      @blocks.last
    end

    def address
      entry.address
    end

    def size
      assert("SubFunction#size: no addresses available") { entry.address }

      start_address = entry.address
      end_address =
        if last.instructions.empty?
          last.address
        else
          last_instruction = last.instructions.list.last
          last_instruction.address + last_instruction.size
        end
      end_address - start_address
    end
  end

  # PML function wrapper
  class Function < ProgramPoint
    attr_reader :module, :level, :blocks, :loops, :arguments, :subfunctions
    def initialize(mod, data, opts)
      set_yaml_repr(data)
      @name = data['name']
      @level = data['level']
      @module = mod
      @qname = name
      @loops = []
      @labelkey = opts[:labelkey]
      @blocks = BlockList.new(self, data['blocks'])
      @blocks.each do |block|
        @loops.push(block.loop) if block.loopheader?
      end
      @blocks.each do |block|
        block.loops.each do |loop|
          loop.add_block(block)
        end
      end
      @arguments = ArgumentList.new(self, data['arguments'] || [])
      @subfunctions = SubFunctionList.new(self, data['subfunctions'] || [])
    end

    def [](k)
      assert("Function: do not access blocks/loops directly") { k != 'blocks' && k != 'loops' }
      data[k]
    end

    def mapsto
      data['mapsto']
    end

    def to_s
      s = name
      s = "(#{data['mapsto']})#{s}" if data['mapsto']
      s
    end

    def to_pml_ref
      { 'function' => name }
    end

    def function
      self
    end

    def entry_block
      blocks.first
    end

    def address
      data['address'] || blocks.first.address
    end

    def label
      data[@labelkey] || blocks.first.label
    end

    def add_node(node)
      @blocks.add(node)
    end

    def add_subfunction(subfunc_data)
      # This is a ugly hack that is here, because the PML abstraction is not clean
      data['subfunctions'] = (data['subfunctions'] || []).push(subfunc_data)
      @subfunctions.add(SubFunction.new(self, subfunc_data))
    end

    def instructions
      blocks.inject([]) { |insns,b| insns.concat(b.instructions.list) }
    end

    # all (intra-procedural) edges in this function
    def edges
      Enumerator.new do |ss|
        blocks.each do |b|
          b.outgoing_edges.each do |e|
            ss << e
          end
        end
      end
    end

    # all callsites found in this function
    def callsites
      Enumerator.new do |ss|
        blocks.each do |b|
          b.callsites.each do |cs|
            ss << cs
          end
        end
      end
    end

    # find all instructions that a callee may return to
    def identify_return_sites
      blocks.each do |b|
        b.instructions.each do |i|
          i.set_return_site(false)
        end
      end
      blocks.each do |b|
        b.instructions.each do |i|
          if i.calls?
            return_index = i.index + i.delay_slots + 1
            overflow = return_index - b.instructions.length
            if overflow < 0
              b.instructions[return_index].set_return_site(true)
            else
              b.next.instructions[overflow].set_return_site(true)
            end
          end
        end
      end
    end
  end # of class Function

  # Class representing PML Basic Blocks
  class Block < ProgramPoint
    attr_reader :function,:instructions,:loopnest
    def initialize(function,data)
      set_yaml_repr(data)
      @function = function
      @name = data['name']
      @qname = "#{function.name}/#{@name}"

      loopnames = data['loops'] || []
      @loopnest = loopnames.length
      @is_loopheader = loopnames.first == self.name
      @instructions = InstructionList.new(self, data['instructions'] || [])
    end

    def mapsto
      data['mapsto']
    end

    def instructions=(instruction_list)
      data['instructions'] = instruction_list.data
      @instructions = instruction_list
    end

    # Returns a list of instruction bundles (array of instructions per bundle)
    def bundles
      bundle = 0
      instructions.chunk do |i|
        idx = bundle
        bundle += 1 unless i.bundled?
        idx
      end.map{ |b| b[1] }
    end

    # loops (not ready at initialization time)
    def loops
      return @loops if @loops
      @loops = (data['loops'] || []).map { |l| function.blocks.by_name(l).loop }
    end

    # returns true if a CFG edge from the given source node to this block is a back edge
    def backedge_target?(source)
      return false unless loopheader?
      # if the loopnest of the source is smaller than ours, it is certainly not in the same loop
      return false unless source.loopnest >= loopnest
      # if the source is in the same loop, our loops are a suffix of theirs
      # as loop nests form a tree, the suffices are equal if there first element is
      source_loop_index = source.loopnest - loopnest
      source.loops[source_loop_index] == self.loop
    end

    # returns true if a CFG edge from this block to the given target is an exit edge
    def exitedge_source?(target)
      if target.loopnest > loopnest
        false
      elsif target.loopnest < loopnest
        true
      else
        loops[0] != target.loops[0]
      end
    end

    # return true if the block does not contain any actual instructions (labels are ok)
    # FIXME: blocks are currently also considered to be empty if they only contain inline asm
    def empty?
      instructions.empty? || instructions.all? { |i| i.size == 0 }
    end

    # block predecessors (not ready at initialization time)
    def add_predecessor(block)
      assert("Very Bad") { function.blocks.by_name(block.name) }
      if not data['predecessors'].include?(block.name)
        data['predecessors'].push(block.name)
        # Undo Caching
        @predecessors = nil
      end
    end

    def predecessors
      return @predecessors if @predecessors
      @predecessors = (data['predecessors'] || []).map { |s| function.blocks.by_name(s) }.uniq.freeze
    end

    # block successors (not ready at initialization time)
    def add_successor(block)
      if not data['successors'].include?(block.name)
        data['successors'].push(block.name)
        # Undo Caching
        @successors = nil
      end
    end

    def successors
      return @successors if @successors
      @successors = (data['successors'] || []).map { |s| function.blocks.by_name(s) }.uniq.freeze
    end

    # edge to the given target block (reference)
    def edge_to(target)
      Edge.new(self, target)
    end

    # edge to the function exit
    def edge_to_exit
      Edge.new(self, nil)
    end

    # yields outgoing edges
    def outgoing_edges
      Enumerator.new do |ss|
        successors.each do |s|
          ss << edge_to(s)
        end
        ss << edge_to(nil) if self.may_return?
      end
    end

    # set the block directly succeeding this one in the binary layout
    def layout_successor=(block)
      @layout_successor = block
    end

    # return a successor which is (might) be reached via fallthrough
    # NOTE: this is a heuristic at the moment
    def fallthrough_successor
      if successors.include?(@layout_successor)
        @layout_successor
      else
        nil
      end
    end

    # the unique successor, if there is one
    def next
      (successors.length == 1) ? successors.first : nil
    end

    # true if this is a loop header
    def loopheader?
      @is_loopheader
    end

    # true if this is the header of a loop that has a preheader
    def has_preheader?
      return @has_preheader unless @has_preheader.nil?
      return (@has_preheader = false) unless loopheader?
      preheaders = []
      predecessors.each do |pred|
        next if self.backedge_target?(pred)
        preheaders.push(pred)
      end
      @has_preheader = (preheaders.length == 1)
    end

    # true if this block may return from the function
    def may_return?
      @returnsites ||= instructions.list.select { |i| i.returns? }
      ! @returnsites.empty? || must_return?
    end

    def must_return?
      successors.empty?
    end

    # whether this block has a call instruction
    def calls?
      ! callsites.empty?
    end

    # list of callsites in this block
    def callsites
      return @callsites if @callsites
      @callsites = instructions.list.select { |i| i.callees.length > 0 }
    end

    # XXX: LLVM specific/arch specific
    def label
      Block.get_label(function.name, name)
    end

    # XXX: LLVM specific/arch specific
    def Block.get_label(fname,bname)
      "LBB#{fname}_#{bname}"
    end

    # location hint (e.g. file:line)
    def src_hint
      data['src-hint'] || ''
    end

    # ProgramPoint#block (return self)
    def block
      self
    end

    # reference to the loop represented by the block (needs to be the header of a reducible loop)
    def loop
      assert("Block#loop: not a loop header") { self.loopheader? }
      return @loop if @loop
      @loop = Loop.new(self)
    end

    def Block.from_qname(functions,qn)
      fn,bn = qn.split('/',2).map { |n| YAML::load(n) }
      functions.by_name(fn).blocks.by_name(bn)
    end

    def to_pml_ref
      { 'function' => function.name, 'block' => name }
    end

    # Returns all blocks that are reachable from this block. Flooding
    # of the graph is stopped at the argument block. This is useful
    # for single-entry; single-exit regions
    def reachable_till(stop)
      rs = reachable_set(self) do |block|
        if block != stop
          block.successors
        else
          []
        end
      end
      rs
    end

    # string representation
    def to_s
      if function.mapsto
        "(#{function.mapsto})#{qname}"
      else
        qname
      end
    end
  end

  # Proxy for PML instructions
  class Instruction < ProgramPoint
    attr_reader :block
    def initialize(block,data)
      set_yaml_repr(data)
      @block = block
      @name = index
      @qname = "#{block.qname}/#{@name}"
    end

    def index
      data['index']
    end

    def to_pml_ref
      { 'function' => function.name, 'block' => block.name, 'instruction' => name }
    end

    def Instruction.from_qname(functions,qn)
      fn,bn,iname = qn.split('/',3).map { |n| YAML::load(n) }
      functions.by_name(fn).blocks.by_name(bn.to_s).instructions[iname]
    end

    def marker
      data['marker']
    end

    # type of branch this instruction realizes (if any)
    def branch_type
      data['branch-type']
    end

    # whether this instruction includes a call
    def calls?
      ! callees.empty?
    end

    # the corresponding return instruction, if this is a call
    def call_return_instruction
      assert("call_return_instruction: not a call") { calls? }
      r_pre_index = index + self.delay_slots
      block.instructions[r_pre_index].next
    end

    # calless of this instruction (labels)
    def callees
      data['callees'] || []
    end

    def update_callees(callees)
      data['callees'] = callees
    end

    # called functions
    def called_functions
      return nil if unresolved_call?
      data['callees'].reject do |n|
        # XXX: hackish
        # filter known pseudo functions on bitcode
        n =~ /llvm\..*/ ||
        n =~ /__aeabi_uidivmod/ ||
        n =~ /__aeabi_idivmod/ ||
        n =~ /__udivsi3/ ||
        n =~ /__divsi3/ ||
        n =~ /__udivmodsi4/
      end.map do |n|
        block.function.module.by_label_or_name(n, true)
      end
    end

    # whether this instruction is an indirect (unresolved) call
    def unresolved_call?
      callees.include?("__any__")
    end

    # whether this instruction isa branch
    def branches?
      ! branch_targets.empty?
    end

    # branch targets
    def branch_targets
      return @branch_targets if @branch_targets
      @branch_targets = (data['branch-targets'] || []).map { |s| function.blocks.by_name(s) }.uniq.freeze
    end

    # whether this instruction returns
    def returns?
      branch_type == 'return'
    end

    # whether control-flow may return to this instruction
    def may_return_to?
      function.identify_return_sites if @may_return_to.nil?
      @may_return_to
    end

    # mark this is instruction as return point
    def set_return_site(may_return_to=true)
      @may_return_to = may_return_to
    end

    # number of delay slots, if this is a branch instruction
    def delay_slots
      data['branch-delay-slots'] || 0
    end

    def sc_arg
      data['stack-cache-argument']
    end

    def sc_fill
      data['stack-cache-fill']
    end

    def sc_spill
      data['stack-cache-spill']
    end

    def memmode
      data['memmode']
    end

    def memtype
      data['memtype']
    end

    def memtype=(mt)
      data['memtype'] = mt
    end

    def load_mem?
      data['memmode'] == 'load'
    end

    def bundled?
      data['bundled']
    end

    # whether the given block is still a successor if we are at this instruction in the current block
    def live_successor?(target)
      ix = index
      while i = block.instructions[ix]
        return true if i.branch_targets.include?(target)
        ix += 1
      end
      return true if block.fallthrough_successor == target
      return false
    end

    # the function corresponding the instruction is contained in
    def function
      block.function
    end

    # ProgramPoint#instruction (return self)
    def instruction
      self
    end

    # the next instruction in the instruction list, or the first instruction of the only successor block
    def next
      block.instructions[index + 1] || (block.next ? block.next.instructions.first : nil)
    end

    # size of this instruction (binary level)
    def size   ; data['size'] ; end

    def opcode ; data['opcode'] ; end

    def to_s
      s = qname
      s = "(#{function.mapsto})#{s}" if function.mapsto
      s
    end
  end

  # List of relation graphs (unmodifiable)
  class RelationGraphList < PMLList

    # non-standard pml list
    #
    def initialize(data, srclist, dstlist)
      @list = data.map { |rgdata| RelationGraph.new(rgdata, srclist, dstlist) }
      set_yaml_repr(data)
      build_lookup
    end

    # whether there is a relation graph involving function
    # @name@ on level @level@
    #
    def has_named?(name, level)
      ! @named[level][name].nil?
    end

    # get relation graph by function's name on the specified level
    #
    def by_name(name, level)
      assert("RelationGraphList#by_name: level != :src,:dst") { [:src,:dst].include?(level) }
      lookup(@named[level], name, "#{level}-name", false)
    end

    # Special Case, because non-standard PML list
    def add(item)
      list.push(item)
      data.push(item.data) if @data
    end

    def build_lookup
      @named = { :src => {}, :dst => {} }
      @list.each do |rg|
        add_lookup(@named[:src], rg.src.name, rg, "src-name")
        add_lookup(@named[:dst], rg.dst.name, rg, "dst-name")
      end
    end
  end

  # List of relation graph nodes (unmodifiable)
  class RelationNodeList < PMLList
    extend PMLListGen
    pml_name_index_list(:RelationNode)

    def initialize(rg, data)
      @list = data.map { |n| RelationNode.new(rg, n) }
      set_yaml_repr(data)
      build_index
      build_relation_index
    end

    # get relation graph node(s) that reference the specified basic block
    #
    def by_basic_block(bb, level)
      assert("RelationNodeList#by_basic_block: level != :src,:dst") { [:src,:dst].include?(level) }
      lookup(@basic_block_index[level], bb, "#{level}-block", false) || []
    end

private
    def build_relation_index
      @basic_block_index = { :src => {}, :dst => {} }
      @list.each do |rgn|
        [:src,:dst].each do |level|
          bb = rgn.get_block(level)
          next unless bb
          (@basic_block_index[level][bb] ||= []).push(rgn)
        end
      end
    end
  end

  # Relation Graphs
  class RelationGraph < PMLObject
    attr_reader :src_functions, :dst_functions, :src, :dst, :nodes
    def initialize(data,src_funs,dst_funs)
      set_yaml_repr(data)
      @src_functions, @dst_functions = src_funs, dst_funs
      @src = src_funs.by_name(data['src']['function'])
      @dst = dst_funs.by_name(data['dst']['function'])
      @nodes = RelationNodeList.new(self, data['nodes'])
    end

    def status
      data['status']
    end

    def accept?(options)
      status == 'valid' or (options.accept_corrected_rgs and status == 'corrected')
    end

    def get_function(level)
      level == :src ? @src : @dst
    end

    def add_node(node)
      @nodes.add(node)
    end

    def qname
      "#{src.qname}<>#{dst.qname}"
    end

    def to_s
      "#{src}<->#{dst}"
    end
  end

  # Relation Graph node
  class RelationNode < PMLObject
    include QNameObject
    attr_reader :name, :rg
    def initialize(rg, data)
      set_yaml_repr(data)
      @rg = rg
      @name = data['name']
      @qname = "#{@rg.qname}_#{@name}"
      @successors = {} # lazy initialization
    end

    # get basic block for the specified level
    # :progress and :entry provide both blocks, :src and :dst
    # blocks on the respective level, and :exit no block
    #
    def get_block(level)
      return nil unless data["#{level}-block"]
      rg.get_function(level).blocks.by_name(data["#{level}-block"])
    end

    # returns one out of [ :progress, :dst, :src, :entry, :exit ]
    #
    def type
      data['type'].to_sym
    end

    # true if this is a :dst or :src node
    #
    def unmapped?
      type == :src || type == :dst
    end

    def successors_matching(block, level)
      assert("successors_matching: nil argument") { ! block.nil? }
      successors(level).select do |b|
        succblock = b.get_block(level)
        ! succblock.nil? && succblock == block
      end
    end

    def add_successor(node, level)
      data["#{level}-successors"].push(node.name)
      @successors[level] = nil
    end

    def successors(level)
      return @successors[level] if @successors[level]
      @successors[level] = (data["#{level}-successors"] || []).map do |succ|
        @rg.nodes.by_name(succ)
      end.uniq
      @successors[level]
    end

    # Flooding of the graph is stopped at the argument node. This is useful
    # for single-entry; single-exit regions
    def reachable_till(stop)
      rs = reachable_set(self) do |node|
        if node != stop
          node.successors(:src) + node.successors(:dst)
        else
          []
        end
      end
      rs
    end

    def to_s
      "#{type}:#{qname}"
    end
  end

  class ABBList < PMLList
    extend PMLListGen
    pml_list(:ABB, [:name], [])

    def initialize(funs, blocks)
      @list = blocks.map { |n| ABB.new(funs, n) }
      set_yaml_repr(data)
      build_index
    end
  end

  # Class representing PML Atomic Basic Block
  class ABB < PMLObject
    attr_reader :name, :function, :machine_function, :entry_block, :exit_block
    def initialize(relation_graphs, data)
      set_yaml_repr(data)
      @rg = relation_graphs.by_name(data['function'], :src)
      assert("No relationship graph for #{data['function']} found") do
        @rg != nil
      end
      @function = @rg.get_function(:src)
      @machine_function = @rg.get_function(:dst)

      @name = data['name']
      @entry_block = @function.blocks.by_name(data['entry-block'])
      @exit_block  = @function.blocks.by_name(data['exit-block'])
      assert("Could not find ABB Entry/Exit Blocks #{data}") do
        @entry_block != nil and @exit_block != nil
      end
      @regions = nil
    end

    def qname
      @name
    end
    class RegionContainer
      attr_accessor :entry_node, :exit_node, :nodes

      def initialize(entry_node=nil, exit_node=nil)
        if entry_node
          @entry_node, @exit_node = entry_node, exit_node
          @nodes = @entry_node.reachable_till(@exit_node).to_a
        else
          @entry_node, @exit_node, @nodes = nil, nil, []
        end
      end
    end

    def get_region(level)
      return @regions[level] if @regions
      # Calculate the region from our data
      entry_rg = @rg.nodes.by_basic_block(@entry_block, :src)
      exit_rg  = @rg.nodes.by_basic_block(@exit_block, :src)

      # Validity Checking on the ABB
      assert("ABB is not well formed; Entry/Exit BB is not uniquly mappable (#{to_s}, #{entry_rg}, #{exit_rg})") do
        entry_rg.length == 1 and exit_rg.length == 1
      end

      rg_region = RegionContainer.new(entry_rg[0], exit_rg[0])

      # Entry and Exit must be progress nodes (or similar)
      assert("ABB is not well formed; Entry/Exit nodes are of wrong type") do
        [:progress, :entry, :exit].include?(rg_region.entry_node.type) and
          [:progress, :entry, :exit].include?(rg_region.exit_node.type)
      end

      # Generate Bitcode and Machine Regions
      bitcode_region, machine_region = [:src, :dst].map do |type|
        RegionContainer.new(rg_region.entry_node.get_block(type),
                            rg_region.exit_node.get_block(type))
      end

      assert("ABB is not well formed; No Single-Entry/Single-Exit region all levels") do
        rg_nodes_lhs = Set.new rg_region.nodes.map{ |n| n.get_block(:src) }
        rg_nodes_rhs = Set.new rg_region.nodes.map{ |n| n.get_block(:dst) }

        rg_nodes_lhs == Set.new(bitcode_region.nodes) and rg_nodes_rhs == Set.new(machine_region.nodes)
      end
      @regions = {
        :rg => rg_region,
        :src => bitcode_region,
        :dst => machine_region,
      }
      @regions[level]
    end

    def to_s
      "#{@function.name}/#{@name}"
    end
  end

  class GCFGNodeList < PMLList
    extend PMLListGen
    pml_list(:GCFGNode, [:index], [])

    def initialize(abbs, nodes)
      @list = nodes.map { |n| GCFGNode.new(abbs, n) }
      @list.each_with_index do |item, index|
        assert("Invalid Indices of GCFG Edges; Nodes are sorted") do
          item.index == index
        end
      end
      @list.each { |n| n.connect(@list) }
      set_yaml_repr(data)
      build_index
    end
  end

  # Class representing PML GCFG Node
  class GCFGNode < PMLObject
    attr_reader :abb, :successors, :predecessors
    def initialize(abbs, data)
      set_yaml_repr(data)
      @abb = abbs[data['abb']]
      @predecessors = []
    end

    def function
      abb.machine_function
    end

    def connect(nodes)
      @successors = data['successors'].map { |i| nodes[i] }
      data['successors'].each do |i|
        nodes[i].add_predecessor(self)
      end
    end

    def index
      data['index']
    end

    def to_s
      "GCFG:N#{index}(#{@abb.name})"
    end

    def qname
      "GCFG:N#{index}"
    end

    def may_return?
      return @successors.empty?
    end

    ### MOCKUP like Block
    def edge_to(target)
      Edge.new(self.abb.get_region(:dst).exit_node, target.abb.get_region(:dst).entry_node)
    end

    # edge to the function exit
    def edge_to_exit
      Edge.new(self.abb.get_region(:dst).exit_node, nil)
    end

    protected
    def add_predecessor(node)
      @predecessors.push(node)
    end
  end

  # Global Control Flow Graph wrapper
  class GCFG < PMLObject
    include QNameObject
    attr_reader :name, :level, :blocks, :nodes, :entry_node

    def initialize(data, relation_graphs)
      set_yaml_repr(data)
      @name = data['name']
      @qname = "GCFG:#{name}"
      @level = data['level']
      @blocks = ABBList.new(relation_graphs, data['blocks'])
      @nodes  = GCFGNodeList.new(@blocks, data['nodes'])
      # Find the Entry Edge into the system
      entry_nodes = @nodes.select { |e| e.predecessors.length == 0 }
      die("GCFG #{name} is not well formed, multiple entries") unless entry_nodes.length == 1
      @entry_node = entry_nodes[0]
    end

    def to_s
      @qname
    end
  end

  # List of Global Control Flow Graphs
  class GCFGList < PMLList
    extend PMLListGen
    pml_name_index_list(:GCFG, [],[])

    # customized constructor
    def initialize(data, relation_graphs)
      @list = data.map do |g|
        GCFG.new(g, relation_graphs)
      end
      set_yaml_repr(data)
      build_index
    end
  end



end # module PML
