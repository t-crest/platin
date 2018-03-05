#
# PML toolset
#
# FFX/F4 exporter
#
require 'platin'
require 'ext/ffx'
require 'ext/otawa'
require 'English'
include PML

class FFXExportTool
  # TODO: There should be a common base class to the FFXExportTool and AISExportTool, providing helper-methods for the
  #      disable-export option and the actual export.

  FF_EXPORT_TYPES = %w{jumptables loop-bounds symbolic-loop-bounds flow-constraints} +
                    %w{infeasible-code call-targets mem-addresses stack-cache}

  def self.add_config_options(opts)
    # TODO: should we name the options --ffx-* to be consistent with the tool
    #       name and to distinguish from the SWEET ff format, or should we keep them
    #       as --ff to avoid confusion with F4 export ??
    opts.on("--ffx", "Export flow-facts using F4 instead of FFX") { |_d| opts.options.export_ffx = true }
    opts.on("--ff-input FILE", "the F4/FFX file is merged into the final F4/FFX file. " \
            "Needs to be the same format as the output format") do |file|
      opts.option.ff_input = file
    end
    opts.on("--ff-disable-exports LIST","F4/FFX information that should not be exported (see --help=ff)") do |list|
      opts.options.ff_disable_export = Set.new(list.split(/\s*,\s*/))
    end
    opts.add_check do |options|
      if options.ff_disable_export.nil?
        options.ff_disable_export = Set.new
      else
        unknown = (options.ff_disable_export - Set[*FF_EXPORT_TYPES])
        die("F4/FFX export types #{unknown.to_a} not known. Try --help=ff.") unless unknown.empty?
      end
    end
    opts.register_help_topic('ff') do |io|
      io.puts <<-EOF.strip_heredoc
        == F4/FFX Exporter ==

        The option --ff-disable-export controls which information is not exported
        (default is export everything that is supported) and takes a comma-separated list
        including one or more of the following types of information:

        jumptables           ... targets of indirect branches
        loop-bounds          ... all loop bound specifications
        symbolic-loop-bounds ... loop bounds that depend on the value of an argument/register
        flow-constraints     ... linear flow constraints
        infeasible-code      ... program points that are never executed
        call-targets         ... targets of (indirect) function calls
        mem-addresses        ... value ranges of accesses memory addresses
        stack-cache          ... information about stack cache behavior
        EOF
    end
  end

  def self.add_options(opts, mandatory = true)
    FFXExportTool.add_config_options(opts)
    opts.ff_file(mandatory)
    opts.flow_fact_selection
  end

  def self.run(pml, options)
    needs_options(options, :ff_file, :flow_fact_selection, :flow_fact_srcs)
    options.ff_disable_export = Set.new unless options.ff_disable_export

    File.open(options.ff_file, "w") do |outfile|
      if options.export_ffx
        ffx = FFXExporter.new(pml, options)
      else
        ffx = F4Exporter.new(pml, outfile, options)
      end

      ffx.merge_file(options.ff_input) unless options.ff_input.nil?

      pml.machine_functions.each { |func| ffx.export_jumptables(func) }
      flowfacts = pml.flowfacts.filter(pml, options.flow_fact_selection, options.flow_fact_srcs, ["machinecode"])
      ffx.export_flowfacts(flowfacts)

      unless options.ff_disable_export.include?('mem-addresses')
        pml.valuefacts.select do |vf|
          vf.level == "machinecode" && vf.origin == "llvm.mc" &&
            vf.ppref.context.empty? &&
            ['mem-address-read', 'mem-address-write'].include?(vf.variable)
        end.each do |vf|
          ffx.export_valuefact(vf)
        end
      end

      unless options.ff_disable_export.include?('stack-cache')
        pml.machine_functions.each do |func|
          func.blocks.each do |mbb|
            mbb.instructions.each do |ins|
              ffx.export_stack_cache_annotation(:fill, ins, ins.sc_fill) if ins.sc_fill
              ffx.export_stack_cache_annotation(:spill, ins, ins.sc_spill) if ins.sc_spill
            end
          end
        end
      end

      ffx.write(outfile) if options.export_ffx

      if options.stats
        statistics("F4/FFX",
                   "exported flow facts" => ffx.stats_generated_facts,
                   "unsupported flow facts" => ffx.stats_skipped_flowfacts)
      end
    end
  end
end

class OSXExportTool
  def self.add_config_options(opts); end

  def self.add_options(opts, mandatory = true)
    opts.analysis_entry

    opts.otawa_platform_file(mandatory)

    opts.add_check do |options|
      die_usage "No OTAWA platform description file specified." if mandatory && !options.otawa_platform_file
    end
  end

  def self.run(pml, options)
    needs_options(options, :otawa_platform_file)

    osx = OSXExporter.new(pml, options)

    File.open(options.otawa_platform_file, "w") do |fh|
      osx.export_platform(fh)
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  SYNOPSIS = <<-EOF
  Export flow information from PML as OTAWA F4/FFX file and generate OTAWA OSX platform config files.
  EOF
  options, args = PML::optparse([:input], "file.pml", SYNOPSIS) do |opts|
    FFXExportTool.add_options(opts, false)
    OSXExportTool.add_options(opts, false)
  end
  pml = PMLDoc.from_files([options.input], options)

  if options.ff_file.nil? && options.otawa_platform_file.nil?
    die_usage("Please speficy at least one of the F4/FF$ output file and the OSX platform file.")
  end

  FFXExportTool.run(pml, options) if options.ff_file

  OSXExportTool.run(pml, options) if options.otawa_platform_file
end
