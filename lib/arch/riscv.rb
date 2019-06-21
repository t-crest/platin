# typed: false
#
# PLATIN tool set
#
# RISCV specific functionality
#

require 'English'

module RISCV

#
# Class to (lazily) read hifive1 simulator trace
# yields [program_counter, cycles] pairs
#
class HiFive1SimulatorTrace
  TIME_PER_TICK = 500

  attr_reader :stats_num_items
  def initialize(elf, options)
    @elf, @options = elf, options
    @stats_num_items = 0
  end

  def each
    die("No RISCV trace file specified") unless @options.trace_file
    file_open(@options.trace_file) do |fh|
      fh.each_line do |line|
        yield parse(line)
        @stats_num_items += 1
      end
    end
  end

private

  def parse(line)
    return nil unless line
    time,event,pc,rest = line.split(/\s*:\s*/,4)
    return nil unless event =~ /system\.cpu/
    [Integer(pc), time.to_i / TIME_PER_TICK, @stats_num_items]
  end
end

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
              warn "No instruction found at #{current_function}+#{current_ix} instructions (#{insname})"
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
    memories = PML::MemoryConfigList.new([PML::MemoryConfig.new('main', 126 * 1024 * 1024, 16,0,21,0,21),
											PML::MemoryConfig.new('data-sram',16384,16,16,3,21,3,21)])
    caches = PML::CacheConfigList.new([Architecture.default_instr_cache('instruction-cache')])
    full_range = PML::ValueRange.new(0,0xFFFFFFFF,nil)
    dtim_range = PML::ValueRange.new(0x80000000,0x80003FFF,nil)
    memory_areas =
      PML::MemoryAreaList.new([PML::MemoryArea.new('instructions','code',caches.list[0], memories.first, full_range),
                               PML::MemoryArea.new('data','data',memories.list[1], memories.first, dtim_range)])
    PML::MachineConfig.new(memories,caches,memory_areas)
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
    "riscv64-unknown-elf-objdump"
  end

  def extract_symbols(extractor, pml, options)
    cmd = objdump_command
    ExtractSymbols.run(cmd, extractor, pml, options)
  end



# found out through measuring nops
# every 16 instructions cycles jump by 4620
# probably due to fetching new cacheline from flash
# -> 4620 cycles for 32 byte => 144.375 cycles/byte
# one instruction usually 32 bit => takes 577.5 cycles to fetch one instruction from flash
# (same number again if a 32bit value is stored or loaded)
  FLASH_WAIT_CYCLES = 578
  CACHE_ACCESS = 1

  def path_wcet(ilist)
	cost = ilist.reduce(0) do |cycles, instr|
      cycles = cycles + cycle_cost(instr) + 1 #FLASH_WAIT_CYCLES # access instructions
	  cycles
    end
    cost
  end

  def edge_wcet(_ilist,_branch_index,_edge)
    # control flow is for free
    0
  end

  def lib_cycle_cost(func)
    #binding.pry
	case func
	when "__mulsi3"
		9
	when "__divsi3"
		2
	when "__udivsi3"
		18
	when "__umodsi3"
		13
	when "__modsi3"
		12
	else
		die("Unknown library function: #{func}")
	end
  end

  NUM_REGISTERS = 10
  PIPELINE_REFILL = 3
  PIPELINE_FLUSH = 5
  def cycle_cost(instr)
  # all info from: https://sifive.cdn.prismic.io/sifive%2F4d063bf8-3ae6-4db6-9843-ee9076ebadf7_fe310-g000.pdf
	case instr.opcode
	when 'LUI', 'AUIPC'
	  1

	when 'JAL', 'J', 'JALR'
	  1 + PIPELINE_REFILL

	when 'BEQ', 'BNE', 'BLT', 'BGE', 'BLTU', 'BGEU'
	  1 + PIPELINE_REFILL

	when 'LW'
	  # 2 assumes cache hit
	  # Loads to addresses currently in the store pipeline result in a five-cycle penalty
	  2 + 5 + FLASH_WAIT_CYCLES

	when 'LH', 'LHU', 'LB', 'LBU'
	  # 3 assumes cache hit
	  # Loads to addresses currently in the store pipeline result in a five-cycle penalty
	  3 + 5 + FLASH_WAIT_CYCLES

	when 'SB', 'SH', 'SW'
	 # The accesslatency is two clock cycles for full words and three clock cycles for smaller quantities
	 # 3 assumes cache hit
	  3 + FLASH_WAIT_CYCLES

	when 'ADDI', 'NOP'
	  1

	when 'SLTI', 'SLTIU', 'XORI', 'ORI', 'ANDI'
	  1

	when 'SLLI', 'SRLI', 'SRAI'
	  1

	when 'ADD', 'SUB', 'SLL', 'SLT', 'SLTU', 'XOR', 'SRL', 'SRA', 'OR', 'AND'
	  1

	when 'FENCE', 'FENCE_TSO', 'FENCE_I', 'ECALL', 'EBREAK'
	  #FENCE: used for synchronizing when writing to the instruction cache
	  1

	when 'CSRRW', 'CSRRS', 'CSRRC', 'CSRRWI', 'CSRRSI', 'CSRRCI'
	  #Atomic Read/Write CSR
	  3 + PIPELINE_FLUSH

	when 'MUL', 'MULH', 'MULHSU', 'MULHU'
	  5

	when 'DIV', 'DIVU', 'REM', 'REMU'
	  33 #between 2 and 33, depending on operand value

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
Architecture.register("riscv32", RISCV::Architecture)

end # module PML
