#
# PLATIN tool set
#
# PML data format classes
#
require 'core/utils'
require 'core/pmlbase'
require 'core/arch'
require 'core/configuration'
require 'core/context'
require 'core/program'
require 'core/programinfo'

# preferably, we would have something like:
# include PML::Kernel
# to have assert and friends in scope
include PML

module PML

# class providing convenient accessors and additional program information derived
# from PML files
class PMLDoc
  attr_reader :data, :triple, :arch, :analysis_configurations
  attr_reader :bitcode_functions,:machine_functions,:relation_graphs,:global_cfgs
  attr_reader :flowfacts,:valuefacts,:timing
  attr_reader :tool_configurations
  attr_reader :sca_graph

  # constructor expects a YAML document or a list of YAML documents
  def initialize(stream)
    stream = [stream] unless stream.kind_of?(Array)
    if stream.length == 1
      @data = stream[0]
    else
      @data = PMLDoc.merge_stream(stream)
    end

    # read-only sections
    if @data['triple']
      @triple = @data['triple'].split('-')
      machine_config = @data['machine-configuration'] ? MachineConfig.from_pml(self, @data['machine-configuration']) : nil
      @arch = Architecture.from_triple(triple, machine_config)
    else
      @triple = nil
      @arch = nil
    end

    retag_machinefunctions(@data)
    @bitcode_functions = FunctionList.new(@data['bitcode-functions'] || [], :labelkey => 'name')
    @machine_functions = FunctionList.new(@data['machine-functions'] || [], :labelkey => 'mapsto')
    @relation_graphs   = RelationGraphList.new(@data['relation-graphs'] || [],
                                               @bitcode_functions, @machine_functions)
    @global_cfgs       = GCFGList.new(@data['global-cfgs'] || [], @relation_graphs)


    # usually read-only sections, but might be modified by pml-config
    @data['analysis-configurations'] ||= []
    @analysis_configurations = AnalysisConfigList.from_pml(self, @data['analysis-configurations'])
    @data['tool-configurations'] ||= []
    @tool_configurations = ToolConfigList.from_pml(self, @data['tool-configurations'])

    # read-write sections
    @data['flowfacts'] ||= []
    @flowfacts = FlowFactList.from_pml(self, @data['flowfacts'])
    @data['valuefacts'] ||= []
    @valuefacts = ValueFactList.from_pml(self, @data['valuefacts'])
    @data['timing'] ||= []
    @timing = TimingList.from_pml(self, @data['timing'])
    @sca_graph = SCAGraph.new(self, @data['sca-graph']) if @data.include?('sca-graph')
    @sca_graph ||= nil
  end
  def valuefacts
    @valuefacts
  end

  # Name generation scheme
  def qualify_machinefunction_name(file, name)
    return file + "." + name
  end

  def retag_machinefunctions(data)
    # Machinefunctionnames are actually counters. Those are unique only for each
    # individual pmlfile. Therefore we qualify them via filename.
    (data['machine-functions'] || []).each do |m|
      assert("machine-functions have to be on machinecode level") { m['level'] == "machinecode" }
      if m.has_key?('pmlsrcfile')
        m['name'] = qualify_machinefunction_name(m['pmlsrcfile'], m['name'])
      end
    end

    (data['relation-graphs'] || []).each do |m|
      if m.has_key?('pmlsrcfile')
        mcode = nil
        if m['src']['level'] == 'machinecode'
          mcode = m['src']
        elsif m['dst']['level'] == 'machinecode'
          mcode = m['dst']
        end

        assert("relationship graphs map between bitcode and machinecode level") { mcode != nil };
        mcode['function'] = qualify_machinefunction_name(m['pmlsrcfile'], mcode['function'])
      end
    end

		(data['valuefacts'] || []).each do |v|
			if v['level'] == "machinecode" && v.has_key?('pmlsrcfile')
				pp = v['program-point']
				assert("valuefacts require a program point") { pp != nil }
				pp['function'] = qualify_machinefunction_name(v['pmlsrcfile'], pp['function'])
			end
		end
  end

  def analysis_entry(options)
    gcfg_name = options.analysis_entry.dup
    if gcfg_name.slice!(/^GCFG:/)
      gcfg = global_cfgs.by_name(gcfg_name)
      if gcfg
        gcfg.entry_node
      end
    else
      machine_functions.by_label(options.analysis_entry)
    end
  end


  def functions_for_level(level)
    if level == 'bitcode'
      bitcode_functions
    elsif level == 'machinecode'
      machine_functions
    else
      raise Exception.new("Unsupported representation level: #{level}")
    end
  end

  def clone_empty
    data = {}
    data['format'] = @data['format']
    data['triple'] = @data['triple']
    PMLDoc.new(data)
  end

  #
  # used if some modifications to the PML database should not become permanent
  # saves the specified sections before yielding, and restores them afterwards
  def with_temporary_sections(temporary_sections = [:flowfacts, :valuefacts, :timing])
    backup = temporary_sections.map { |s| self.send(s) }
    begin
      temporary_sections.map { |s|
        instance_variable_set("@#{s}", Marshal.load(Marshal.dump(self.send(s))))
      }
      r = yield
    ensure
      temporary_sections.zip(backup).each { |s,b|
        instance_variable_set("@#{s}",b)
      }
    end
    r
  end

  def to_s
    sprintf("PMLDoc{bitcode-functions: |%d|, machine-functions: |%d|"+
            ", flowfacts: |%s|, valuefacts: |%d|, timings: |%d|, gcfgs:|%d|",
            bitcode_functions.length, machine_functions.length,
            flowfacts.length,valuefacts.length,timing.length,global_cfgs.length)
  end

  def dump_to_file(filename, write_config=false)
    if filename.nil? || filename == '-'
      dump($>, write_config)
    else
      File.open(filename, "w") do |fh|
        dump(fh, write_config)
      end
    end
  end

  def dump(io, write_config=false)
    @data["bitcode-functions"] = @bitcode_functions.to_pml
    @data["machine-functions"] = @machine_functions.to_pml
    @data["relation-graphs"]   = @relation_graphs.to_pml

    final = deep_data_clone # eliminate sharing to enable YAML import in LLVM

    # XXX: we do not export machine-configuration and analysis-configurations by default for now
    # The trouble is that we first need to mirror those sections for LLVM's yaml-io :(
    final.delete("machine-configuration") if @data["machine-configuration"] == [] or not write_config
    final.delete("analysis-configurations") if @data["analysis-configurations"] == [] or not write_config
    final.delete("tool-configurations") if @data["tool-configurations"] == [] or not write_config
    final.delete("flowfacts") if @data["flowfacts"] == []
    final.delete("valuefacts") if @data["valuefacts"] == []
    final.delete("timing") if @data["timing"] == []
    io.write(YAML::dump(final))
  end

  def deep_data_clone
    cloned_data = @data.dup
    worklist = [cloned_data]
    while ! worklist.empty?
      d = worklist.pop
      if d.kind_of?(Hash)
        d.each { |k,v|
          # compounds are always sequences (Array) or mappings (Hash)
          if v.kind_of?(Hash) || v.kind_of?(Array)
            d[k] = v_copy = v.dup
            worklist.push(v_copy)
          end
        }
      elsif d.kind_of?(Array)
        d.each_with_index { |v,k|
          if v.kind_of?(Hash) || v.kind_of?(Array)
            d[k] = v_copy = v.dup
            worklist.push(v_copy)
          end
        }
      else
        assert("Internal error in deep_data_clone: non-compound in worklist") { false }
      end
    end
    cloned_data
  end

  def machine_code_only_functions
    %w{_start _exit exit abort __ashldi3 __adddf3 __addsf3 __divsi3 __udivsi3 __divdf3 __divsf3 __eqdf2 __eqsf2 __extendsfdf2} +
      %w{__fixdfdi __fixdfsi __fixsfdi __fixsfsi __fixunsdfdi __fixunsdfsi __fixunssfdi __fixunssfsi __floatdidf __floatdisf} +
      %w{__floatsidf __floatsisf __floatundidf __floatundisf __floatunsidf __floatunsisf __gedf2 __gesf2 __gtdf2 __gtsf2} +
      %w{__ledf2 __lesf2 __lshrdi3 __ltdf2 __ltsf2 __muldf3 __mulsf3 __nedf2 __nesf2 __subdf3 __subsf3 __truncdfsf2 __unorddf2 __unordsf2} +
      %w{memcpy memmove memset}
  end

  def PMLDoc.from_files(filenames)
    streams = filenames.inject([]) { |list,f|
      begin
        fstream = File.open(f) { |fh|
          stream = YAML::load_stream(fh)
          stream.documents if stream.respond_to?(:documents) # ruby 1.8 compat
          [[f, stream]]
        }
        list + fstream
      rescue Exception => detail
        die("Failed to load PML document: #{detail}")
      end
    }
    PMLDoc.new(streams)
  end

  def PMLDoc.merge_stream(stream)
    merged_doc = {}
    stream.each do |fstream|
      (fname, content) = fstream
      content.each do |doc|
        doc.each do |k,v|
          if(v.kind_of? Array)
            v.map! { |elem|
              if (elem.kind_of? Hash)
                elem['pmlsrcfile'] = fname
              end
              elem
            }
            (merged_doc[k]||=[]).concat(v)
          elsif(! merged_doc[k])
            merged_doc[k] = doc[k]
          elsif(merged_doc[k] != doc[k])
            die "Mismatch in non-list attribute #{k}: #{merged_doc[k]} and #{doc[k]}"
          end
        end
      end
    end
    merged_doc
  end
end

end # mdoule PML
