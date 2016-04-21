#!/usr/bin/env ruby

require 'platin'

include PML

class GCFGTool
  attr_reader :pml_in, :pml_out, :options
  def initialize(pml_in, options)
    @pml_in, @options = pml_in, options
    @pml_out = pml_in.clone_empty
  end

  class RegionContainer
    @name = nil
    @entry_node = nil
    @exit_node = nil
    @nodes = nil
    attr_accessor :name, :entry_node, :exit_node, :nodes

    def initialize
      @nodes = []
    end

    def map_name(name)
      "#{@name}_#{name}"
    end
  end

  def transform_gcfg(gcfg, address)
    # Frist we add some functions and containers for our data
    ## Bitcode Function
    data = {'name'=> gcfg.name, 'level'=>'bitcode',
            'blocks'=> [], 'address'=> address}
    bitcode_function = @pml_out.bitcode_functions.add_function(data)

    ## Machine Code Function
    data = {'name'=> address, 'mapsto'=> gcfg.name,
            'level'=>'machinecode', 'blocks'=> [], 'address'=> 0}
    machine_function = @pml_out.machine_functions.add_function(data)

    # Relationship Graph Container
    data = {'src'=> {'level'=>'bitcode', 'function' => bitcode_function.name},
            'dst'=> {'level'=>'machinecode', 'function' => machine_function.name},
           'nodes'=> [], 'status'=>'valid'}
    rg = RelationGraph.new(data, @pml_out.bitcode_functions, @pml_out.machine_functions)
    @pml_out.relation_graphs.add(rg)

    # Cut out Regions identified by the abb field of the edge object.
    # The region is copied to the given functions, relation graphs.
    mapping = {}
    gcfg.edges.each { |edge|
      rg_region, bc_region, mc_region = copy_basic_blocks(edge, rg, bitcode_function, machine_function)
      mapping[edge] = [rg_region, bc_region, mc_region]
    }

    exit_node = rg.add_node(RelationNode.new(rg, {'name'=> 'RG_exit', 'type' => 'exit'}))
    # Connect Regions according to the GCFG Edges
    mapping.each { |source, value|
      src_rg, src_bc, src_mc = value
      source.successor_edges.each { |dst|
        dst_rg, dst_bc, dst_mc = mapping[dst]

        # Add Bitcode Edges
        src_bc.exit_node.add_successor(dst_bc.entry_node)
        dst_bc.entry_node.add_predecessor(src_bc.exit_node)

        # Add Machinecode Edges
        src_mc.exit_node.add_successor(dst_mc.entry_node)
        dst_mc.entry_node.add_predecessor(src_mc.exit_node)

        # Add relationship edges
        src_rg.exit_node.add_successor(dst_rg.entry_node, :src)
        src_rg.exit_node.add_successor(dst_rg.entry_node, :dst)
      }
      # Region has no followup regions. It must be connected to an
      # Exit Region
      if source.successor_edges.length == 0
        src_rg.exit_node.add_successor(exit_node, :src)
        src_rg.exit_node.add_successor(exit_node, :dst)
      end
    }

    # Now we have to identify and copy all functions that are called
    bc_funcs = Set.new(bitcode_function.instructions\
                        .collect_concat { |instr| instr.callees||[] })
    mc_funcs = Set.new(machine_function.instructions\
                        .collect_concat { |instr| instr.callees||[] })
    bc_funcs.each { |func|
      func = @pml_in.bitcode_functions.by_name(func)
      @pml_out.bitcode_functions.add_function(func.data.dup)
    }
    mc_funcs.each { |func|
      data = @pml_in.machine_functions.by_label(func).data.dup
      address += 1
      data['name'] = address
      @pml_out.machine_functions.add_function(data)
      if bc_funcs.include?(data['mapsto'])
        data = @pml_in.relation_graphs.by_name(data['mapsto'], :src).data.dup
        data['dst']['function'] = address
        @pml_out.relation_graphs.add(RelationGraph.new(data, @pml_out.bitcode_functions, @pml_out.machine_functions))
      end
    }
    mc_funcs.intersection(bc_funcs).each { |func|

    }
  end

  private

  def copy_basic_blocks(gcfg_edge, rg_graph, bitcode_function, machine_function)
    abb = gcfg_edge.abb
    rg = @pml_in.relation_graphs.by_name(abb.function.name, :src)

    entry_rg = rg.nodes.by_basic_block(abb.entry_block, :src)
    exit_rg  = rg.nodes.by_basic_block(abb.exit_block, :src)

    # Validity Checking on the ABB
    assert("ABB is not well formed; Entry/Exit BB is not uniquly mappable") {
      entry_rg.length == 1 and exit_rg.length == 1
    }
    rg_region = RegionContainer.new
    rg_region.name = "R#{gcfg_edge.index}"
    rg_region.entry_node = entry_rg[0]
    rg_region.exit_node = exit_rg[0]
    rg_region.nodes =  rg_region.entry_node.reachable_till(rg_region.exit_node)

    # Entry and Exit must be progress nodes (or similar)
    assert("ABB is not well formed; Entry/Exit nodes are of wrong type") {
      [:progress, :entry, :exit].include?(rg_region.entry_node.type) and
        [:progress, :entry, :exit].include?(rg_region.exit_node.type)
    }

    # Generate Bitcode and Machine Regions
    bitcode_region, machine_region = [:src, :dst].map { |type|
      region = RegionContainer.new
      region.name = "R#{gcfg_edge.index}"
      region.entry_node = rg_region.entry_node.get_block(type)
      region.exit_node  = rg_region.exit_node.get_block(type)
      region.nodes = region.entry_node.reachable_till(region.exit_node)
      region
    }

    assert("ABB is not well formed; No Single-Entry/Single-Exit region all levels") {
      rg_nodes_lhs = Set.new rg_region.nodes.map{|n| n.get_block(:src)}
      rg_nodes_rhs = Set.new rg_region.nodes.map{|n| n.get_block(:dst)}

      rg_nodes_lhs == bitcode_region.nodes and rg_nodes_rhs == machine_region.nodes
    }

    # Copy Blocks to new Functions
    new_bc_region = copy_region_to_function(bitcode_region, bitcode_function, Block)
    new_mc_region = copy_region_to_function(machine_region, machine_function, Block)
    new_rg_region = copy_region_to_function(rg_region, rg_graph, RelationNode)

    # Each Function for the Patmos architecture is divided into
    # different subfunctions, which are loaded into the function
    # cache, therefore, we look for all subfunctions our abb covers.
    rg.get_function(:dst).subfunctions.select {|subfunction|
      blocks_included = subfunction.blocks.map {|block| machine_region.nodes.include? block }
      if blocks_included.any?
        assert("If one block of a subfunction is included in the region, all subfunction blocks must be included") {
          blocks_included.all?
        }
        # Copy and rename subfunction to machien_code function
        data = subfunction.data.dup
        data['name'] = machine_region.map_name(data['name'])
        data['blocks'] = data['blocks'].map{|x| machine_region.map_name(x) }
        machine_function.add_subfunction(data)
      end
    }

    [new_rg_region, new_bc_region, new_mc_region]
  end

  def copy_region_to_function(region, function, factory)
    # Copy Blocks to Bitcode Functions
    target_region = RegionContainer.new
    blocks_within = Set.new region.nodes.map {|x| x.name}
    region.nodes.each {|bb_in|
      data = bb_in.data.dup
      ['name', 'mapsto', 'src-block', 'dst-block'].each {|key|
        data[key] = region.map_name(data[key]) if data[key]
      }

      map_sequence = lambda { |seq|
        seq \
          # Select only labels that are within the current region
          .select {|name| blocks_within.include? name} \
          .map    {|name| region.map_name(name) }
      }

      ['successors', 'predecessors', 'src-successors', 'dst-successors', 'loops'].each {|key|
        data[key] = map_sequence.(data[key]) if data[key]
      }

      if data["instructions"]
        data["instructions"].each {|instr|
          if instr["branch-targets"]
            instr["branch-targets"] = map_sequence.(instr["branch-targets"])
          end
        }
      end

      # Make all inner nodes progress nodes for now
      if factory == RelationNode and ['exit', 'entry'].include?(data['type'])
        data['type'] = 'progress'
      end

      bb = function.add_node(factory.new(function, data))

      # Construct Region in the target
      target_region.nodes.push(bb)
      target_region.entry_node = bb if region.entry_node == bb_in
      target_region.exit_node = bb if region.exit_node == bb_in
    }
    target_region
  end
end

if __FILE__ == $0
  SYNOPSIS=<<EOF if __FILE__ == $0
Transform Program according to the global control flow graph
EOF
  options, args = PML::optparse([],"", SYNOPSIS) do |opts|
    opts.needs_pml
    opts.writes_pml
  end
  pml_in = PMLDoc.from_files(options.input)

  rewriter = GCFGTool.new(pml_in, options)
  address = 0
  pml_in.global_cfgs.each {|gcfg|
    rewriter.transform_gcfg(gcfg, address)
    address += 100000
  }

  # gcfg = pml_in.global_cfgs.by_name("system")

  # gcfg.blocks.each {|e|
  #   rg = pml_in.relation_graphs.by_name(e.function.name, :src)

  #   entry_rg = rg.nodes.by_basic_block(e.entry_block, :src)
  #   exit_rg  = rg.nodes.by_basic_block(e.exit_block, :src)

  #   # Validity Checking on the ABB
  #   assert("ABB is not well formed; Entry/Exit BB is not uniquly mappable") {
  #     entry_rg.length == 1 and exit_rg.length == 1
  #   }
  #   entry_rg = entry_rg[0]
  #   exit_rg = exit_rg[0]

  #   assert("ABB is not well formed; Entry/Exit nodes are of wrong type") {
  #     [:progress, :entry, :exit].include?(entry_rg.type) and
  #       [:progress, :entry, :exit].include?(exit_rg.type)
  #   }

  #   assert("ABB is not well formed; No Single-Entry/Single-Exit region all levels") {
  #     rg_nodes = entry_rg.reachable_till(exit_rg)
  #     rg_nodes_lhs = Set.new rg_nodes.map{|n| n.get_block(:src)}
  #     rg_nodes_rhs = Set.new rg_nodes.map{|n| n.get_block(:dst)}

  #     bitcode_blocks = entry_rg.get_block(:src).reachable_till(exit_rg.get_block(:src))
  #     machine_blocks = entry_rg.get_block(:dst).reachable_till(exit_rg.get_block(:dst))

  #     rg_nodes_lhs == bitcode_blocks and rg_nodes_rhs == machine_blocks
  #   }

  # }

  rewriter.pml_out.dump_to_file(options.output)
end
