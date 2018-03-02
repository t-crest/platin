#!/usr/bin/env ruby
#
# platin tool set
#
# "Inhouse" IPET-based WCET analysis

require 'platin'
require 'analysis/wca'
require 'English'
include PML

class WcaTool
  def self.add_config_options(opts)
    opts.on("--[no-]wca-cache-regions","use single-entry cache regions (=true)") do |b|
      opts.options.wca_cache_regions = b
    end
    opts.on("--[no-]wca-persistence-analysis","use (more expensive) persistence DFA for LRU caches (=false)") do |b|
      opts.options.wca_persistence_analysis = b
    end
    opts.on("--wca-ideal-cache","assume each cache block is loaded at most once (=false)") do |b|
      opts.options.wca_ideal_cache = b
    end
    opts.on("--wca-minimal-cache","assume there is only one cache block (=false)") do |b|
      opts.options.wca_minimal_cache = b
    end
    opts.on("--wca-data-cache-analysis ANALYSIS","data cache analysis type (scope,always-hit,=always-miss)") do |v|
      opts.options.wca_data_cache_analysis = v
    end
    opts.on("--wca-write-lp-file FILE", "write the ILP problem to an .lp file") do |f|
      # TODO: Set wca_write_lp, and set options.write_lp only when invoking the ILP solver.
      #      Or only set a dir and prefix here and create unique filenames per ILP invocation.
      opts.options.write_lp = f
    end
    opts.on("--wca-use-gurobi", "use Gurobi solver instead of lp_solve") do |v|
      opts.options.use_gurobi = v
    end
    # Disable all cache related costs.
    opts.on("--wca-disable-cache", "disable all cache related  costs") do |f|
      opts.options.disable_dca = true
      opts.options.disable_sca = true
      opts.options.disable_ica = true
    end
    opts.add_check do |options|
      options.wca_cache_regions = true if options.wca_cache_regions.nil?
      # TODO: change this default to 'scope' once the scope analysis works properly
      options.wca_data_cache_analysis = 'always-miss' if options.wca_data_cache_analysis.nil?
    end
    opts.stack_cache_analysis
    opts.target_callret_costs
  end

  def self.add_options(opts)
    WcaTool.add_config_options(opts)
    opts.analysis_entry
    opts.flow_fact_selection
    opts.callstring_length
    opts.calculates_wcet('wca-unknown')
    opts.stack_cache_analysis
  end

  def self.run(pml,options)
    needs_options(options, :analysis_entry, :flow_fact_selection, :flow_fact_srcs, :timing_output)
    wca = WCA.new(pml, options)
    report = wca.analyze(options.analysis_entry)
    pml.timing.add(report)
    pml
  end
end

if __FILE__ == $PROGRAM_NAME
  SYNOPSIS = <<-EOF
  Calculate WCET using lp_solve and a simple timing model
  EOF
  options, args = PML::optparse(0, "", SYNOPSIS) do |opts|
    opts.needs_pml
    opts.writes_pml
    WcaTool.add_options(opts)
  end
  WcaTool.run(PMLDoc.from_files(options.input, options), options).dump_to_file(options.output)
end
