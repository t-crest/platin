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
  # TODO: FIXME dummy values
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
  # FIXME: dummy stub
  end
  def Architecture.default_instr_cache(type)
  # TODO: FIXME dummy values
    if type == 'method-cache'
      PML::CacheConfig.new('method-cache','method-cache','fifo',16,8,4096)
    else
      PML::CacheConfig.new('instruction-cache','instruction-cache','dm',1,16,4096)
    end
  end
  def Architecture.simulator_options(opts)
  # FIXME: dummy stub
  end
  def config_for_clang(options)
  # FIXME: dummy stub
  end
  def config_for_simulator
  # FIXME: dummy stub
  end
  def simulator_trace(options, watchpoints)
    M5SimulatorTrace.new(options.binary_file, self, options)
  end
  def extract_symbols(extractor, pml, options)
    # prefix="armv6-#{@triple[2]}-#{@triple[3]}"
    # cmd = "#{prefix}-objdump"
  # FIXME hard coded tool name
    cmd = "arm-none-eabi-objdump"
    ExtractSymbols.run(cmd, extractor, pml, options)
  end


# found out through reading register on hardware:
FLASH_WAIT_CYCLES=3
#
# FLASH_WAIT_CYCLES=15 # the actual worst case

# xmc4500_um.pdf 8-41
# WAIT_CYCLES_FLASH_ACCESS=3
  def path_wcet(ilist)
    cost = ilist.reduce(0) do |cycles, instr|
      # TODO: flushes for call??
      if (instr.callees[0] =~ /__aeabi_.*/ || instr.callees[0] =~ /__.*div.*/)
        cycles + cycle_cost(instr) + lib_cycle_cost(instr.callees[0]) + FLASH_WAIT_CYCLES
      else
        cycles + cycle_cost(instr) + FLASH_WAIT_CYCLES # access instructions
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
    when 'tBcc', 'tCBNZ', 'tCBZ'
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
    when 'tADDhirr', 'tMOVr', 'tCMPhir'
      1

    # immediate
    when 'tMOVi8', 'tADDi8', 'tSUBi8', 'tCMPi8'
      1

    # branch and link: BL = inst32
    when 'tBL'
      1 + PIPELINE_REFILL

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
      2 + FLASH_WAIT_CYCLES

    # NOTE: not directly considered in NEO's classes
    # ldrh r, [r, #i] same as ldr r, [r, #i]??
    # memimmediate
    when 'tSTRHi', 'tLDRHi'
      2 + FLASH_WAIT_CYCLES

    # ldrb r, [r, #i] same as ldr r, [r, #i]??
    # memmimmediate
    when 'tSTRBi', 'tLDRBi'
      2 + FLASH_WAIT_CYCLES

    # ldrsb r, [r, #i] same as ldr r, [r, #i]??
    # memimmediate
    when 'tLDRSB', 'tLDRSH'
      2 + FLASH_WAIT_CYCLES

    # memmultiple
    when 'tLDMIA', 'tLDMIA_UDP', 'tSTMIA_UDP'
      1 + (NUM_REGISTERS * FLASH_WAIT_CYCLES)

    # mempcrel
    when 'tLDRpci'
      2 + FLASH_WAIT_CYCLES

    # memreg
    when 'tSTRBr', 'tLDRBr', 'tLDRr', 'tSTRr', 'tLDRHr', 'tSTRHr'
      2 + FLASH_WAIT_CYCLES

    # memsprel
    when 'tSTRspi', 'tLDRspi'
      2 + FLASH_WAIT_CYCLES

    # pushpop
    when 'tPUSH', 'tPOP'
      1 + (NUM_REGISTERS * FLASH_WAIT_CYCLES)

    # pseudo instruction mapping to pop
    when 'tPOP_RET'
      1 + (NUM_REGISTERS * FLASH_WAIT_CYCLES) + PIPELINE_REFILL

    # shift
    when 'tLSLri', 'tLSRri', 'tASRri'
      1

    # single-cycle multiplication
    when 'tMUL'
      1

    # pseudo instruction translated to a 'mov pc, r2'
    when 'tBR_JTr'
      1 + PIPELINE_REFILL

    # ARMv7M support (thumb2)
    # http://infocenter.arm.com/help/index.jsp?topic=/com.arm.doc.ddi0439b/CHDDIGAC.html
    #
    # STMFD is s synonym for STMDB, and refers to its use for pushing data onto Full Descending stacks
    # Store Multiple: 1 + N: (Number of registers: N = NUM_REGISTERS)
    when 't2STMDB_UPD'
      1 + FLASH_WAIT_CYCLES * NUM_REGISTERS
    when 't2MOVi16', 't2MOVTi16', 't2MOVi'
      1

    # move not, test
    when 't2MVNi', 't2MVNr', 't2TSTri'
      1
    when 't2Bcc', 't2B'
      1 + PIPELINE_REFILL
    when 't2LDMIA_RET', 't2STRi8', 't2STRBi8', 't2STRHi8', 't2STRBi12', 't2STRHi12'
      2 + FLASH_WAIT_CYCLES
    when 't2LDRi8', 't2LDRi12', 't2LDRBi12', 't2LDRSBi12', 't2LDRSHi12', 't2LDRSHi12', 't2LDRHi12'
      2 + FLASH_WAIT_CYCLES
    when 't2LDRDi8', 't2STRDi8', 't2STMIA'
      1 + FLASH_WAIT_CYCLES * NUM_REGISTERS
    when 'PSEUDO_LOOPBOUND'
      0
    # page 31:
    when 't2MUL', 't2SMMUL', 't2MLA', 't2MLS', 't2SMULL', 't2UMULL', 't2SMMLA', 't2SMLAL', 't2UMLAL'
      1
    when 't2ADDrs', 't2ADDri', 't2ADDrr', 't2ADCrs', 't2ADCri', 't2ADCrr', 't2ADDri12'
      1
    # logical operations
    when 't2ANDrr', 't2ANDrs', 't2ANDri', 't2EORrr', 't2EORri', 't2ORRrr', 't2ORRrs', 't2ORRri', 't2ORNrr', 't2BICrr', 't2MVNrr', 't2TSTrr', 't2TEQrr', 't2EORrs', 't2BICri', 't2ORNri'
      1
    # bitwise shifts
    when 't2LSLri', 't2LSLri', 't2LSRri', 't2LSRri', 't2ASRri', 't2ASRri'
      1
    # subtract
    when 't2SUBrr', 't2SUBri', 't2SUBrs',  't2SBCrr', 't2SBCri', 't2RSBrs', 't2RSBri', 't2SUBri12'
      1
    # store instructions
    when 't2STRi12'
      2 + FLASH_WAIT_CYCLES
    when 't2CMPri', 't2CMPrs'
      1
    # extend
    when 't2SXTH', 't2SXTB', 't2UXTH', 't2UXTB'
      1
    # bit field, extract unsigned, extract signed, clear, insert
    when 't2UBFX', 't2SBFX', 't2BFC', 't2BFI'
      1
    # If-then-else
    when 't2IT'
      1
    else
      die("Unknown opcode: #{instr.opcode}")
    end
  end

  def method_cache
  # FIXME: dummy stub
    nil
  end

  def instruction_cache
  # FIXME: dummy stub
    nil
  end

  def stack_cache
  # FIXME: dummy stub
    nil
  end

  def data_cache
  # FIXME: dummy stub
    nil
  end

  def data_memory
  # FIXME: dummy stub
    dm = @config.memory_areas.by_name('data')
    dm.memory if dm
  end

  def local_memory
  # FIXME: dummy stub
    # used for local scratchpad and stack cache accesses
    @config.memories.by_name("local")
  end

  # Return the maximum size of a load or store in bytes.
  def max_data_transfer_bytes
  # FIXME: dummy stub
    4
  end

  def data_cache_access?(instr)
  # FIXME: dummy stub
    false
  end
end

end # module ARMv7m

# Extend PML
module PML

# Register architecture
Architecture.register("armv7m",   ARMv7m::Architecture)
Architecture.register("thumbv7m", ARMv7m::Architecture)

end # module PML
