#
# PLATIN tool set
#
# ARMv7m specific functionality
#

module ARMv7m

class ExtractSymbols
  OP_CONSTPOOL=121
  OP_IMPLICIT_DEF=8
  OPCODE_NAMES={233=>/mov/}
  def ExtractSymbols.run(cmd,extractor,pml,options)
    r = IO.popen("#{cmd} -d --no-show-raw-insn '#{options.binary_file}'") do |io|
      current_label, current_ix, current_function = nil, 0, nil
      io.each_line do |line|
        if line =~ RE_FUNCTION_LABEL
          current_label, current_ix = $2, 0
          current_function = pml.machine_functions.by_label(current_label, false)
          extractor.add_symbol(current_label,Integer("0x#{$1}"))
        elsif line =~ RE_INS_LABEL
          addr, insname = $1, $2
          next unless current_function
          instruction = current_function.instructions[current_ix]
          if instruction.nil?
            if(insname[0] != "." && insname != "nop")
              warn ("No instruction found at #{current_function}+#{current_ix} instructions (#{insname})")
            end
            next
          end
          next if instruction.opcode == OP_IMPLICIT_DEF # not in disassembly
          # FIXME: We cannot reliably extract addresses of data ATM, because the disassembler
          # is not able to distinguish them. 'Data Instructions' (opcode 121) with a size
          # different from 4 will thus get incorrected addresses. We partially try to address
          # this issue by skipping data entries if the opcode is not 121
          next if(insname[0] == "." && instruction.opcode != OP_CONSTPOOL)
          extractor.add_instruction_address(current_label,current_ix, Integer("0x#{addr}"))

          # SANITY CHECK (begin)
          if (re = OPCODE_NAMES[instruction.opcode])
            if(insname !~ re)
              die ("Address extraction heuristic probably failed at #{addr}: #{insname} not #{re}")
            end
          end
          # SANITY CHECK (end)

          current_ix+=1
        end
      end
    end
    die "The objdump command '#{cmd}' exited with status #{$?.exitstatus}" unless $?.success?
  end
  RE_HEX=/[0-9A-Fa-f]/
  RE_FUNCTION_LABEL = %r{ ^
    ( #{RE_HEX}{8} ) \s # address
    <([^>]+)>:          # label
  }x
  RE_INS_LABEL = %r{ ^ \s+
    ( #{RE_HEX}+ ): \s* # address
    ( \S+ )             # instruction
    # rest
  }x

end

class Architecture < PML::Architecture
  attr_reader :triple, :config
  def initialize(triple, config)
    @triple, @config = triple, config
    @config = self.class.default_config unless @config
  end
  def Architecture.default_config
  # TODO FIXME dummy values
    memories = PML::MemoryConfigList.new([PML::MemoryConfig.new('main',2*1024*1024,16,0,21,0,21)])
    caches = PML::CacheConfigList.new([Architecture.default_instr_cache('method-cache'),
                                  PML::CacheConfig.new('stack-cache','stack-cache','block',nil,4,2048),
                                  PML::CacheConfig.new('data-cache','set-associative','dm',nil,16,2048) ])
    full_range = PML::ValueRange.new(0,0xFFFFFFFF,nil)
    memory_areas =
      PML::MemoryAreaList.new([PML::MemoryArea.new('code','code',caches.list[0], memories.first, full_range),
                               PML::MemoryArea.new('data','data',caches.list[2], memories.first, full_range) ])
    PML::MachineConfig.new(memories,caches,memory_areas)
  end
  def update_cache_config(options)
  # FIXME dummy stub
  end
  def Architecture.default_instr_cache(type)
  # TODO FIXME dummy values
    if type == 'method-cache'
      PML::CacheConfig.new('method-cache','method-cache','fifo',16,8,4096)
    else
      PML::CacheConfig.new('instruction-cache','instruction-cache','dm',1,16,4096)
    end
  end
  def Architecture.simulator_options(opts)
  # FIXME dummy stub
  end
  def config_for_clang(options)
  # FIXME dummy stub
  end
  def config_for_simulator
  # FIXME dummy stub
  end
  def simulator_trace(options, watchpoints)
    M5SimulatorTrace.new(options.binary_file, self, options)
  end
  def extract_symbols(extractor, pml, options)
    #prefix="armv6-#{@triple[2]}-#{@triple[3]}"
    #cmd = "#{prefix}-objdump"
  # FIXME hard coded tool name
    cmd = "arm-none-eabi-objdump"
    ExtractSymbols.run(cmd, extractor, pml, options)
  end
  

# xmc4500_um.pdf 8-41
WAIT_CYCLES_FLASH_ACCESS=3
  def path_wcet(ilist)
    cost = ilist.reduce(0) do |cycles, instr|
      # TODO flushes for call??
      if (instr.callees[0] =~ /__aeabi_.*/ || instr.callees[0] =~ /__.*div.*/)
        cycles + cycle_cost(instr) + lib_cycle_cost(instr.callees[0]) + WAIT_CYCLES_FLASH_ACCESS
      else
        cycles + cycle_cost(instr) + WAIT_CYCLES_FLASH_ACCESS
      end
    end
    cost
  end
  def edge_wcet(ilist,branch_index,edge)
    # control flow is for free
    0
  end
  def lib_cycle_cost(func)
#    case func
#    when "__aeabi_uidivmod"
#      845 + 16
#    when "__aeabi_idivmod"
#      922 + 16#
#    when "__udivsi3"
#      820
#    when "__udivmodsi4"
#      845
#    when "__divsi3"
#      897
#    when "__divmodsi4"
#      922
#    else
      die("Unknown library function: #{func}")
#    end
  end


NUM_REGISTERS=10
PIPELINE_REFILL=3
  def cycle_cost(instr)
    case instr.opcode
    # addsub
    when 'tADDi3', 'tSUBi3'
      1

    # assume same costs for 3 registers as for 2 registers and immediate
    when 'tADDrr', 'tSUBrr'
      1

    # addsubsp
    when 'tSUBspi', 'tADDspi', 'tADDrSPi'
      1

    # alu
    when 'tAND', 'tEOR', 'tADC', 'tSBC',  'tROR', 'tTST',  'tRSB', 'tCMPr', 'tCMNz', 'tLSLrr', 'tLSRrr', 'tASRrr', 'tORR', 'tBIC', 'tMVN'
      1

    # branchcond (requires pipeline refill)
    # 1 + P (P \in {1,..,3})
    when 'tBcc'
      1 + PIPELINE_REFILL

    # branchuncond (requires pipeline refill)
    # 1 + P
    when 'tB'
      1 + PIPELINE_REFILL

    # pseudo instruction mapping to 'bx lr'
    # 1 + P
    when 'tBX_RET'
      1 + PIPELINE_REFILL

    # extend
    when 'tSXTB', 'tSXTH', 'tUXTB', 'tUXTH'
      1

    # hireg
    # TODO 
    when 'tADDhirr', 'tMOVr', 'tCMPhir'
      1

    # immediate
    when 'tMOVi8', 'tADDi8', 'tSUBi8', 'tCMPi8'
      1

    # branch and link: BL = inst32
    when 'tBL'
      4

    # NOTE: pseudo instruction that maps to tBL
    # branchuncond
    # 1 + P
    when 'tBfar'
      1 + PIPELINE_REFILL

    # lea
    when 'tADR'
      1

    # NOTE pseduo instruction that maps to 'add rA, pc, #i'
    # probably lea
    when 'tLEApcrelJT'
      1

    # memimmediate
    when 'tSTRi', 'tLDRi'
      3

    # NOTE: not directly considered in NEO's classes
    # ldrh r, [r, #i] same as ldr r, [r, #i]??
    # memimmediate
    when 'tSTRHi', 'tLDRHi'
      3

    # NOTE: not directly considered in NEO's classes
    # ldrb r, [r, #i] same as ldr r, [r, #i]??
    # memmimmediate
    when 'tSTRBi', 'tLDRBi'
      3

    # NOTE: not directly considered in NEO's classes
    # ldrsb r, [r, #i] same as ldr r, [r, #i]??
    # memimmediate
    when 'tLDRSB', 'tLDRSH'
      3

    # memmultiple
    when 'tLDMIA', 'tLDMIA_UDP', 'tSTMIA_UDP'
      4

    # mempcrel
    when 'tLDRpci'
      3

    # memreg
    when 'tSTRBr', 'tLDRBr', 'tLDRr', 'tSTRr', 'tLDRHr', 'tSTRHr'
      3 # 1 in paper, but 3 should be correct for 48 MHz

    # memsprel
    when 'tSTRspi', 'tLDRspi'
      3

    # pushpop
    when 'tPUSH', 'tPOP'
      1 + NUM_REGISTERS

    # pseudo instruction mapping to pop
    when 'tPOP_RET'
      1 + NUM_REGISTERS + PIPELINE_REFILL

    # shift
    when 'tLSLri', 'tLSRri', 'tASRri'
      1

    # according to list above it it correct
    # according to reference manual, it is implementation-specific
    # lincenses for single-cycle-cpus and the other variants
    #
    # Sub-family reference manual p. 53 => single-cycle CPU
    when 'tMUL'
      2 # NEO says alu instruction
      # 1 # for single-cycle CPU

    # pseudo instruction translated to a 'mov pc, r2'
    when 'tBR_JTr'
      2
      
    # ARMv7M support
    # TODO
    when 't2STMDB_UPD'
      2
    when 't2MOVi16'
      2
    when 't2MOVTi16'
      2
    when 't2MVNi', 't2STRi8', 't2TSTri', 't2Bcc', 't2SUBri', 't2ANDri', 't2LDRi8', 't2LDMIA_RET'
      2
    when 'PSEUDO_LOOPBOUND'
      0
    when 't2B'
      1 + PIPELINE_REFILL
    # page 31:
    when 't2MUL', 't2MLA', 't2MLS', 't2SMULL', 't2UMULL', 't2SMLAL', 't2UMLAL'
      1
    else
      die("Unknown opcode: #{instr.opcode}")
    end
  end

  def method_cache
  # FIXME dummy stub
    nil
  end

  def instruction_cache
  # FIXME dummy stub
    nil
  end

  def stack_cache
  # FIXME dummy stub
    nil
  end

  def data_cache
  # FIXME dummy stub
    nil
  end

  def data_memory
  # FIXME dummy stub
    dm = @config.memory_areas.by_name('data')
    dm.memory if dm
  end

  def local_memory
  # FIXME dummy stub
    # used for local scratchpad and stack cache accesses
    @config.memories.by_name("local")
  end

  # Return the maximum size of a load or store in bytes.
  def max_data_transfer_bytes
  # FIXME dummy stub
    4
  end

  def data_cache_access?(instr)
  # FIXME dummy stub
    false
  end
end

end # module ARMv7m

# Extend PML
module PML

# Register architecture
Architecture.register("armv7m", ARMv7m::Architecture)

end # module PML
