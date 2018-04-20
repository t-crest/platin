#
# PLATIN tool set
#
# Bindings for Gurobi
#
require 'platin'
include PML

require 'thwait'
require 'thread'
require 'pry'

# Simple interface to gurobi_cl
class GurobiILP < ILP
  # Tolarable floating point error in objective
  def initialize(options = nil)
    super(options)

    @lines_thread0 = []
    @backlock_idx0 = 0

    @lines_thread1 = []
    @backlock_idx1 = 0

    @lines_thread2 = []
    @backlock_idx2 = 0
  end
  # run solver to find maximum cost
  def solve_max
    # create LP problem (maximize)
    lp_name = options.write_lp
    lp_name = File.join(options.outdir, "model.lp") unless lp_name
    sol_name = File.join(options.outdir, "model.sol")
    lp = File.open(lp_name, "w")

    # set objective and add constraints
    add_objective(lp)
    add_linear_constraints(lp)
    add_variables(lp)

    lp.close

    # solve
    debug(options, :ilp) { self.dump(DebugIO.new) }
    start = Time.now
    err, sol_name = solve_lp(lp_name, sol_name)
    @solvertime += (Time.now - start)

    # Throw exception on error (after setting solvertime)
    if err
      gurobi_error(err)
    end

    # read solution
    sol = File.open(sol_name, "r")

    obj, freqmap = read_results(sol)

    # close temp files
    sol.close

    if obj.nil?
      gurobi_error("Could not read objective value from result file #{sol_name}")
    end
    if freqmap.length != @variables.length
      gurobi_error("Read #{freqmap.length} variables, expected #{@variables.length}")
    end

    [obj.round, freqmap ]
  end

  private
  # Remove characters from constraint names that are not allowed in an .lp file
  def cleanup_name(name)
    name.gsub(/[\@\: \/\(\)\-\>]/, "_")
  end
  def varname(vi)
    "v_#{vi}"
  end
  # create an LP with variables
  def add_variables(lp)
    lp.puts("Generals")
    @variables.each do |v|
      lp.print(" ", varname(index(v)))
    end
    lp.puts
    lp.puts("SOS")
    sos1.each { |name, sos|
      assert("Invalid SOS crardinatlity") {sos[1] == 1}
      lp.print("  #{name}: S1 :: ")
      sos[0].each { |v|
        lp.print("#{varname(index(v))}:1 ")
      }
      lp.puts
    }
    lp.puts("End")
  end
  # set LP ovjective
  def add_objective(lp)
    lp.puts("Maximize")
    @costs.each { |v,c| lp.print(" #{lp_term(c,index(v))}") }
    lp.puts
  end
  # add LP constraints
  def add_linear_constraints(lp)
    lp.puts("Subject To")
    @constraints.each do |constr|
      next if constr.bound?
      lp.puts(" #{cleanup_name(constr.name)}: #{lp_lhs(constr.lhs)} #{lp_op(constr.op)} #{constr.rhs}")
    end
    # We could put the bounds in as constraints, but bounds should be faster
    lp.puts("Bounds")

    # we are in big numeric trouble if we do not put any bounds at all
    maximum_count = 100000
    @variables.each do |v|
      lp.puts(" #{varname(index(v))} <= #{maximum_count}")
    end

    @constraints.each do |constr|
      # Bounds must have the form '[-1,1] x <= rhs'
      next unless constr.bound?
      # All integer variables are bounded to [0,inf] by default
      next if constr.non_negative_bound?
      v,c = constr.lhs.first
      lp.puts(" #{varname(v)} >= #{constr.rhs}") if c == -1
      lp.puts(" #{varname(v)} <= #{constr.rhs}") if c ==  1
    end
    lp.puts
  end
  # extract solution vector
  def read_results(sol)
    obj = nil
    vmap = {}
    sol.readlines.each { |line|
      if line =~ /# Objective value = ([0-9][0-9.+e]*)/
    # Need to convert to float first, otherwise very large results that are printed in exp format
    # are truncated to the first digit.
        obj = $1.to_f.to_i
      elsif line =~ /v_([0-9]*) ([0-9]*)/
        vmap[var_by_index($1.to_i)] = $2.to_i
      end
    }
    [obj, vmap]
  end
  def lp_term(c,vi)
    "#{c < 0 ? '-' : '+'} #{c.abs} #{varname(vi)}"
  end
  def lp_lhs(lhs)
    lhs.map { |vi,c| " #{lp_term(c,vi)}" }.join
  end
  # lp comparsion operators
  def lp_op(op)
    case op
    when "equal"
      "="
    when "less-equal"
      "<="
    when "greater-equal"
      ">="
    else
      internal_error("Unsupported comparison operator #{op}")
    end
  end

  def thread0(lp, sol)
    out = IO.popen("gurobi_cl MIPFocus=1 ResultFile=#{sol} #{lp}")
    @lines_thread0 = []
    backlock_idx0 = 0
    while line = out.gets do
      @lines_thread0.push(line)
      if @lines_thread0.length > 40 and @options.verbose
        while backlock_idx0 < @lines_thread0.length do
          puts(@lines_thread0[backlock_idx0])
          backlock_idx0 += 1
        end
      end
    end
    $queue << [@lines_thread0, sol]
    @lines_thread0
  end

  def thread1(lp, sol)
    out = IO.popen("gurobi_cl MIPFocus=2 ResultFile=#{sol} #{lp}")
    @lines_thread1 = []
    backlock_idx1 = 0
    while line = out.gets do
      @lines_thread1.push(line)
      if @lines_thread1.length > 40 and @options.verbose
        while backlock_idx1 < @lines_thread1.length do
          puts(@lines_thread1[backlock_idx1])
          backlock_idx1 += 1
        end
      end
    end
    $queue << [@lines_thread1, sol]
    @lines_thread1
  end

  def thread2(lp, sol)
    out = IO.popen("gurobi_cl MIPFocus=3 ResultFile=#{sol} #{lp}")
    @lines_thread2 = []
    backlock_idx2 = 0
    while line = out.gets do
      @lines_thread2.push(line)
      if @lines_thread2.length > 40 and @options.verbose
        while backlock_idx2 < @lines_thread2.length do
          puts(@lines_thread2[backlock_idx2])
          backlock_idx2 += 1
        end
      end
    end
    $queue << [@lines_thread2, sol]
    @lines_thread2
  end

  def solve_lp(lp, sol)
    lines = []
    # MIPFocus=1: focus on finding feasible solutions
    # MIPFocus=2: focus on proving optimality
    # MIPFocus=3: focus on improving the bound
    # (unused: MIPGap=0.03  => stop at 3% gap between incubent and best bound)
    # (unused: TimeLimit=600 => terminate after 600 seconds)
    #out = IO.popen("gurobi_cl MIPFocus=2 ResultFile=#{sol} #{lp}")
    #out = IO.popen("gurobi_cl Heuristics=0 Method=0 MIPFocus=2 ResultFile=#{sol} #{lp}")
    #out = IO.popen("gurobi_cl AggFill=1000 ResultFile=#{sol} #{lp}")
    #backlock_idx = 0
    #while line = out.gets do
      #lines.push(line)
      #if lines.length > 40 or @options.verbose
        #while backlock_idx < lines.length do
          #puts(lines[backlock_idx])
          #backlock_idx += 1
        #end
      #end
    #end

    $queue = Queue.new
    sol0 = "#{sol}_th0.sol"
    sol1 = "#{sol}_th1.sol"
    sol2 = "#{sol}_th2.sol"
    th0 = Thread.new { thread0(lp, sol0) }
    th1 = Thread.new { thread1(lp, sol1) }
    #th2 = Thread.new { thread2(lp, sol2) }

    (lines, sol) = $queue.pop
    sol_name = sol
    th0.kill
    th1.kill
    #th2.kill

    # Detect error messages
    if $? and $?.exitstatus > 0
      return "Gurobi terminated unexpectedly (#{$?.exitstatus})", sol_name 
    end

    lines.each do |line|
      if line =~ /Model is infeasible/ || line =~ /Model is unbounded/
        #while backlock_idx < lines.length do
          #puts(lines[backlock_idx])
          #backlock_idx += 1
        #end
        return line
      end
      return nil, sol_name if line =~ /Optimal solution found/
    end
    #nil # No error
    return nil, sol_name
  end
  def gurobi_error(msg)
    raise Exception.new("Gurobi Error: #{msg}")
  end
end
