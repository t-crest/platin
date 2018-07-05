#
# platin tool set
#
# "Inhouse" Worst-Case Execution Time Analysis using IPET
#
require 'core/utils'
require 'core/pml'
require 'analysis/ipet'
require 'analysis/cache_region_analysis'
require 'analysis/vcfg'
require 'ext/lpsolve'
require 'ext/gurobi'

#require 'tools/visualize-ilp'

module PML

class WCA

  def initialize(pml, options)
    @pml, @options = pml, options
  end

  def edge_cost(edge)
    # get list of executed instructions
    branch_index = nil
    ilist =
        if (edge.kind_of?(Block))
          edge.instructions
        else
          # Special Case for GCFG Node+>Node Edges
          if edge.level == :gcfg
            src = edge.source.abb.get_region(:dst).exit_node
            if edge.target == :exit
              dst = :exit
            else
              dst = edge.target.abb.get_region(:dst).entry_node
            end
          else
            src = edge.source
            dst = edge.target
          end
          src.instructions.each_with_index { |ins,ix|
            if ins.returns? && (dst == :exit || edge.level == :gcfg)
              branch_index = ix # last instruction that returns
            elsif ! ins.branch_targets.empty? && ins.branch_targets.include?(dst)
              branch_index = ix # last instruction that branches to the target
            elsif ! ins.branch_targets.empty? && edge.level == :gcfg && dst != :exit
              branch_index = ix
            end
          }
          if ! branch_index
            src.instructions
          else
            slots = src.instructions[branch_index].delay_slots
            slot_end = branch_index
            instr = src.instructions[slot_end+1]
            while slots > 0 || (instr && instr.bundled?)
              if ! (instr && instr.bundled?)
                slots = slots - 1
              end
              slot_end = slot_end + 1
              instr = src.instructions[slot_end+1]
            end
            src.instructions[0..slot_end]
          end
        end
      if @options.wca_count_instructions
        path_wcet = ilist.length
        edge_wcet = 0
      else
        path_wcet = @pml.arch.path_wcet(ilist)
        edge_wcet = @pml.arch.edge_wcet(ilist,branch_index,edge)
      end
      debug(@options,:costs) { "WCET edge costs for #{edge}: #{path_wcet} block, #{edge_wcet} edge" }
      path_wcet + edge_wcet
  end

  def analyze_fragment(entries, exists, blocks, &cost)
    # Builder and Analysis Entry
    ilp = GurobiILP.new(@options) if @options.use_gurobi
    ilp = LpSolveILP.new(@options) unless ilp

    # flow facts
    ff_levels = ["machinecode", "gcfg"]
    flowfacts = @pml.flowfacts.filter(@pml,
                                      @options.flow_fact_selection,
                                      @options.flow_fact_srcs,
                                      ff_levels,
                                      true)

    builder = IPETBuilder.new(@pml, @options, ilp)
    builder.build_fragment(entries, exists, blocks, flowfacts, cost)

    x = @pml.machine_functions.by_label("unexpected_interrupt")
    ilp.add_constraint([[x.blocks.first, 1]], "equal", 0, "no_unexpected_interrupts", :archane)


    # Solve ILP
    begin
      cycles, freqs = ilp.solve_max
    rescue Exception => ex
      warn("WCA: ILP failed: #{ex}") unless @options.disable_ipet_diagnosis
      cycles,freqs = -1, {}
    end

    if @options.verbose
      freqs.each {|edge, freq|
        next if freq * ilp.get_cost(edge) == 0
        p [edge, freq, ilp.get_cost(edge)]
      }
    end
    cycles
  end

  def two_decimals(float_n)
     float_n.round(3).to_s[0..3].to_f
  end
  def three_decimals(float_n)
     float_n.round(4).to_s[0..4].to_f
  end

TIME_PER_CYCLE = 1/(1e6) # 1MHz => 1us

  def analyze(entry_label)

    # Builder and Analysis Entry
    ilp = GurobiILP.new(@options) if @options.use_gurobi
    ilp = LpSolveILP.new(@options) unless ilp

    gcfg = @pml.analysis_gcfg(@options)
    machine_entry = gcfg.get_entry()['machinecode'].first

    # PLAYING: VCFGs
    #bcffs,mcffs = ['bitcode','machinecode'].map { |level|
    #  @pml.flowfacts.filter(@pml,@options.flow_fact_selection,@options.flow_fact_srcs,level)
    #}
    #ctxm = ContextManager.new(@options.callstring_length,1,1,2)
    #mc_model = ControlFlowModel.new(@pml.machine_functions, machine_entry, mcffs, ctxm, @pml.arch)
    #mc_model.build_ipet(ilp) do |edge|
      # pseudo cost (1 cycle per instruction)
    #  if (edge.kind_of?(Block))
    #    edge.instructions.length
    #  else
    #    edge.source.instructions.length
    #  end
    #end

    #cfbc = ControlFlowModel.new(@pml.bitcode_functions, bitcode_entry, bcffs,
    #                            ContextManager.new(@options.callstring_length), GenericArchitecture.new)

    # BEGIN: remove me soon
    # builder
    builder = IPETBuilder.new(@pml, @options, ilp)

    # flow facts
    ff_levels = ["machinecode", "gcfg"]
    flowfacts = @pml.flowfacts.filter(@pml,
                                     @options.flow_fact_selection,
                                     @options.flow_fact_srcs,
                                     ff_levels,
                                     true)

    # units
    # info ("Assuming time per cycle: #{TIME_PER_CYCLE} second")

    # Build IPET using costs from @pml.arch
    local_builder = nil
    if @options.wcec
      # We calculate WCETs for each ABB and every function that is
      # directly called
      wcet = Hash.new
      t_wcrt_all1 = Time.now
      gcfg.nodes.each do |node|
        next if node.abb and wcet.member?(node.abb)
        next if node.function and wcet.member?(node.function)

        local_ilp = GurobiILP.new(@options) if @options.use_gurobi
        local_ilp = LpSolveILP.new(@options) unless local_ilp
        local_builder = IPETBuilder.new(@pml, @options, local_ilp)

        if node.microstructure
          next
        elsif node.abb
          blocks = []
          nodes = []
          entry_nodes = []
          exit_nodes = []

          # If this block is an ISR entry, we capture this block, and
          # all following microstructural ABBs and put them into this
          # fragment. Lateron, the microstructural ABBs are accounted
          # with a cost of 0
          wcet_for_obj = nil
          power_states = Set.new
          if node.isr_entry?
            wcet_for_obj = node
            assert("ISR entry node cannot be microstructural") {!node.microstructure}
            assert("ISR entry node should be a function") {node.abb.function}

            irq_nodes = Set.new
            worklist = [node]
            while worklist.length > 0
              elem = worklist.shift
              irq_nodes.add(elem)
              elem.successors.each do |next_node|
                next unless next_node.microstructure
                next if irq_nodes.member?(next_node)
                worklist.push(next_node)
              end
            end
            ## Prepare an SSTG fragment from irq_entry --> iret
            # Blocks/ABB: Copy and reindex
            abb_to_idx = {}
            irq_nodes.each_with_index do |n|
              power_states.add(n.devices)
              next unless n.abb
              next if abb_to_idx[n.abb]
              idx = abb_to_idx.length
              abb_to_idx[n.abb] = idx
              data = n.abb.data.dup
              data['index'] = idx
              blocks.push(data)
            end
            # Nodes: copy and reindex
            node_to_idx ={}
            irq_nodes.each_with_index do |n, idx|
              node_to_idx[n] = idx
              data = n.data.dup
              data['index'] = idx
              if n.abb
                data['abb'] = abb_to_idx[n.abb]
              end
              nodes.push(data)
            end

            # Fixup node ID references and find entry and exit nodes
            nodes.each do |copied_node|
              copied_node['local-successors'] = copied_node['local-successors'].map do |old_idx|
                ret = node_to_idx[gcfg.nodes[old_idx]]
                assert("broken") {ret}
                ret
              end
              copied_node['global-successors'] = []
              if copied_node['isr_entry']
                entry_nodes.push(copied_node['index'])
              end
              if /iret/ =~ (copied_node['abb-name'] ||"")
                exit_nodes.push(copied_node['index'])
              end
            end
          else # node.isr_entry? == false
            # For non IRQ nodes: use only the node itself, and its
            # associated function
            blocks.push(node.abb.to_pml.dup)
            blocks[0]['index'] = 0
            nodes.push({'index'=>0, 'abb'=>0})
            entry_nodes = [0]
            exit_nodes = [0]
            wcet_for_obj = node.abb
          end

          fragment = GCFG.new({'level'=>'bitcode',
                               'name'=> node.abb.to_s,
                               'entry-nodes'=>entry_nodes,
                               'exit-nodes'=>exit_nodes,
                               'nodes'=> nodes,
                               'blocks'=> blocks},
                              @pml)

        else
          # this should never happen
          assert("No microstructure and no ABB: this should never happen!") {false}
        end

        local_builder.build_gcfg(fragment, flowfacts) do |edge|
          edge_cost(edge)
        end

        cycles, freqs = local_ilp.solve_max
        #info("WCET(#{wcet_for_obj}): #{cycles} cy (#{two_decimals(cycles * TIME_PER_CYCLE*1e6)} us)")
        statistics("WCEC/nodes/cycles",
                   "#{wcet_for_obj}" => cycles)
        statistics("WCEC/nodes/freqs",
                   "#{wcet_for_obj}" => freqs)

        wcet[wcet_for_obj] = [cycles, power_states.to_a]
      end
      t_wcrt_all2 = Time.now
      statistics("WCEC",
                 "solve wcets" => ((t_wcrt_all2-t_wcrt_all1)*1000).to_i)

      info ("Start WCEC Analysis")

      # make the actual WCEC analysis by using parameter wcet {abb => wcet}
      builder.build_wcec_analysis(gcfg, wcet, flowfacts)

      # Solve ILP
      t_ilp1 = Time.now
      begin
        cycles, freqs = builder.ilp.solve_max
      rescue Exception => ex
        warn("WCA: ILP failed: #{ex}") unless @options.disable_ipet_diagnosis
        cycles,freqs = -1, {}
      end
      t_ilp2 = Time.now
      statistics("WCEC",
                 "solve wcec" => ((t_ilp2-t_ilp1)*1000).to_i)

      # stats
      freqs.each do |variable, value|
        if builder.ilp.costs[variable] > 0 || /global/ =~ variable.to_s
          costs = value * builder.ilp.costs[variable]
          if @options.verbose
            info("WCEC: #{variable} => #{costs} mA*cy (freq=#{value})")
          end
          statistics("WCEC", variable => costs)
        end
      end


      report = TimingEntry.new(machine_entry, cycles, nil,
                               'level' => 'machinecode',
                               'origin' => @options.timing_output || 'platin')
      info "best WCEC bound: #{cycles} mA*cy"
      # 1e3 => uJ => mJ
      mJ = cycles * TIME_PER_CYCLE * 3.3
      info "best WCEC bound: #{mJ.round(3)} mJ (@3.3V)"

      # baseline (all always on):
      power_all_on = 0
      gcfg.device_list.each do |d|
        #if gcfg.device_list.member?(d['index'])
        power_all_on += d['energy_stay_on']
        #end
      end
      baseline_energy = 0

      response_time = freqs[builder.gcfg_model.wcet_variable]
      # max_costs_mJ = response_time * power_all_on * TIME_PER_CYCLE * 3.3
      # baseline_energy += max_costs_mJ
      # info "baseline WCEC: #{baseline_energy.round(3)} mJ (response time: #{response_time} cy)"

      statistics("WCEC",
                 "response_time" => response_time) if @options.stats

      statistics("WCEC",
                 "flowfacts" => flowfacts.length,
                 "ipet variables" => builder.ilp.num_variables,
                 "ipet constraints" => builder.ilp.constraints.length) if @options.stats

      statistics("WCEC",
                 "wcec" => cycles,
                 "max_power" => power_all_on) if @options.stats


      return report
    else # @options.wcec == false
      builder.build_gcfg(gcfg, flowfacts) do |edge|
        edge_cost(edge)
      end


      # run cache analyses
      # FIXME
      ca = CacheAnalysis.new(builder.refinement['machinecode'], @pml, @options)
      #ca.analyze(entry['machinecode'], builder)

      # END: remove me soon

      statistics("WCA",
                 "flowfacts" => flowfacts.length,
                 "ipet variables" => builder.ilp.num_variables,
                 "ipet constraints" => builder.ilp.constraints.length) if @options.stats

      # Solve ILP
      begin
        cycles, freqs = builder.ilp.solve_max
      rescue Exception => ex
        warn("WCA: ILP failed: #{ex}") unless @options.disable_ipet_diagnosis
        cycles,freqs = -1, {}
      end
    end

    if @options.visualize_ilp
      run_visualization_server(builder.ilp, @options, freqs)
    end

    # report result
    profile = Profile.new([])
    report = TimingEntry.new(machine_entry, cycles, profile,
                             'level' => 'machinecode', 'origin' => @options.timing_output || 'platin')

    # collect edge timings
    edgefreqs, edgecosts, totalcosts = {}, Hash.new(0), Hash.new(0)
    freqs.each { |v,freq|
      edgecost = builder.ilp.get_cost(v)
      freq = freq.to_i
      if edgecost > 0 || (v.kind_of?(IPETEdge) && v.cfg_edge?)

        next if v.kind_of?(Instruction)         # Stack-Cache Cost
        next if v.kind_of?(IPETEdgeSCA)         # Stack-Cache Cost (graph-based)
        ref = nil
        if v.kind_of?(IPETEdge)
           if v.level != :gcfg
            die("ILP cost: source is not a block") unless v.source.kind_of?(Block)
            die("ILP cost: target is not a block") unless v.target == :exit || v.target.kind_of?(Block)
            ref = ContextRef.new(v.cfg_edge, Context.empty)
            edgefreqs[ref] = freq
          else
            ref = ContextRef.new(v.gcfg_edge, Context.empty)
            edgefreqs[ref] = freq
          end
        elsif v.kind_of?(MemoryEdge)
          ref = ContextRef.new(v.edgeref, Context.empty)
        end
        edgecosts[ref] += edgecost
        totalcosts[ref] += edgecost*freq
      end
    }
    edgecosts.each { |ref, edgecost|
      unless edgefreqs.include?(ref)
        warn("edge cost (#{ref} -> #{edgecost}), but no corresponding IPETEdge variable")
        next
      end
      edgefreq = edgefreqs[ref]
      profile.add(ProfileEntry.new(ref, edgecost, edgefreqs[ref], totalcosts[ref]))
    }
    ca.summarize(@options, freqs, Hash[freqs.map{ |v,freq| [v,freq * builder.ilp.get_cost(v)] }], report)

    def grouped_report_by(ilp, freqs, key, print_activations=true)
      groups = freqs.group_by { |v, freq|
        v.static_context(key) if v.kind_of?(IPETEdge)
      }

      groups.sort_by {|k,v| k.to_s}.map {|label, edges|
        activation_count = edges.select {|v, freq|
          v.is_entry_in_static_context(key) if v.kind_of?(IPETEdge)
        }.reduce(0) {|acc, n| acc + n[1]}

        combined_cost = edges.map {|v, freq| freq * ilp.get_cost(v) }.inject(0, :+)
        next if (combined_cost + activation_count) == 0

        yield (label ? label : "<unspecified>"), combined_cost, activation_count
      }
    end

    if @options.stats
      statistics("WCA", "cycles" => cycles)
      irqs, timers = 0, 0
      grouped_report_by(builder.ilp, freqs, 'function') do
        | label, cost, activation_count |
        irqs   = activation_count if label == 'irq_entry'
        timers = activation_count if label == 'timer_isr'
        if label =~ /^timing_/
          statistics("WCA", "functions" => {label=>activation_count})
        end
      end
      # Count alarm activations
      alarms = 0
      freqs.each { |v, freq|
        if v.to_s =~ /^GCFG:.*CheckAlarm.*(ActivateTask|SetEvent)/
          alarms += freq
        end
      }
      statistics("WCA",
                 "interrupt requests" => irqs,
                 "timer ticks" => timers,
                 "alarm activations" => alarms)

    end

    if @options.verbose
      puts "Cycles: #{cycles}"
      puts "Subtask Profile:"
      grouped_report_by(builder.ilp, freqs, 'subtask', false) do
        | label, cost, activation_count |
        printf "%42s:", label
        printf " %6d cycles", cost
        printf "\n"
      end
      puts "ABB Profile:"
      grouped_report_by(builder.ilp, freqs, 'abb') do
          | label, cost, activation_count |
        printf "%42s:", label
        printf " %6d cycles", cost
        printf " %4d activations", activation_count
        printf "\n"
      end
      puts "Function Profile:"
      grouped_report_by(builder.ilp, freqs, 'function') do
        | label, cost, activation_count |
        printf "%42s:", label
        printf " %6d cycles", cost
        printf " %4d activations", activation_count
        printf "\n"
      end
      if @options.verbosity_level > 1
        puts "\nEdge Profile:"
        freqs.sort_by { |v,freq| [v.to_s, freq] }.each { |v, freq|
          next if freq == 0
          printf "%4d cyc %4d freq  %s\n", freq * builder.ilp.get_cost(v), freq, v
        }
      end
    end
    report
  end
end

end # module PML
