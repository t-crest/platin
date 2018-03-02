#
# PLATIN Toolchain
#
# Generate trace using pasim and extract flow facts (underapproximations)
#
# A word on performance; Currently we have (buildbot, adpcm -O0):
#  pasim >/dev/null .. 18s
#  read from pasim  .. 1m39
#  read and parse   .. 1m52
#  platin-analyze-trace .. 2m
# So there is probably not a lot to optimize in the ruby logic.
#
# Nevertheless, for this tool it might be worth to think of a faster solution;
# it seems as if the pipe communication is the culprit.

require 'platin'
require 'tools/extract-symbols.rb'
require 'English'
include PML

class AnalyzeTraceTool
  def initialize(pml, options, entry)
    @pml, @options, @entry = pml, options, entry
  end

  def analyze_trace
    tm = MachineTraceMonitor.new(@pml, @options)
    debug(@options, :trace) do
      tm.subscribe(VerboseRecorder.new(DebugIO.new))
      "Starting trace analysis"
    end
    @main_recorder = RecorderScheduler.new(@options.recorders, @entry, @options)
    tm.subscribe(@main_recorder)
    trace = @pml.arch.simulator_trace(@options, tm.watchpoints)
    tm.run(trace)

    die "Analysis entry '#{@options.analysis_entry}' (pc: #{@entry.address}) never executed" if @main_recorder.runs == 0
    @executed_blocks = @main_recorder.executed_blocks
    @infeasible_functions = Set.new
    @executed_blocks.each do |function,_bset|
      function.callsites.each do |cs|
        next if cs.unresolved_call?
        cs.callees.each do |callee|
          f = @pml.machine_functions.by_label(callee)
          @infeasible_functions.add(f) unless @executed_blocks[f]
        end
      end
    end
    statistics("TRACE", "simulator trace length" => trace.stats_num_items) if @options.stats
  end

  def console_output
    # Verbose Output
    if @options.verbose || @options.console_output
      @main_recorder.recorders.each do |recorder|
        recorder.dump($stdout)
      end
      $stdout.puts "* Executed Functions: #{@main_recorder.executed_blocks.keys.join(", ")}"
    end
    # Warn about functions / loops not executed
    @infeasible_functions.each do |function|
      warn "Reachable function #{function} never executed by trace"
    end
    @executed_blocks.each do |function,bset|
      function.loops.each do |loop|
        warn "Loop #{loop} not executed by trace" unless bset.include?(loop.loopheader)
      end
    end
    # # Console Output
    # if ! @options.output
    #   $stdout.puts "=== Summary of '#{@options.analysis_entry}' observed during " +
    #                "execution of '#{@options.trace_entry}' ==="
    #   loops_by_fun = Hash.new
    #   @loops.results.each { |loop, r| (loops_by_fun[loop.function]||=[]).push([loop,r]) }
    #   @local.results.each { |scope,r|
    #     $stdout.printf("Function %-30s  Cycles: %15s  Executions: %8d\n",scope,r.cycles,r.runs)
    #     (loops_by_fun[scope] || []).each { |loop,rl|
    #       $stdout.printf(" Loop %-30s     Cycles: %15s  Executions: %8d Bounds: %8s\n",
    #                    loop, rl.cycles, rl.runs, rl.freqs.values[0])
    #     }
    #   }
    # end
  end

  def export_facts
    outpml = @pml

    fact_context = { 'level' => 'machinecode', 'origin' => @options.flow_fact_output || 'trace' }

    # if we have a global recorder, add timing extracted from trace
    global_recorders = @main_recorder.global_recorders
    unless global_recorders.empty?
      global = global_recorders.first
      outpml.timing.add(TimingEntry.new(global.scope,global.results.cycles.max,nil,fact_context))
    end

    flowfacts_before = @pml.flowfacts.length

    @main_recorder.recorders.each do |recorder|
      scope = recorder.scope
      suffix = recorder.type
      # Export call targets (mandatory for WCET analysis)
      # Only export if either unresolved in the compiler or the dynamic receiver set is smaller than the static one
      recorder.results.calltargets.each do |cs_ref,receiverset|
        cs = cs_ref.programpoint
        next unless cs.unresolved_call? || cs.callees.size != receiverset.size
        ff = FlowFact.calltargets(scope, cs_ref, receiverset, fact_context)
        debug(@options,:trace) { "Adding trace flowfact #{ff}" }
        outpml.flowfacts.add(ff)
      end
      # Export block frequencies; infeasible blocks are necessary for WCET analysis
      recorder.results.blockfreqs.each do |block_ref,freq|
        type = (freq.max == 0) ? "infeasible" : "block"
        next unless recorder.report_block_frequencies || type == "infeasible"
        outpml.flowfacts.add(FlowFact.block_frequency(scope, block_ref, freq, fact_context))
      end
      # Export loop header bounds (mandatory for WCET analysis) for global analyses
      if recorder.global?
        recorder.results.loopbounds.each do |loop_ref,bound|
          outpml.flowfacts.add(FlowFact.loop_bound(loop_ref, bound.max, fact_context))
        end
      end
    end
    statistics("TRACE", "extracted flow-flact hypotheses" =>
               outpml.flowfacts.length - flowfacts_before) if @options.stats
    outpml
  end

  # The default recorder record loop bounds, infeasibles and calltargets globally, and
  # intraprocedural block frequencies
  DEFAULT_RECORDER_SPEC = "g:lic,f:b/0"

  def self.add_config_options(opts)
    Architecture.simulator_options(opts)
    opts.trace_entry
    opts.callstring_length
    opts.target_callret_costs
    opts.on("--recorders LIST",
            "recorder specification (=#{DEFAULT_RECORDER_SPEC}; see --help=recorders)") do |recorder_spec|
      opts.options.recorder_spec = recorder_spec
    end
    opts.on("--max-cycles NUM", Integer,
            "consider only the first NUM cycles of the trace") do |num|
      opts.options.max_cycles = num
    end
    opts.on("--max-instructions NUM", Integer,
            "consider only the first NUM instructions of the trace") do |num|
      opts.options.max_instructions = num
    end
    opts.on("--max-target-traces NUM", Integer,
            "maximum number of target function executions to trace (unlimited if not set)") do |num|
      opts.options.max_target_traces = num
    end
    opts.on("--sim-input FILE", "Pass file as input to program under test.") { |f| opts.options.sim_input = f }
    opts.register_help_topic('recorders') do |io|
      RecorderSpecification.help(io)
    end
    opts.add_check do |options|
      options.recorder_spec = DEFAULT_RECORDER_SPEC unless options.recorder_spec
      options.recorders = RecorderSpecification.parse(options.recorder_spec, options.callstring_length)
    end
  end

  def self.add_options(opts)
    ExtractSymbolsTool.add_config_options(opts)
    AnalyzeTraceTool.add_config_options(opts)
    opts.binary_file(true)
    opts.trace_entry
    opts.analysis_entry
    opts.generates_flowfacts
  end

  def self.run(pml,options)
    needs_options(options, :analysis_entry, :trace_entry, :binary_file, :recorder_spec)
    entry = pml.machine_functions.by_label(options.analysis_entry, true)
    die("Analysis entry (ELF label #{options.analysis_entry}) not found") unless entry

    unless entry.blocks.first.address
      warn("No addresses in PML file, trying to extract from ELF file")
      ExtractSymbolsTool.run(pml,options)
    end
    tool = AnalyzeTraceTool.new(pml, options, entry)
    tool.analyze_trace
    tool.console_output
    tool.export_facts
  end
end

if __FILE__ == $PROGRAM_NAME
  SYNOPSIS = <<-EOF
  Run simulator (patmos: pasim --debug-fmt trace), record execution frequencies
  of instructions and generate flow facts. Also records indirect call targets.
  EOF
    # FIXME: binary file is passed as positional argument, and thus should not be shown
    # as option argument in usage
  options, args = PML::optparse([], "", SYNOPSIS) do |opts|
    opts.needs_pml
    opts.writes_pml
    AnalyzeTraceTool.add_options(opts)
  end
  options.console_output = true unless options.output
  pml = AnalyzeTraceTool.run(PMLDoc.from_files(options.input, options), options)
  pml.dump_to_file(options.output) if options.output
end
