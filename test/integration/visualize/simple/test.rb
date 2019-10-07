# typed: true
Class.new(superclass = PlatinTest::Test) do

  def initialize
    @description       = "Basic test for --link and --qualify-machincode"
    @required_commands = ["arm-none-eabi-objdump", "llvm-objdump"]
    @required_gems     = ["graphviz"]
    @entry             = "c_entry"
    @elf               = "test"
    @pml               = ["#{@elf}.c.pml"]
    @platininvocation  = "platin " \
                         " visualize " \
" --function #{@entry}" \
" #{@pml.map{|x| " -i #{x} "}.join(' ')} " \
        " --link " \
        " --qualify-machinecode " \
        " --debug ilp "
  end

  def check_cycles(cycles)
    !cycles.nil? && cycles > 0
  end

  def enabled?
    PlatinTest::Test::check_commands(*@required_commands) && PlatinTest::Test::check_gems(*@required_gems)
  end

  def rmf(file)
    File.delete(file) if File.exist?(file)
  end

  def run
    artifacts = ["c_entry.bc.png", "c_entry.mc.png", "c_entry.mc.sg.png", "c_entry.bc.sg.png", "c_entry.cg.png", "c_entry.rg.png"]
    artifacts.each do |f|
      rmf(f)
    end

    output, status = PlatinTest::Test::execute_platin(@platininvocation)
    success = status

    output += "\nVerifying artifacts exist:\n"
    artifacts.each do |f|
      exists = File.exist?(f)
      output += "File #{f}: #{exists ? "found" : "not found"}\n"
      success &&= exists
    end

    @result = PlatinTest::Result.new(
      success: status == 0 && success,
      message: "Exitstatus: #{status}\tFiles exist: #{success}",
      output: output
    )
  end

  def id
    File.basename(File.dirname(@path))
  end
end.new
