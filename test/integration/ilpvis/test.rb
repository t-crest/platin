Class.new(superclass = PlatinTest::Test) do

  def initialize
    @description       = "Basic test for testing the graphical ilp visualisation"
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
        " --debug ilp " \
        " --visualize-ilp " \
        " --outdir . "
  end

  def check_cycles(cycles)
    !cycles.nil? && cycles == -1
  end

  def enabled?
    Test::check_commands(*@required_commands) && Test::check_gems(*@required_gems)
  end

  def rmf(file)
    File.delete(file) if File.exist?(file)
  end

  def run
    artifacts = ["ilp.svg", "constraints.json", "srchints.json"]
    artifacts.each do |f|
      rmf(f)
    end

    cycles, output, status = Test::platin_getcycles(@platininvocation)

    success = true
    output += "\nVerifying artifacts exist:\n"
    artifacts.each do |f|
      exists = File.exist?(f)
      output += "File #{f}: #{exists ? "found" : "not found"}\n"
      success &&= exists
    end

    output += "Checking for file ilp.svg"
    if File.exist?("ilp.svg")
      output += " success"
      pattern = "∞ × 1"
      output += "Expecting string #{pattern} in file ilp.svg: "
      if File.readlines("ilp.svg").grep(/#{pattern}/).empty?
        success = false
        output += "not found\n"
      else
        output += "found\n"
      end
    else
      success = false
      output += " failed"
    end

    @result = Result.new(
      success: status == 0 && check_cycles(cycles) && success,
      message: "Exitstatus: #{status}\tCycles: #{cycles}",
      output: output
    )
  end

  def id
    File.basename(File.dirname(@path))
  end
end.new
