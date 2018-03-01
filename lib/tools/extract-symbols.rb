#
# platin toolchain: extract-symbols
#
# Tool to extract addresses from a ELF file
#
require 'platin'
include PML

# Class to extract symbol addresses from an ELF file
class ExtractSymbols
  attr_reader :stats_address_count
  def initialize(pml, options)
    @pml,@options = pml, options
    @text_symbols = {}
    @stats_address_count = 0
    @instruction_addresses = {}
    @instructions = {}

  end

  def add_symbol(label,address)
    @text_symbols[label] = address
    @stats_address_count += 1
  end

  def add_instruction_address(label,index,address)
    (@instruction_addresses[label] ||= {})[index] = address
  end

  def add_instruction(label,address, data)
    (@instructions[label] ||= {})[address] = data
  end

  def analyze
    elf = @options.binary_file
    die "The binary file '#{elf}' does not exist" if !File.exist?(elf)
    r = IO.popen("#{@options.objdump} -t '#{elf}'") do |io|
      io.each_line do |line|
        if record = objdump_extract(line.chomp)
          next unless @options.text_sections.include?(record.section)
          debug(@options, :elf) do
            "Adding address for label #{record.label}: #{record.address}"
          end
          add_symbol(record.label, record.address)
        end
      end
    end
    die "The objdump command '#{@options.objdump}' exited with status #{$CHILD_STATUS.exitstatus}" unless $CHILD_STATUS.success?

    # Run platform-specific extractor, if available
    # Computes instruction_addresses
    @pml.arch.extract_symbols(self, @pml, @options) if @pml.arch.respond_to?(:extract_symbols)

    statistics("EXTRACT","extracted addresses" => stats_address_count) if @options.stats
    self
  end

  def update_pml
    @pml.machine_functions.each do |function|
      addr = @text_symbols[function.label] || @text_symbols[function.blocks.first.label]
      (warn("No symbol for machine function #{function.to_s}");next) unless addr
      ins_index = 0
      function.blocks.each do |block|
        if block_addr = @text_symbols[block.label]
          # Migh be different from current addr, as subfunctions require the emitter
          # to insert additional text between blocks.
          addr = block_addr
        elsif !@instruction_addresses[function.label]
          if @instruction_addresses.empty?
            die("There is no symbol for basic block #{block.label} (function: #{function.label}) in the binary")
          else
            die("There is no symbol for #{block.label}, and no instruction addresses for function #{function.label} are available")
          end
        elsif ins_addr = @instruction_addresses[function.label][ins_index]
          warn("Heuristic found wrong address for #{block}: #{addr}, not #{ins_addr}") if addr != ins_addr
          addr = ins_addr
        else
          warn("No symbol for basic block #{block}")
        end
        block.address = addr
        block.instructions.each do |instruction|
          # This might be necessary for von-Neumann architectures
          # (e.g., for ARMs BR_JTm instruction, where PML does not provide a size)
          if ins_addr = (@instruction_addresses[function.label] || {})[ins_index]
            warn("Heuristic found wrong address: #{instruction}: #{addr}, not #{ins_addr}") if addr != ins_addr
            addr = ins_addr
          elsif instruction.size == 0
            debug(@options,:elf) { "Size 0 for instruction #{instruction}" }
          end
          instruction.address = addr
          addr += instruction.size
          ins_index += 1
        end

        # Replace INLINEASM instructions
        instruction_data = []
        block.instructions.each do |instruction|
          if instruction.opcode != 'INLINEASM'
            instruction_data.push(instruction.data)
          else # INLINEASM instruction
            addr, size = instruction.address, instruction.size
            debug(@options,:elf) do
              "Replace INLINEASM block of size #{size} in #{function.label}"
            end
            while size > 0
              instr = @instructions[function.label][addr]
              assert("Could not disassemble address @ #{addr} #{instr}") { instr != nil and !instr['invalid'] }
              instruction_data.push(instr)
              addr += instr['size']
              size -= instr['size']
            end
            assert("Could not resolve INLINEASM block") do
              size == 0
            end
          end
        end
        # Reorder instructions
        instruction_data.each_with_index { |e, idx| e['index'] = idx }
        ## Update instruction list
        block.instructions = InstructionList.new(block, instruction_data)
      end
    end
    @pml.text_symbols = @text_symbols
    @pml
  end
  private
  RE_OBJDUMP_LABEL = %r{
    ( #{RE_HEX}{8} ) # address
    . {9}            # .ignore
    ( \S+ ) \s+      # section
    ( #{RE_HEX}+ ) \s+ # value
    ( \S+ ) # label
  }x
  def objdump_extract(line)
    return nil unless line =~ /\A#{RE_OBJDUMP_LABEL}$/
    OpenStruct.new(address: Integer("0x#{$1}"), section: $2, value: 3, label: $4)
  end
end

class ExtractSymbolsTool
  def self.add_config_options(opts)
    opts.on("--objdump-command FILE", "path to 'llvm-objdump'") { |f| opts.options.objdump = f }
    opts.on("--text-sections SECTION,..", "list of code sections (=.text)") { |s| opts.options.text_sections = s.split(/\s*,\s*/) }
    opts.add_check do |options|
      options.objdump = "patmos-llvm-objdump" unless options.objdump
      options.text_sections = [".text"] unless options.text_sections
    end
  end

  def self.add_options(opts)
    ExtractSymbolsTool.add_config_options(opts)
  end

  def self.run(pml, options)
    needs_options(options, :objdump, :text_sections, :binary_file)
    ExtractSymbols.new(pml,options).analyze.update_pml
  end
end

if __FILE__ == $PROGRAM_NAME
  SYNOPSIS = <<EOF
Extract Symbol Addresses from ELF file. It is possible to specify the same file
for input and output; as long as the ELF file does not change, this is an
idempotent transformation.
EOF

  options, args = PML::optparse([:binary_file], "program.elf", SYNOPSIS) do |opts|
    opts.needs_pml
    opts.writes_pml
    ExtractSymbolsTool.add_options(opts)
  end
  ExtractSymbolsTool.run(PMLDoc.from_files(options.input, options), options).dump_to_file(options.output)
end
