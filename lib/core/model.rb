# Peaches is the expression language used for evaluating annotations over a
# given model.

require 'core/programinfo'
require 'core/peaches'

module PML

class PMLMutation
  def mutate(pml)
    pml
  end
end

class PMLMachineCalleeMutation < PMLMutation
  def initialize(instruction, callees)
    @level       = instruction.function.level
    @instruction = instruction.qname
    @callees     = callees
    @old         = nil
  end

  def mutate(pml)
    # We cannot use the acutal instruction here, as later duplication might
    # change the underlying object. Therefore, we have to navigate the
    # datastructure manually in this method from the pml-root object...
    instr = resolve(pml)
    @old  = instr.callees
    instr.update_callees(@callees)
    pml
  end

  def repair(pml)
    instr = resolve(pml)
    assert("Can only undo if the mutation was applied before") { @old != nil }
    instr.update_callees(@old)
    @old = nil
    pml
  end

  def resolve(pml)
    funs = pml.functions_for_level(@level)
    Instruction.from_qname(funs, @instruction)
  end

  private :resolve
end

class Model
  attr_reader :context

  def initialize(context = Peaches::Context.new)
    @context = context
    @stack = []
  end

  def self.from_file(filename)
    prog    = File.read(filename)
    context = Peaches::build_context(prog)
    self.new(context)
  end

  def evaluate(pml, modelfacts)
    # Undo information
    done = []
    @stack << done

    facts = modelfacts.map { |fact| fact.to_fact(pml, self) }.compact

    facts.select{ |f| f.kind_of?(FlowFact) }.each do |ff|
      pml.flowfacts.add(ff)
      done << ff
    end
    facts.select{ |f| f.kind_of?(ValueFact) }.each do |vf|
      pml.flowfacts.add(ff)
      done << vf
    end
    facts.select{ |f| f.kind_of?(PMLMutation) }.each do |mt|
      mt.mutate(pml)
      done << mt
    end

    self
  end

  # This is actually a whole lot more fragile than ideal as PMLMutations do mutate
  # the machine_functions, and those mutations actually persist across
  # pml.with_temporary_sections([:machine_functions]). Therefore we have to
  # explicitly undo them. Fragile as hell.
  def repair(pml)
    facts = @stack.pop

    assert ("Trying to repair a pml without undo information") { facts != nil }

    # We have to apply the undo steps in the inverse order of the "mutate"
    # operations, if two mutations target the same pieces of information, or we
    # risk corrupting the original data (We still do that anyways, if a
    # mutation has an implementation flaw)
    facts = facts.reverse

    # Valuefacts and Flowfacts are handled by "with_temporary_sections"
    facts.select{ |f| f.kind_of?(PMLMutation) }.each do |mt|
      mt.repair(pml)
    end
  end
end

end # module PML
