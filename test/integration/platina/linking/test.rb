# typed: false
Class.new(superclass = PlatinTest::Test) do

  def initialize
    @description       = "Basic test for --link and --qualify-machincode"
    @required_commands = ["arm-none-eabi-objdump", "llvm-objdump"]
    @required_gems     = ["lpsolve"]
    @entry             = "c_entry"
    @elf               = "test"
    @pml               = ["#{@elf}.c.pml", "sched.c.pml"]
    @platininvocation  = "platin " \
        " wcet " \
        " --analysis-entry #{@entry}" \
        " #{@pml.map{|x| " -i #{x} "}.join(' ')} " \
        " -b #{@elf} " \
        " --disable-ait " \
        " --enable-wca " \
        " --report " \
			  " --link " \
        " --qualify-machinecode " \
        " --objdump llvm-objdump" \
        " --debug ilp "
  end

  def check_cycles(cycles)
    !cycles.nil? && cycles > 0
  end

  def enabled?
    Test::check_commands(*@required_commands) && Test::check_gems(*@required_gems)
  end

  def run
    cycles, output, status = Test::platin_getcycles(@platininvocation)
    @result = Result.new(
      success: status == 0 && check_cycles(cycles),
      message: "Exitstatus: #{status}\tCycles: #{cycles}",
      output: output
    )
  end

  def id
    File.basename(File.dirname(@path))
  end
end.new
