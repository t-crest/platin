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

    mapping = {}
    gcfg.edges.each { |edge|
      bc_region, mc_region = copy_basic_blocks(edge, bitcode_function, machine_function)
      mapping[edge] = [bc_region, mc_region]
    }

    # Connect Regions according to the GCFG Edges
    mapping.each { |source, value|
      source_bc_region, source_mc_region = value
      source.successor_edges.each { |target|
        target_bc_region, target_mc_region = mapping[target]

        # Add Bitcode Edges
        source_bc_region.exit_node.add_successor(target_bc_region.entry_node)
        target_bc_region.entry_node.add_predecessor(source_bc_region.exit_node)

        # Add Machinecode Edges
        source_mc_region.exit_node.add_successor(target_mc_region.entry_node)
        target_mc_region.entry_node.add_predecessor(source_mc_region.exit_node)
      }
    }
  end

  private


  def copy_basic_blocks(gcfg_edge, bitcode_function, machine_function)
    abb = gcfg_edge.abb
    rg = @pml_in.relation_graphs.by_name(abb.function.name, :src)

    entry_rg = rg.nodes.by_basic_block(abb.entry_block, :src)
    exit_rg  = rg.nodes.by_basic_block(abb.exit_block, :src)

    # Validity Checking on the ABB
    assert("ABB is not well formed; Entry/Exit BB is not uniquly mappable") {
      entry_rg.length == 1 and exit_rg.length == 1
    }
    entry_rg = entry_rg[0]
    exit_rg = exit_rg[0]

    # Entry and Exit must be progress nodes (or similar)
    assert("ABB is not well formed; Entry/Exit nodes are of wrong type") {
      [:progress, :entry, :exit].include?(entry_rg.type) and
        [:progress, :entry, :exit].include?(exit_rg.type)
    }

    # Generate Regions
    bitcode_region, machine_region = [:src, :dst].map { |type|
      region = RegionContainer.new
      region.name = "R#{gcfg_edge.index}"
      region.entry_node = entry_rg.get_block(type)
      region.exit_node  = exit_rg.get_block(type)
      region.nodes = region.entry_node.reachable_till(region.exit_node)
      region
    }

    assert("ABB is not well formed; No Single-Entry/Single-Exit region all levels") {
      rg_nodes = entry_rg.reachable_till(exit_rg)
      rg_nodes_lhs = Set.new rg_nodes.map{|n| n.get_block(:src)}
      rg_nodes_rhs = Set.new rg_nodes.map{|n| n.get_block(:dst)}

      rg_nodes_lhs == bitcode_region.nodes and rg_nodes_rhs == machine_region.nodes
    }

    # Copy Blocks to new Functions
    new_bc_region = copy_region_to_function(bitcode_region, bitcode_function)
    new_mc_region = copy_region_to_function(machine_region, machine_function)

    [new_bc_region, new_mc_region]
  end

  def copy_region_to_function(region, function)
    # Copy Blocks to Bitcode Functions
    target_region = RegionContainer.new
    blocks_within = Set.new region.nodes.map {|x| x.name}
    region.nodes.each {|bb_in|
      data = bb_in.data.dup
      data["name"]   = region.map_name(data["name"])
      data["mapsto"] = region.map_name(data["mapsto"]) if data["mapsto"]

      map_sequence = lambda { |seq|
        seq \
          # Select only labels that are within the current region
          .select {|name| blocks_within.include? name} \
          .map    {|name| region.map_name(name) }
      }

      data["successors"]   = map_sequence.(data["successors"])
      data["predecessors"] = map_sequence.(data["predecessors"])
      data["loops"]        = map_sequence.(data["loops"]) if data["loops"]
      if data["instructions"]
        data["instructions"].each {|instr|
          if instr["branch-targets"]
            instr["branch-targets"] = map_sequence.(instr["branch-targets"])
          end
        }
      end

      bb = function.blocks.add(Block.new(function, data))

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
    address += 1
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
