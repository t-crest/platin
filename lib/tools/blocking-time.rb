#!/usr/bin/env ruby
# coding: utf-8
#
# platin tool set
#
# Interprets the results of the aiT analysis in PML
#

require 'platin'
require 'analysis/wca'
require 'tools/wca'

include PML

class BlockingTimeTool
  DEFAULT_DISABLE_INTERRUPTS = "_ZN7Machine18disable_interruptsEv"
  DEFAULT_ENABLE_INTERRUPTS = "_ZN7Machine17enable_interruptsEv"

  def BlockingTimeTool.add_config_options(opts)
    opts.on("--disable-interrupts FUNC", "Function that disables interrupts") { |v|
      opts.options.disable_interrupts = v
    }

    opts.on("--enable-interrupts FUNC", "Function that enables interrupts") { |v|
      opts.options.enable_interrupts = v
    }
    opts.on("--enable-interrupts FUNC", "Function that enables interrupts") { |v|
      opts.options.enable_interrupts = v
    }
    opts.on("--gcfg CIRCUIT", "Use the following timing Circuit") { |v|
      opts.options.use_gcfg = v
    }
    opts.add_check { |options|
      opts.options.disable_interrupts = DEFAULT_DISABLE_INTERRUPTS unless opts.options.disable_interrupts
      opts.options.enable_interrupts = DEFAULT_ENABLE_INTERRUPTS unless opts.options.enable_interrupts
    }
  end
  def BlockingTimeTool.add_options(opts, mandatory = true)
    BlockingTimeTool.add_config_options(opts)
  end

  def BlockingTimeTool.instrs_from_function(mf, callee)
    ret = []
    mf.blocks.each {|mbb|
      mbb.instructions.each {|instr|
        if instr.callees.member?(callee)
          ret.push(instr)
        end
      }
    }
    ret
  end

  def BlockingTimeTool.instrs_from_mbb(mbb, callee)
    ret = []
    mbb.instructions.each {|instr|
      p instr.callees, callee
      if instr.callees.member?(callee)
        ret.push(instr)
      end
    }
    ret
  end

  def BlockingTimeTool.process(region, instr, visited, after_switch = false)
    # No Endless Recursion
    queue = [[instr,after_switch]]

    any_after_switch = after_switch

    while queue != []
      instr, after_switch = queue.pop
      next if visited.member?(instr)
      visited.add(instr)

      while instr do
        region.blocks.add(instr.block)

        if after_switch
          region.after_switch.add(instr)
        end

        if region.enable.member?(instr)
          last_instr = nil
          break
        end

        if not after_switch and instr.block.mapsto =~ /^switch_context/
          region.switch.add(instr)
          after_switch = true
          any_after_switch = true
        end

        # Go to called functions
        instr.callees.map { |mf|
          next if mf =~ /StartOS|timing_dump_trap/
          mf = region.pml.machine_functions.by_label(mf)
          x = process(region, mf.instructions.first, visited, after_switch)
          after_switch ||= x
          any_after_switch ||= x
        }

        last_instr = instr
        instr = instr.next
      end

      if last_instr
        last_instr.block.successors.each { |mbb|
          while mbb.instructions.first.nil? do
            region.blocks.add(mbb)
            mbb = mbb.next
          end
          queue.push([mbb.instructions.first, after_switch])
        }
      end
    end
    return any_after_switch
  end

  def BlockingTimeTool.run(pml, options)
    r = OpenStruct.new
    r.pml = pml
    r.blocks = Set.new
    r.disable = Set.new
    r.enable = Set.new
    r.switch = Set.new
    r.after_switch = Set.new

    pml.machine_functions.each { |mf|
      # We will ignore a few functions here.
      next if mf.label =~ /StartOS|arch_startup|test_trace_assert|init_generic|os_main|OSEKOS.*Interrupts/
      r.disable += instrs_from_function(mf, options.disable_interrupts)
      r.enable += instrs_from_function(mf, options.enable_interrupts)
      if mf.label =~ /^OSEKOS_TASK_FUNC/
        r.switch.add(mf.blocks.first.instructions.first)
      end
      if mf.label =~ /irq_entry/
        r.disable += [mf.blocks.first.instructions.first]
        r.enable += [mf.blocks.last.instructions.first]
      end
    }
    (r.disable | r.switch).each {|instr|
      # Find end Instruction
      process(r, instr, Set.new, r.switch.member?(instr))
    }
    r.enable.each {|instr|
      r.blocks.add(instr.block)
      if instr.callees.length > 0
        r.blocks.merge(pml.machine_functions.by_label(instr.callees[0]).blocks)
      end
    }
    r.delete_field("pml")

    begin
      tmpdir = nil
      tmpdir = options.outdir = Dir.mktmpdir() unless options.outdir
      wca = WCA.new(pml, options)

      disable_enable, _1, _2 = wca.analyze_fragment(r.disable, r.enable, r.blocks) do |a, b|
        b.index - a.index
      end
      puts "Disable->Enable: #{disable_enable} cycles"

      disable_switch, _1, _2 = wca.analyze_fragment(r.disable, r.switch, r.blocks) do |a, b|
        b.index - a.index
      end
      puts "Disable->Switch: #{disable_switch} cycles"

      switch_enable, _1, _2 = wca.analyze_fragment(r.disable, r.enable, r.blocks) do |a, b|
        if r.after_switch.member?(a)
          b.index - a.index
        else
          0
        end
      end
      puts "Switch->Enable: #{switch_enable} cycles"

      @options = options
      statistics("BLOCKING", {"disable enable" => disable_enable,
                              "disable switch" => disable_switch,
                              "switch enable" => switch_enable,
                              "maximum"=> [disable_enable, disable_switch+switch_enable].max
                             })
    ensure
      FileUtils.remove_entry tmpdir if tmpdir
    end

  end
end

if __FILE__ == $0
SYNOPSIS=<<EOF if __FILE__ == $0
Calculate the Interrupt Blocking Time
EOF
  options, args = PML::optparse([], "", SYNOPSIS) do |opts|
    opts.needs_pml
    BlockingTimeTool.add_options(opts)
    WcaTool.add_options(opts)
  end
  BlockingTimeTool.run(PMLDoc.from_files(options.input, options), options)
end
