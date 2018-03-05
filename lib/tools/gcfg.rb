#!/usr/bin/env ruby

require 'platin'
require 'English'

include PML

class GCFGTool
  attr_reader :pml_in, :pml_out, :options
  def initialize(pml_in, options)
    @pml_in, @options = pml_in, options
    @pml_out = pml_in.clone_empty
  end

  def transform_gcfg(gcfg, address)
    # Frist we add some functions and containers for our data
    ## Bitcode Function
    data = { 'name' => gcfg.name, 'level' => 'bitcode',
             'blocks' => [], 'address' => address }
    bitcode_function = @pml_out.bitcode_functions.add_function(data)

    ## Machine Code Function
    data = { 'name' => address, 'mapsto' => gcfg.name,
             'level' => 'machinecode', 'blocks' => [], 'address' => 0 }
    machine_function = @pml_out.machine_functions.add_function(data)

    # Relationship Graph Container
    data = { 'src' => { 'level' => 'bitcode', 'function' => bitcode_function.name },
             'dst' => { 'level' => 'machinecode', 'function' => machine_function.name },
             'nodes' => [], 'status' => 'valid' }
    rg = RelationGraph.new(data, @pml_out.bitcode_functions, @pml_out.machine_functions)
    @pml_out.relation_graphs.add(rg)

    # Cut out Regions identified by the abb field of the edge object.
    # The region is copied to the given functions, relation graphs.
    mapping = {}
    gcfg.nodes.each do |gcfg_node|
      rg_region, bc_region, mc_region = copy_basic_blocks(gcfg_node, rg, bitcode_function, machine_function)
      mapping[gcfg_node] = [rg_region, bc_region, mc_region]
    end

    exit_node = rg.add_node(RelationNode.new(rg, { 'name' => 'RG_exit', 'type' => 'exit' }))
    # Connect Regions according to the GCFG Edges
    mapping.each do |source, value|
      src_rg, src_bc, src_mc = value
      source.successors.each do |dst|
        dst_rg, dst_bc, dst_mc = mapping[dst]

        # Add Bitcode Edges
        src_bc.exit_node.add_successor(dst_bc.entry_node)
        dst_bc.entry_node.add_predecessor(src_bc.exit_node)

        # Add Machinecode Edges
        src_mc.exit_node.add_successor(dst_mc.entry_node)
        dst_mc.entry_node.add_predecessor(src_mc.exit_node)

        src_mc.exit_node.data["instructions"].each do |instr|
          if instr["branch-targets"]
            idx = instr["branch-targets"].find_index(:next_node)
            instr["branch-targets"][idx] = dst_mc.entry_node.data["name"] if idx != nil
          end
          break
        end

        # Add relationship edges
        src_rg.exit_node.add_successor(dst_rg.entry_node, :src)
        src_rg.exit_node.add_successor(dst_rg.entry_node, :dst)
      end
      # Region has no followup regions. It must be connected to an
      # Exit Region
      if source.successors.empty?
        src_rg.exit_node.add_successor(exit_node, :src)
        src_rg.exit_node.add_successor(exit_node, :dst)
      end
    end

    # Now we have to identify and copy all functions that are called
    bc_funcs = Set.new(bitcode_function.instructions\
                        .collect_concat { |instr| instr.callees || [] })
    mc_funcs = Set.new(machine_function.instructions\
                        .collect_concat { |instr| instr.callees || [] })
    bc_funcs.each do |func|
      func = @pml_in.bitcode_functions.by_name(func)
      @pml_out.bitcode_functions.add_function(func.data.dup)
    end
    mc_funcs.each do |func|
      data = @pml_in.machine_functions.by_label(func).data.dup
      address += 1
      data['name'] = address
      @pml_out.machine_functions.add_function(data)
      if bc_funcs.include?(data['mapsto'])
        data = @pml_in.relation_graphs.by_name(data['mapsto'], :src).data.dup
        data['dst']['function'] = address
        @pml_out.relation_graphs.add(RelationGraph.new(data, @pml_out.bitcode_functions, @pml_out.machine_functions))
      end
    end
    mc_funcs.intersection(bc_funcs).each do |func|
    end
  end

private

  def copy_basic_blocks(gcfg_node, rg_graph, bitcode_function, machine_function)
    abb = gcfg_node.abb
    rg = @pml_in.relation_graphs.by_name(abb.function.name, :src)

    rg_region = abb.get_region(:rg)
    bitcode_region = abb.get_region(:src)
    machine_region = abb.get_region(:dst)

    # Copy Blocks to new Functions
    name_mapper = lambda { |name| "#{gcfg_node.qname}_#{name}" }
    new_bc_region = copy_region_to_function(name_mapper, bitcode_region, bitcode_function, Block)
    new_mc_region = copy_region_to_function(name_mapper, machine_region, machine_function, Block)
    new_rg_region = copy_region_to_function(name_mapper, rg_region, rg_graph, RelationNode)

    # Each Function for the Patmos architecture is divided into
    # different subfunctions, which are loaded into the function
    # cache, therefore, we look for all subfunctions our abb covers.
    rg.get_function(:dst).subfunctions.select &(lambda { |subfunction|
      blocks_included = subfunction.blocks.map { |block| machine_region.nodes.include? block }
      if blocks_included.any?
        assert("If one block of a subfunction is included in the region, all subfunction blocks must be included") do
          blocks_included.all?
        end
        # Copy and rename subfunction to machien_code function
        data = subfunction.data.dup
        data['name'] = name_mapper.(data['name'])
        data['blocks'] = data['blocks'].map { |x| name_mapper.(x) }
        machine_function.add_subfunction(data)
      end
    })

    [new_rg_region, new_bc_region, new_mc_region]
  end

  def copy_region_to_function(name_mapper, region, function, factory)
    # Copy Blocks to Bitcode Functions
    target_region = ABB::RegionContainer.new
    blocks_within = Set.new region.nodes.map { |x| x.name }
    region.nodes.each do |bb_in|
      data = Marshal.load(Marshal.dump(bb_in.data))
      ['name', 'mapsto', 'src-block', 'dst-block'].each do |key|
        data[key] = name_mapper.(data[key]) if data[key]
      end

      map_sequence = lambda { |seq|
        seq \
          # Select only labels that are within the current region
          .select { |name| blocks_within.include? name } \
          .map    { |name| name_mapper.(name) }
      }

      ['successors', 'predecessors', 'src-successors', 'dst-successors', 'loops'].each do |key|
        data[key] = map_sequence.(data[key]) if data[key]
      end

      if data["instructions"]
        data["instructions"].each do |instr|
          if instr["branch-targets"]
            if bb_in == region.exit_node
              instr["branch-targets"] = map_sequence.(instr["branch-targets"]) + [:next_node]
            else
              instr["branch-targets"] = map_sequence.(instr["branch-targets"])
            end
          end
        end
      end

      # Make all inner nodes progress nodes for now
      data['type'] = 'progress' if (factory == RelationNode) && ['exit', 'entry'].include?(data['type'])

      bb = function.add_node(factory.new(function, data))

      # Construct Region in the target
      target_region.nodes.push(bb)
      target_region.entry_node = bb if region.entry_node == bb_in
      target_region.exit_node = bb if region.exit_node == bb_in
    end
    target_region
  end
end

if __FILE__ == $PROGRAM_NAME
  SYNOPSIS = <<-EOF
    Transform Program according to the global control flow graph
  EOF
  options, args = PML::optparse([],"", SYNOPSIS) do |opts|
    opts.needs_pml
    opts.writes_pml
  end
  pml_in = PMLDoc.from_files(options.input, options)

  rewriter = GCFGTool.new(pml_in, options)
  address = 0
  pml_in.global_cfgs.each do |gcfg|
    rewriter.transform_gcfg(gcfg, address)
    address += 100000
  end

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
