# typed: false
Class.new(superclass = PlatinTest::Test) do

  def initialize
    @description       = "Test for correct splitting of basicblocks"
    @required_commands = ["arm-none-eabi-objdump", "llvm-objdump"]
    @required_gems     = ["lpsolve"]
    @entry             = "c_entry"
    @elf               = "test"
    @pml               = "#{@elf}.c.pml"
    @splitpml          = "#{@elf}.split.pml"
    @platininvocation  = "platin " \
        " wcet " \
        " --analysis-entry #{@entry}" \
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
    output = ""
    initcycles, initoutput, initstatus = PlatinTest::Test::platin_getcycles(@platininvocation + " -i ./#{@pml} ")
    output += initoutput
    if initstatus != 0
      @result = PlatinTest::Result.new(
        success: initstatus == 0 && check_cycles(initcycles),
        message: "Initial analysis (unsplitted) failed: Exitstatus: #{initstatus}\tCycles: #{initcycles}",
        output: output
      )
      return @result
    end


    splitoutput, splitstatus = PlatinTest::Test::execute_platin("platin basicblocksplitter -i ./#{@pml} -o ./#{@splitpml}")
    output += splitoutput
    if splitstatus != 0
      @result = PlatinTest::Result.new(
        success: splitstatus == 0,
        message: "Splitting basicblocks failed: Exitstatus: #{initstatus}",
        output: output
      )
      return @result
    end

    fincycles, finoutput, finstatus = PlatinTest::Test::platin_getcycles(@platininvocation + " -i ./#{@pml} ")

    @result = PlatinTest::Result.new(
      success: finstatus == 0 && check_cycles(fincycles) && initcycles == fincycles,
      message: "Final analysis: Exitstatus: #{finstatus}\tCycles original: #{initcycles}\tCycles splitted: #{fincycles}",
      output: output
    )
  end

  def id
    File.basename(File.dirname(@path))
  end
end.new
