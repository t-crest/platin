#
# PLATIN tool set
#
# Bindings to lp_solve
#
require 'platin'
include PML
begin
  require 'rubygems'
  require "lpsolve"
rescue Exception => details
  $stderr.puts "Failed to load library lpsolve"
  $stderr.puts "  ==> aptitude install liblpsolve55-dev [Debian/Ubuntu]"
  $stderr.puts "  ==> llvm/tools/platin/install.sh -i INSTALL_DIR [installs gems again]"
  $stderr.puts "Failed to load required ruby libraries: #{details}"
  exit 1
end

# Simple interface to lp_solve
class LpSolveILP < ILP
  # Tolarable floating point error in objective
  EPS = 0.0001
  def initialize(options = nil)
    super(options)
    @eps = EPS
  end

  # run solver to find maximum cost
  def solve_max
    # create LP problem (maximize)
    lp = create_lp
    lp.set_maxim
    # set objective and add constraints
    lp.set_add_rowmode(true)
    set_objective(lp)
    add_linear_constraints(lp)
    # solve
    lp.set_add_rowmode(false)
    lp.print_lp if options.lp_debug
    lp.write_lp(options.write_lp) if options.write_lp
    lp.set_verbose(0)

    debug(options, :ilp) { dump(DebugIO.new) }
    start = Time.now
    r = lp.solve
    @solvertime += (Time.now - start)

    # read solution
    lp.print_solution(-1) if options.lp_debug
    obj = lp.objective
    freqmap = extract_frequencies(lp.get_variables)
    unbounded = nil
    if r == LPSolve::INFEASIBLE
      diagnose_infeasible(lp_solve_error_msg(r), freqmap) if @do_diagnose
    elsif r == LPSolve::UNBOUNDED
      unbounded, freqmap = diagnose_unbounded(lp_solve_error_msg(r), freqmap) if @do_diagnose
    end
    raise ILPSolverException.new(lp_solve_error(r), obj.round, freqmap, unbounded) unless r == 0
    if (obj - obj.round.to_f).abs > @eps
      raise Exception, "Untolerable floating point inaccuracy > #{EPS} in objective #{obj}"
    end

    [obj.round, freqmap, unbounded]
  end

private

  # Remove characters from constraint names that are not allowed in an .lp file
  def cleanup_name(name)
    name.gsub(/[@: \/()->]/, "_")
  end

  # create an LP with variables
  def create_lp
    lp = LPSolve.new(0, variables.size)
    variables.each do |v|
      ix = index(v)
      lp.set_col_name(ix, "v_#{ix}")
      lp.set_int(ix, true)
    end
    lp
  end

  # set LP ovjective
  def set_objective(lp)
    lp.set_obj_fnex(@costs.map { |v,c| [index(v),c] })
  end

  # add LP constraints
  def add_linear_constraints(lp)
    @constraints.each do |constr|
      v =  lp.add_constraintex(cleanup_name(constr.name), constr.lhs.to_a, lpsolve_op(constr.op), constr.rhs)
      unless v
        dump($stderr)
        die("constraintex #{constr} failed with return value #{v.inspect}")
      end
    end
  end

  # extract solution vector
  def extract_frequencies(fs)
    vmap = {}
    fs.each_with_index do |v, ix|
      vmap[@variables[ix]] = v if v != 0
    end
    vmap
  end

  # lp-solve comparsion operators
  def lpsolve_op(op)
    case op
    when "equal"
      LPSolve::EQ
    when "less-equal"
      LPSolve::LE
    when "greater-equal"
      LPSolve::GE
    else
      internal_error("Unsupported comparison operator #{op}")
    end
  end

  def lp_solve_error_msg(r)
    case r
    when LPSolve::NOMEMORY
      "NOMEMORY"
    when LPSolve::SUBOPTIMAL
      "SUBOPTIMAL"
    when LPSolve::INFEASIBLE
      "INFEASIBLE"
    when LPSolve::UNBOUNDED
      "UNBOUNDED"
    else
      "ERROR_#{r}"
    end
  end

  def lp_solve_error(r)
    "LPSolver Error: #{lp_solve_error_msg(r)} (E#{r})"
  end
end
