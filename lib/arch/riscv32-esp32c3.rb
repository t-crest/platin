# typed: false
#
# PLATIN tool set
#
# RISCV specific functionality for the ESP32C3
#
# Despite the manuals were consulted with care, all information in this document
# came from measurements of the Cycle Counter events from the performance
# counters of the ESP32C3, as the information provided in the manuals did not
# yield usable timings.

require 'English'

module RISCV32

  class ExtractSymbols
    OP_CONSTPOOL = 121
    OP_IMPLICIT_DEF = 8
    OPCODE_NAMES = { 233 => /mov/ }
    def self.run(cmd,extractor,pml,options)
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
              if insname[0] != "." && insname != "nop"
                warn "No instruction found at #{current_function}+#{current_ix} instructions (#{insname}), addr (#{addr})"
              end
              next
            end
            next if instruction.opcode == OP_IMPLICIT_DEF # not in disassembly
            # FIXME (FROM ARM): We cannot reliably extract addresses of data ATM, because the disassembler
            # is not able to distinguish them. 'Data Instructions' (opcode 121) with a size
            # different from 4 will thus get incorrected addresses. We partially try to address
            # this issue by skipping data entries if the opcode is not 121
            next if insname[0] == "." && instruction.opcode != OP_CONSTPOOL
            extractor.add_instruction_address(current_label,current_ix, Integer("0x#{addr}"))

            # SANITY CHECK (begin)
            if (re = OPCODE_NAMES[instruction.opcode])
              die "Address extraction heuristic probably failed at #{addr}: #{insname} not #{re}" if insname !~ re
            end
            # SANITY CHECK (end)

            current_ix += 1
          end
        end
      end
      die "The objdump command '#{cmd}' exited with status #{$CHILD_STATUS.exitstatus}" unless $CHILD_STATUS.success?
    end
    RE_HEX = /[0-9A-Fa-f]/
    RE_FUNCTION_LABEL = %r{ ^
    ( #{RE_HEX}{8} ) \s # address
    <([^>]+)>:          # label
}x
RE_INS_LABEL = %r{ ^\s*
  ( #{RE_HEX}+ ): \s* # address
  ( \S+ )             # instruction
  # rest
}x
  end

  class Architecture < PML::Architecture
    attr_reader :config
    def initialize(triple, config)
      @triple, @config = triple, config
      @config ||= self.class.default_config
    end

    def self.default_config
      # TODO: fix values: don't know transfer times and burst-sizes
      memories = PML::MemoryConfigList.new([
                                            # the SRAM is accessible "generally within a single CPU clock cycle" - so all latencies are set to zero
                                            # there are no information about the timing of the ROM in the manual -> set it to zero too
                                            PML::MemoryConfig.new('rom0',  256 * 1024, 4, 0, 0, 0, 0),
                                            PML::MemoryConfig.new('rom1',  128 * 1024, 4, 0, 0, 0, 0),
                                            PML::MemoryConfig.new('sram0', 16 * 1024, 4, 0, 0, 0, 0),
                                            PML::MemoryConfig.new('sram1', 384 * 1024, 4, 0, 0, 0, 0)])
      caches = nil # cache is not modeled
      full_range = PML::ValueRange.new(0,0xFFFFFFFF,nil)
      memory_areas =
        PML::MemoryAreaList.new([
  # memoryarea(name, type, cache, memory, address_range, data = nil)
          PML::MemoryArea.new('data_rom',   'data', nil, memories[1], PML::ValueRange.new(0x3ff00000, 0x3ff1ffff, nil)),
          PML::MemoryArea.new('data_sram',  'data', nil, memories[3], PML::ValueRange.new(0x3fc80000, 0x3fcdffff, nil)),
          PML::MemoryArea.new('inst_rom0',  'code', nil, memories[0], PML::ValueRange.new(0x40000000, 0x4003ffff, nil)),
          PML::MemoryArea.new('inst_rom1',  'code', nil, memories[1], PML::ValueRange.new(0x40040000, 0x4005ffff, nil)),
          PML::MemoryArea.new('inst_sram0', 'code', nil, memories[2], PML::ValueRange.new(0x4037c000, 0x4037ffff, nil)),
          PML::MemoryArea.new('inst_sram1', 'code', nil, memories[3], PML::ValueRange.new(0x40380000, 0x403dffff, nil))
        ])
      PML::MachineConfig.new(memories, caches, memory_areas)
    end

    def update_cache_config(options)
      # FIXME: dummy stub
    end

    def self.default_instr_cache(type)
      # TODO: FIXME dummy values
      if type == 'method-cache'
        PML::CacheConfig.new('method-cache','method-cache','fifo',16,8,4096)
      else
        PML::CacheConfig.new('instruction-cache','instruction-cache','lru',2,32,16384)
      end
    end

    def self.simulator_options(opts); end

    def config_for_clang(options); end

    def config_for_simulator; end

    def simulator_trace(options, _watchpoints)
      HiFive1SimulatorTrace.new(options.binary_file, self, options)
    end

    def objdump_command
      "riscv32-esp-elf-objdump"
    end

    def extract_symbols(extractor, pml, options)
      cmd = objdump_command
      ExtractSymbols.run(cmd, extractor, pml, options)
    end

    def path_wcet(ilist)
      cost = ilist.reduce(0) do |cycles, instr|
        if instr.callees[0] =~ /__.*add.*/ || instr.callees[0] =~ /__.*div.*/
          cycles = cycles + cycle_cost(instr) + lib_cycle_cost(instr.callees[0])
        else
          cycles = cycles + cycle_cost(instr)
        end
        cycles
      end
      cost
    end

    def edge_wcet(_ilist,_branch_index,_edge)
      # control flow is for free
      0
    end

    def lib_cycle_cost(func)
      # libgcc functions are defined in ROM:
      # https://github.com/espressif/esp-idf/blob/master/components/esp_rom/esp32c3/ld/esp32c3.rom.libgcc.ld
      # One would need to measure the cycle count by reading out the performance counters for every single instruction
      # This is left as TODO for later.
      warn "Unknown library function: #{func}"
      42
    end

    def cycle_cost(instr)
      case instr.opcode

      when 'LUI', 'AUIPC'
        1

      when 'ADDI', 'NOP', 'SLTI', 'SLTIU', 'XORI', 'ORI', 'ANDI', 'SLLI', 'SRLI', 'SRAI'
        1

      when 'ADD', 'SUB', 'SLL', 'SLT', 'SLTU', 'XOR', 'SRL', 'SRA', 'OR', 'AND'
        1

      when 'MUL', 'MULH', 'MULHSU', 'MULHU'
        5

      when 'DIV', 'DIVU', 'REM', 'REMU'
        35 #between 29 and 35, depending on operand value

      when 'J', 'JAL', 'PseudoBR'
        3 # 2 or 3, depending on alignment
      when 'JALR', 'PseudoRET', 'PseudoBRIND', 'PseudoCALLIndirect', 'PseudoTAILIndirect'
        5 # 4 to 5, depending on alignment
      when 'PseudoCALL', 'PseudoTAIL' # is either jal or auipc+jalr -> max(3, 5+1) = 6
        6

      when 'BEQ', 'BNE', 'BLT', 'BGE', 'BLTU', 'BGEU'
        4 # 1 - 4, depending on taken/not taken

      when 'LW', 'LH', 'LHU', 'LB', 'LBU'
        3 # 1 - 3, depending on area / alignment

      when 'SB', 'SH', 'SW'
        3 # 1 - 3, depending on area / alignment

      when 'CSRRW', 'CSRRS', 'CSRRC', 'CSRRWI', 'CSRRSI', 'CSRRCI'
        #Atomic Read/Write CSR
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

    def data_cache_access?(_instr)
      # FIXME: dummy stub
      false
    end

  end

end # module RISCV

# Extend PML
module PML

# Register architecture
Architecture.register("riscv32", RISCV32::Architecture)

end # module PML
