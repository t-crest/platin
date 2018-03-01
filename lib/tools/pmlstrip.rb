#!/usr/bin/env ruby
#
# platin tool set
#

require 'platin'
require 'tools/extract-symbols'
include PML

if __FILE__ == $PROGRAM_NAME
  SYNOPSIS = <<-EOF
  Remove any user annotations from the PML database.
  EOF
  options, args = PML::optparse([], "", SYNOPSIS) do |opts|
    opts.needs_pml
    opts.writes_pml
  end

  pml = PMLDoc.from_files(options.input, options)

  pml.flowfacts.delete_if do |ff|
    ff.origin == "user.bc"
  end

  pml.data['flowfacts'] = pml.flowfacts.to_pml

  pml.dump_to_file(options.output)
end

# origin:          user.bc
