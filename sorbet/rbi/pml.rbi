# typed: strong

class PML::PMLList
  # add_index is provided by the respective mixin, so we fake a function
  def add_index(item); end
  # The constructor has to be provided by the calling function, so we fake it here
  def initialize(items, pmldata = nil); end
end

module PML::PMLListGen
  # somehow, sorbet does not buy me that module_eval is in scope
  def module_eval(code, file = nil, line = nil); end
  # PMLListGen is used as a mixin, so fake the class accessor from dynamic scope
  def class; end
end