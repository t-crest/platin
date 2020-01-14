#!/usr/bin/env ruby
# typed: ignore
#
# platin tool set
#
# "Inhouse" IPET-based WCET analysis

require 'platin'
require 'analysis/wca'
require 'mkmf'
require 'English'
require 'set'
include PML

# Calls do not constitute basic block terminators in LLVM
# Therefore, we split basic blocks at call boundaries
class BasicBlockSplittingTool
  def self.add_options(opts) end

  def self.run(pml,options)
    bbst = BasicBlockSplittingTool.new(pml, options)
    bbst.run
  end

  def run
    split
    patched = patch_pml

    File.open(@options.output, "w") do |fh|
      fh.write(YAML::dump(PML::PMLDoc.deep_data_clone(patched)))
    end

    patched
  end

private

  def initialize(pml, options)
    @pml = pml
    @options = options
    # Mapping programpoints to their updated target
    # T::Hash[String, T::Array[PML::ProgramPoint]]
    @updates = Hash.new
    # Mapping basic blocks to their splits
    # T::Hash[PML::Block, T::Array[PML::Block]}
    @splits  = Hash.new
  end

  # Split a basic block at call sides
  #
  # @param ins [PML::InstructionList] list of instructions to split
  # @param splitpoints [T::Array[PML::Instruction]] list of instructions that constitute a splitpoint
  # @return [T::Array[T::Hash[String, any]]] the list of splitted instructions in their pml representation
  def split_instructionlist(ins, splitpoints)
    splits = [[]]
    lastidx = -1
    ins.zip(ins.to_pml).each_with_index do |(i,p), idx|
      # The splitter resets the index hard within create_blockchain, so
      # we better make sure that the input was what we expected (incrementing index per bb)
      assert("Nonlinear increasing instruction index found within a block") { idx == (lastidx += 1) }
      
      splits.last.push(p)
      # does this point constitute a splitpoint?
      if ins.last != i && splitpoints.include?(i)
        splits.push([])
      end
    end
    splits
  end

  SEPERATOR = ":split"
  def gen_name(prefix, idx)
    prefix + SEPERATOR + idx.to_s
  end

  # Given an exemplary basic block as a template (in PML representation), construct a series of
  # basicblocks using that pattern, but with patched predecessor/successor so that they form a chain
  # Names of duplicated are adapted to make them unique again
  #
  # @param tmpl [T::Hash[String, any]] the template block in pml representation
  # @param inss [T::Array[T::Array[T::Hash[String, any]]]] list of lists, each list represents a new splits instruction list
  # @return [T::Array[T::Hash[String, any]]] the list of chained blocks, again in pml representation
  def create_blockchain(tmpl, inss)
    if inss.length == 1
      tmpl['instructions'] = inss.first
      return tmpl
    end

    # List of pml-represented basic blocks
    blocks = inss.map.with_index do |ins, idx|
      cpy = deep_copy(tmpl)
      cpy['name'] = gen_name(cpy['name'], idx)
      # rewire blockindices: lineary increasing
      cpy['instructions'] = ins.map.with_index do |i, idx|
        i['index'] = idx.to_s
        i
      end
      cpy
    end.to_a

    # now chain them
    blocks.each_with_index do |block, idx|
      # first block keeps his predecessors, all others get chained
      block['predecessors'] = [blocks[idx - 1]['name']] unless idx <= 0

      # last block keeps his successors, all others get chained
      block['successors'] = [blocks[idx + 1]['name']] unless idx >= (blocks.length - 1)
    end

    blocks
  end

  def relate(tmpl, srcblocks, dstblocks)
    assert("Failed to relate splits: unequal length for src and destblocks: #{srcblocks} <-> #{dstblocks}") { srcblocks.length == dstblocks.length }
    
    rgns = srcblocks.zip(dstblocks).map.with_index do |(src,dst),idx|
      cpy = deep_copy(tmpl)
      cpy['name'] = gen_name(cpy['name'], idx)
      cpy['src-block'] = src['name']
      cpy['dst-block'] = dst['name']

      assert("Related nodes do not share common callee set in tail expression: #{src}<->#{dst}") {
        deep_compare(src['callees'], dst['callees'])
      }

      cpy
    end

    # link them up
    rgns.each_with_index do |rgn, idx|
      unless idx >= (rgns.length - 1)
        rgn['src-successors'] = [rgns[idx + 1]['name']]
        rgn['dst-successors'] = [rgns[idx + 1]['name']]
      end
    end
  end

  # Split a basic block at call sides
  #
  # @param mbb [PML::Block] machinecode-level basicblock to split
  # @param bbb [PML::Block] matching bitcode-level basicblock
  # @param rgn [PML::RelationNode] The matching relationship graph node if applicable
  # @return [T::Hash[String, T::Array[T::Hash]]] the splitted nodes, as hash mapping their QNames to the PML representations
  def splitblock(mbb, bbb, rgn)
    # Idea: only patch the pml representation and then recreate the blocks using constructor
    mcb  = create_blockchain(mbb.to_pml, split_instructionlist(mbb.instructions, mbb.callsites))
    bcb  = create_blockchain(bbb.to_pml, split_instructionlist(bbb.instructions, bbb.callsites))
    rgns = relate(rgn.to_pml, bcb, mcb)

    {
      mbb.qname => mcb,
      bbb.qname => bcb,
      rgn.qname => rgns
    }
  end

  def split
    @pml.machine_functions.each do |mf|
      bf = @pml.bitcode_functions.by_name(mf.mapsto)
      assert("Only blocks that cleanly map to a bitcodefunction can be split") { !bf.nil? }

      # relation-graph for a function
      rg = @pml.relation_graphs.by_name(bf.name, :src)
      assert("A relation graph for function #{bf} is required to do the splitting") { !rg.nil? }

      mf.blocks.each do |mbb|
        # We only have to split blocks with calls in the middle of the block
        next unless mbb.calls? && \
                    (mbb.callsites.last != mbb.instructions.last)

        # bitcode level representation
        bbb = bf.blocks.by_name(mbb.mapsto)
        assert("Only blocks that cleanly map to a bitcode-level basicblock can be split") { !bbb.nil? }

        rgns = rg.nodes.by_basic_block(mbb, :dst)
        assert("No matching relationship graph node found for machine basic block #{mbb}") { !rgns.empty? }
        assert("Too many relationgraphnodes match basic block #{mbb}: #{rgns}") { rgns.size == 1 }
        rgn = rgns[0]
        assert("Relationship node #{rgn} not a entry, progress or exit node, nodetype is '#{rgn.type}'") {
          [:progress, :entry, :exit].include?(rgn.type)
        }

        splits = splitblock(mbb, bbb, rgn)
        @updates.merge!(splits)
      end
    end
  end

  # Patch a list of basicblocks according to the updates from @updates
  # @param original [PML::BlockList] The list of basicblocks to patch
  # @returns [T::Array[T::Hash[String,any]]] The patched pml representation
  def patch_blockchain(original)
    pml = original.to_pml
    pml = pml.zip(original).flat_map do |p,o|
      p['successors'] = p['successors'].zip(o.successors).map do |p,succ|
        u = @updates[succ.qname]
        if u.nil?
          p
        else
          u.first['name']
        end
      end

      p['predecessors'] = p['predecessors'].zip(o.predecessors).map do |p,pred|
        u = @updates[pred.qname]
        if u.nil?
          p
        else
          u.last['name']
        end
      end

      unless p['loops'].nil?
        p['loops'] = p['loops'].zip(o.loops).map do |p,loop|
            u = @updates[loop.loopheader.qname]
            if u.nil?
            p
            else
            u.last['name']
            end
        end
      end

      @updates[o.qname] || [p]
    end
    pml
  end

  # Patch a list of relationshipgraph according to the updates from @updates
  # @param original [PML::BlockList] The list of basicblocks to patch
  # @returns [T::Array[T::Hash[String,any]]] The patched pml representation
  def patch_relationgraph(original)
    pml = original.to_pml

    pml = pml.zip(original).flat_map do |p,o|
      ['src', 'dst'].each do |level|
        next if p["#{level}-successors"].nil?
        p["#{level}-successors"] = p["#{level}-successors"].zip(o.successors(level.to_sym)).map do |p,succ|
          u = @updates[succ.qname]
          if u.nil?
            p
          else
            u.first['name']
          end
        end
      end

      @updates[o.qname] || [p]
    end
  end

  def patch_pml
    patched = @pml.to_pml

    patched['machine-functions'] = @pml.machine_functions.zip(patched['machine-functions']).map do |mf,pml|
      pml['blocks'] = patch_blockchain(mf.blocks)
      pml
    end
    patched['bitcode-functions'] = @pml.machine_functions.zip(patched['bitcode-functions']).map do |bf,pml|
      pml['blocks'] = patch_blockchain(bf.blocks)
      pml
    end

    patched['relation-graphs'] = @pml.relation_graphs.zip(patched['relation-graphs']).map do |rg,pml|
      pml['nodes'] = patch_relationgraph(rg.nodes)
      pml
    end

    # todo: patch all flow/modelfacts
    
    patched
  end
end

if __FILE__ == $PROGRAM_NAME
  SYNOPSIS = <<-EOF
  Splits basic blocks at call instructions
  EOF
  options, args = PML::optparse(0, "", SYNOPSIS) do |opts|
    opts.needs_pml
    opts.writes_pml
    BasicBlockSplittingTool.add_options(opts)
  end
  pml_in = PMLDoc.from_files(options.input, options)
  pml_out = BasicBlockSplittingTool.run(pml_in, options)
  # pml_out.dump_to_file(options.output)
end
