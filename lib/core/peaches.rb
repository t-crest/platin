# Peaches is the expression language used for evaluating annotations over a
# given model.

require 'core/programinfo'

module PML

class Model
  def evaluate(pml, modelfacts)
    facts = modelfacts.map {|fact| fact.to_fact(pml, self)}.compact
    facts.select{|f| f.kind_of?(FlowFact)}.each do |ff|
      pml.flowfacts.add(ff)
    end
    facts.select{|f| f.kind_of?(ValueFact)}.each do |vf|
      pml.flowfacts.add(ff)
    end
  end
end

end # module PML
