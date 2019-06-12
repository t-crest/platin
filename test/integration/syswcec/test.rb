Class.new(superclass = PlatinTest::Test) do

  def initialize
    @description       = "Basic test for SysWCEC calculation"
    @required_commands = ["arm-none-eabi-objdump", "llvm-objdump"]
    @required_gems     = ["lpsolve"]
    @entry             = "GCFG:timing-0"
    @elf               = "ma_interrupt"
    @pml               = ["#{@elf}-gcfg.pml", "#{@elf}-system.pml"]
    @platininvocation  = "platin " \
        " wcet " \
        " --disable-ait" \
        " --analysis-entry #{@entry}" \
        " -i ./#{@pml[0]} " \
        " -i ./#{@pml[1]} " \
        " -b #{@elf} " \
        " --objdump llvm-objdump" \
        " --wcec"
  end

  def check_bound(bound)
    !bound.nil? && bound > 0
  end

  def enabled?
    Test::check_commands(*@required_commands) && Test::check_gems(*@required_gems)
  end

  def run
    output, status = Test::execute_platin(@platininvocation)
    # match in reverse order: we want the last cycles
    wcec = output.lines.reverse.find {|l| l =~ /best WCEC bound: (-?\d+(\.\d+)?) mJ/m}
    unless wcec.nil?
      bound, output, status = Float($1), output, status.exitstatus
    else
      Test::logn("Failed to determine wcec bound", level: Log::WARN)
      Test::logn(output, level: Log::DEBUG)
      bound, output, status = nil, output, status.exitstatus
    end
    @result = Result.new(
      success: status == 0 && check_bound(bound),
      message: "Exitstatus: #{status}\tWCEC: #{bound}",
      output: output
    )
  end

  def id
    File.basename(File.dirname(@path))
  end
end.new
