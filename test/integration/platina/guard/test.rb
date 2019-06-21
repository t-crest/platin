# typed: true
Class.new(superclass = PlatinTest::Test) do

  def initialize
    @description       = "Basic test for the '#pragma platina guard' annotation"
    @required_commands = ["arm-none-eabi-objdump", "llvm-objdump"]
    @required_gems     = ["lpsolve"]
    @entry             = "c_entry"
    @elf               = "test"
    @pml               = "#{@elf}.c.pml"
    @platininvocation  = "platin " \
        " wcet " \
        " --analysis-entry #{@entry}" \
        " -i ./#{@pml} " \
        " -b #{@elf} " \
        " --disable-ait " \
        " --enable-wca " \
        " --report " \
        " --objdump llvm-objdump" \
        " --debug ilp "
  end

  def check_cycles(cycles)
    !cycles.nil? && cycles > 0
  end

  def enabled?
    PlatinTest::Test::check_commands(*@required_commands) && PlatinTest::Test::check_gems(*@required_gems)
  end

  def run
    cycles, output, status = PlatinTest::Test::platin_getcycles(@platininvocation)
    @result = PlatinTest::Result.new(
      success: status == 0 && check_cycles(cycles),
      message: "Exitstatus: #{status}\tCycles: #{cycles}",
      output: output
    )
  end

  def id
    File.basename(File.dirname(@path))
  end
end.new
