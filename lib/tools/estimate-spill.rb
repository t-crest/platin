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


class EstimateSpill
  def EstimateSpill.default_targets(pml)
    targets = Array.new
    pml.data['relation-graphs'].each { |func|
      targets << func["src"]["function"]
    }

    targets
  end

  def EstimateSpill.estimate(pml, target)
    rg = pml.data['relation-graphs'].find { |f| f['src']['function'] == target or f['dst']['function'] == target }
    raise Exception.new("Relation Graph not found") unless rg

    nodes = {}

    # XXX: update me
    rg = rg.data if rg.kind_of?(RelationGraph)

    spills_per_depth = {}
    spills    = 0
    mem_src   = 0
    mem_dst   = 0
    instr_src = 0
    instr_dst = 0
    rg['nodes'].each do |node|
      block_name_src = node['src-block']
      block_name_dst = node['dst-block']

      func_src = pml.bitcode_functions.by_label_or_name(target)
      func_dst = pml.machine_functions.by_label_or_name(target)

      block_src = func_src.blocks[block_name_src]
      block_dst = func_dst.blocks[block_name_dst]

      next if block_src == NIL

      ls_src = 0
      block_src.instructions.each { |instr|
          #puts "#{instr.opcode}" if (instr.memmode == "store" or instr.memmode == "load")
          ls_src = ls_src + 1 if (instr.memmode == "store" or instr.memmode == "load")
      }

      ls_dst = 0
      block_dst.instructions.each { |instr|
          #puts "#{instr.opcode}" if (instr.memmode == "store" or instr.memmode == "load")
          ls_dst = ls_dst + 1 if (instr.memmode == "store" or instr.memmode == "load")
      }

      spills_per_depth[block_src.loopnest]  = 0 if NIL == spills_per_depth[block_src.loopnest]
      spills_per_depth[block_src.loopnest] += ls_dst - ls_src
      spills += ls_dst - ls_src
      mem_src   += ls_src
      mem_dst   += ls_dst
      instr_src += block_src.instructions.length
      instr_dst += block_dst.instructions.length
    end

    { "spills" => spills, "instr_src" => instr_src, "instr_dst" => instr_dst, "mem_src" => mem_src, "mem_dst" => mem_dst, "spd" => spills_per_depth }
  end

  def EstimateSpill.run(pml, options)
    outdir  = options.outdir || "."
    targets = options.functions || EstimateSpill.default_targets(pml)

    targets.each do |target|
      puts "[EstimateSpill] #{target}: #{estimate(pml, target)}"
    end
    statistics("ESTIMATE-SPILL","Generated rg graphs" => targets.length) if options.stats
  end

  def EstimateSpill.add_options(opts)
    opts.on("-f","--function FUNCTION,...","Name of the function(s) to check") { |f| opts.options.functions = f.split(/\s*,\s*/) }
  end
end

if __FILE__ == $0
SYNOPSIS=<<EOF if __FILE__ == $0
Estimate the number of spill instructions per function
EOF
  options, args = PML::optparse([],"", SYNOPSIS) do |opts|
    opts.needs_pml
    EstimateSpill.add_options(opts)
  end
  EstimateSpill.run(PMLDoc.from_files(options.input, options), options)
end
