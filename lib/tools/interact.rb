# typed: ignore
require 'platin'
include PML

require 'readline'
require 'shellwords'
require 'json'
require 'tempfile'

require 'tools/wcet'
require 'tools/visualisationserver'
require 'English'

# On the code design
#
# There are tokens, which provide a completion interface for various kinds of objects
# They all implement a "complete" function that receives the relevant prefix
#
# There are Commands. For completion purposes, they return a list of tokens in the
# get_tokens function, which are used by readline for the actual completion.
# They further provide a '.run' method that executes the actual function
#
# There is the dispatcher, which stores the subcommands and dispatches these commands
# to their respective implementations
#
# There is a REPLContext class, which stores global information such as options, debug mode
# or the parsed PMLDoc
#
# At the bottom, there is a main loop, that hooks this machinery into Readline

# Token implementations {{{
class Token
  def complete(_prefix)
    raise ArgumentError, 'This should be overwritten in the child class'
  end
end

class ListToken < Token
  def get_list
    raise ArgumentError 'This should be overwritten in the child class'
  end

  def complete(prefix)
    get_list.grep(/^#{Regexp.escape(prefix)}/i)
  end
end

class MachineFunctionToken < ListToken
  def get_list
    REPLContext.instance.pml.machine_functions.keys_label
  end
end

class CommandToken < ListToken
  def get_list
    Dispatcher.instance.get_commands
  end
end

class BooleanToken < ListToken
  TRUE  = ["true", "yes", "y", "on"]
  FALSE = ["false", "no", "n", "off"]

  def get_list
    TRUE + FALSE
  end

  def coerce(arg)
    return true unless TRUE.grep(arg).empty?
    return false unless FALSE.grep(arg).empty?
    raise ArgumentError, "Not a boolean option #{arg}"
  end
end

class TypeToken < ListToken
  TYPES = ['string', 'int', 'bool']

  def get_list
    TYPES + TYPES.map { |m| '[' + m + ']' }
  end

  def coerce(input)
    list = false
    if input =~ /^\[(.*)\]$/
      list = true
      input = $1
    end

    raise ArgumentError, "No such type: #{input}" if TYPES.grep(input).empty?

    lambda { |args|
      conv = args.map do |x|
        case input
        when 'string'
          x
        when 'int'
          Integer(x)
        when 'bool'
          BooleanToken.new.coerce(x)
        else
          raise ArgumentError, "No such type: #{input}"
        end
      end
      if !list
        if conv.length == 1
          return conv[0]
        else
          raise ArgumentError, "Illegal number of parameters, maybe qouting is required"
        end
      else
        return conv
      end
    }
  end
end

class OperationToken < ListToken
  OPS = ['=', '<<']

  def get_list
    OPS
  end

  def coerce(tok)
    raise ArgumentError, "Unknown op: #{tok}" if OPS.grep(tok).empty?
    tok
  end
end

class OptionMemberToken < ListToken
  def get_list
    REPLContext.instance.options.to_h.keys
  end
end

class ProgramPointToken < ListToken
  def qnameblocks(pmllist)
    pmllist.map { |f| f.blocks.list }.compact.flatten.map { |b| b.qname }.flatten
  end

  def qnameinstructions(pmllist)
    pmllist.map { |f| f.blocks.list }.compact.flatten.map { |b| b.instructions.list }.compact.flatten.map { |i| i.qname }
  end

  def get_list
    qnameblocks(REPLContext.instance.pml.bitcode_functions) +
      qnameblocks(REPLContext.instance.pml.machine_functions) +
      qnameinstructions(REPLContext.instance.pml.machine_functions)
    # Skipped for performance reasons
    # + qnameinstructions(REPLContext.instance.pml.bitcode_functions)
  end

  def squelch(exception_to_ignore = StandardError, default_value = nil)
    yield
  rescue Exception => e
    raise unless e.is_a?(exception_to_ignore)
    default_value
  end

  def coerce(qname)
    pp = nil
    squelch { pp   = Block.from_qname(REPLContext.instance.pml.bitcode_functions, qname) }
    squelch { pp ||= Block.from_qname(REPLContext.instance.pml.machine_functions, qname) }
    squelch { pp ||= Instruction.from_qname(REPLContext.instance.pml.bitcode_functions, qname) }
    squelch { pp ||= Instruction.from_qname(REPLContext.instance.pml.machine_functions, qname) }
    raise ArgumentError, "Unknown programpoint: #{qname}" if pp.nil?
    pp
  end
end

class PlatinaToken < ListToken
  ANNOTATIONS = ['guard', 'lbound', 'callee']

  def get_list
    ANNOTATIONS
  end

  def coerce(tok)
    raise ArgumentError, "Unknown annotation type: #{tok}" if ANNOTATIONS.grep(tok).empty?
    tok
  end
end

class EditCommandToken < ListToken
  EDITTARGET = ['modelfacts', 'model']

  def get_list
    EDITTARGET
  end

  def coerce(tok)
    raise ArgumentError, "Unknown annotation type: #{tok}" if EDITTARGET.grep(tok).empty?
    tok.to_sym
  end
end

class VisualizeInfoToken < ListToken
  VISUALISATIONS = ['ilp', 'callgraph']

  def get_list
    VISUALISATIONS
  end

  def coerce(tok)
    raise ArgumentError, "Unknown annotation type: #{tok}" if VISUALISATIONS.grep(tok).empty?
    tok.to_sym
  end
end

class DiffCommandToken < ListToken
  OPS = ['annotations']

  def get_list
    OPS
  end

  def coerce(tok)
    raise ArgumentError, "Unknown op: #{tok}" if OPS.grep(tok).empty?
    tok.to_sym
  end
end

# }}}

# Command Implementations {{{
class Command
  def run(_args)
    raise 'This should be overwritten in the child class'
  end

  def help(_long = false)
    raise "This should be overwritten in the child class"
  end

  def get_tokens
    raise 'This should be overwritten in the child class'
  end
end

class HelpCommand < Command
  def initialize
    @tokens = [CommandToken.new]
  end

  def help(long = false)
    out = "Display help"
    if long
      out << <<-'EOF'

  help [command]

  Displays an general help message or specific help for  a command
      EOF
    end
    out
  end

  def run(args)
    case args.length
    when 0
      help = []
      Dispatcher.instance.get_commands_map.each do |k,v|
        help << "  " + k.ljust(20) + " - " + v.help(false)
      end
      puts help.join("\n")
    when 1
      puts "  " + Dispatcher.instance[args[0]].help(true)
    else
      puts "  " + help(true)
    end
  end

  def get_tokens
    @tokens
  end
end

class DebugCommand < Command
  def initialize
    @tokens = [BooleanToken.new]
  end

  def help(long = false)
    out = "Enable/Disable debugging"
    if long
      out << <<-'EOF'

  debug [<on|off>]

  If on or off is omitted, drops the user into a pry shell
      EOF
    end
    out
  end

  def run(args)
    case args.length
    when 0
      # pry will pollute our history
      hist = Readline::HISTORY.length
      binding.pry
      # So we restore it
      Readline::HISTORY.pop while Readline::HISTORY.length != hist
      Readline.completion_proc = REPLContext.instance.completor
    when 1
      REPLContext.instance.debug = @tokens[0].coerce(args[0])
    else
      raise ArgumentError, "Usage: debug (on|off)"
    end
  end

  def get_tokens
    @tokens
  end
end

class WCETCommand < Command
  def initialize
    @tokens = [MachineFunctionToken.new]
  end

  def help(long = false)
    out = "Run a wcet analysis for an entrypoint"
    if long
      out << <<-'EOF'

  wcet <symbol>
      EOF
    end
    out
  end

  def run(args)
    raise ArgumentError, "Usage: wcet <symbolname>" if args.length <= 0

    puts "Analysing #{args[0]}"
    opts, pml = REPLContext.instance.options, REPLContext.instance.pml
    # Pass the "parameter
    opts.analysis_entry = args[0]

    WcetTool.run(pml, opts)
    # Record the result
    pml.timing.each do |t|
      (REPLContext.instance.timing[args[0]] ||= []) << t
    end

    pml.timing.clear!
  end

  def get_tokens
    @tokens
  end
end

class VisualizeCommand < Command
  def initialize
    @tokens = [VisualizeInfoToken.new, MachineFunctionToken.new]
  end

  def help(long = false)
    out = "Visualize some aspects (ILP, ...) starting from a given entrypoint"
    if long
      out << <<-'EOF'

  visualize (ilp) <symbol>
      EOF
    end
    out
  end

  def run(args)
    raise ArgumentError, "Usage: visualize (ilp) <symbolname>" if args.length != 2

    puts "Visualizing #{args[0]} #{args[1]}"
    opts, pml = REPLContext.instance.options, REPLContext.instance.pml
    # Pass the symbol of interest
    opts.analysis_entry = args[1]

    case @tokens[0].coerce(args[0])
    when :ilp
      # Save the visualisation-flag
      visualize_ilp_bak = opts.visualize_ilp
      debug_type_bak = opts.debug_type
      # Hacky: Because return-info of timing infos travels via pml and we do not
      #        really want our visualisation in there, we pass in a hash by
      #        reference and take output that way... Lovely.
      visualisation = {}
      opts.visualize_ilp = visualisation
      opts.debug_type    = [:ilp]

      WcetTool.run(pml, opts)
      pml.timing.clear!

      ilpdata = {
        'ilp.svg' => {
          'content_type' => 'image/svg+xml',
          'data' => visualisation[:ilp][:svg],
        },
        'ilp.dot' => {
          'content_type' => 'text/vnd.graphviz',
          'data' => visualisation[:ilp][:dot],
        },
        'constraints.json' => {
          'content_type' => 'application/json',
          'data' => JSON.generate(visualisation[:ilp][:constraints]),
        },
        'srchints.json' => {
          'content_type' => 'application/json',
          'data' => JSON.generate(visualisation[:ilp][:srchints]),
        },
      }

      assetdir = File.realpath(File.join(__dir__, '..', '..', 'assets'))
      assert("Not a directory #{assetdir}") { File.directory? assetdir }


      puts "Prohibit_directory_traversal: #{opts.prohibit_directory_traversal }"

      server = VisualisationServer::Server.new( \
        :ilp, \
        { \
          entrypoint: opts.analysis_entry \
          , srcroot: opts.source_path  \
          , assets: assetdir \
          , data: ilpdata  \
          , directory_traversal: (opts.prohibit_directory_traversal ? :strict : :loose) \
        }, \
        BindAddress: opts.server_bind_addr, \
        Port: opts.server_port \
      )

      # Restore the old value
      opts.visualize_ilp = visualize_ilp_bak
      opts.debug_type    = debug_type_bak
    when :callgraph
      entry_label = args[1]

      # We want to efficiently build an callgraph (without invoking scopegraphs)
      # Based on analysis/wca.rb
      machine_entry = pml.machine_functions.by_label(entry_label)
      raise ArgumentError, "No machine function to label #{machine_entry}" if machine_entry.nil?
      bitcode_entry = pml.bitcode_functions.by_name(entry_label)
      # rubocop:disable Layout/MultilineHashBraceLayout
      entry = { 'machinecode' => machine_entry,
                'bitcode' => bitcode_entry,
              }
      # rubocop:enable Layout/MultilineHashBraceLayout

      graph = nil

      pml.with_temporary_sections([:flowfacts, :valuefacts]) do
        if opts.modelfile
          model = Model.from_file(opts.modelfile)
        else
          model = Model.new
        end
        begin
          model.evaluate(pml, pml.modelfacts)
          builder = IPETBuilder.new(pml, opts, nil)

          # flow facts
          flowfacts = pml.flowfacts.filter(pml,
                                           opts.flow_fact_selection,
                                           opts.flow_fact_srcs,
                                           ["machinecode"],
                                           true)

          # Based on analysis/ipet.rb
          builder.build_refinement(entry, flowfacts)
          mf_functions = builder.get_functions_reachable_from_function(entry['machinecode'])
          mc_model = builder.mc_model
          pcgv = PlainCallGraphVisualizer.new(entry_label, mf_functions, mc_model)
          graph = pcgv.visualize_callgraph
        ensure
          # ALWAYS undo mutations, even in case of errors (such as unresolved
          # calls)
          model.repair(pml)
        end
      end

      data = {
        'callgraph.svg' => {
          'content_type' => 'image/svg+xml',
          'data' => graph.output(svg: String),
        },
      }
      server = VisualisationServer::Server.new( \
        :callgraph, \
        { \
          data: data  \
        }, \
        BindAddress: opts.server_bind_addr, \
        Port: opts.server_port \
      )
    else
      assert("Unexpected visualisation type: :#{args[0]}") { false }
    end

    puts "Starting server, use <Ctrl-C> to return to REPL"
    puts "Listening at http://#{opts.server_bind_addr}:#{opts.server_port}/"
    server.start
  end

  def get_tokens
    @tokens
  end
end

class ModelFactCommand < Command
  def initialize
    @modeltokens = [ProgramPointToken.new, PlatinaToken.new]
  end

  def build_modelfact(pparg, typearg, exprarg)
    pp    = @modeltokens[0].coerce(pparg)
    type  = @modeltokens[1].coerce(typearg)
    expr  = exprarg

    # Yeah, lets fake a pml-entry
    pml = {}
    pml['program-point'] = pp.to_pml_ref
    pml['level'] = pp.function.level
    pml['origin'] = case pml['level']
                    when 'bitcode'
                      'platina.bc'
                    when 'machinecode'
                      'platina'
                    else
                      raise ArgumentError, "ProgramPoint #{pp} has level #{pml['level']}, " \
                                           "which is unsupported"
                    end

    pml['type']        = type
    pml['expression']  = expr

    modelfact = ModelFact.from_pml(REPLContext.instance.pml, pml)
    modelfact
  end

  def get_model_tokens
    @modeltokens
  end
end

module FindEditor
  def get_edit_command(ft = nil)
    editor = []
    if ENV['EDITOR']
      editor << ENV['EDITOR']
    else
      # use default
      editor << 'vim'
    end

    unless ft.nil?
      if editor.last.end_with?('vim')
        editor << '-c'
        editor << "set ft=#{ft}"
      end
    end

    editor
  end
end

class EditCommand < ModelFactCommand
  include FindEditor

  def initialize
    super
    @tokens = [EditCommandToken.new]
  end

  def help(long = false)
    out = "Edit the current set of modelfacts"
    if long
      out << <<-'EOF'

  edit (modelfacts|model)
    modelfacts: Open $EDITOR on the current set of modelfacts
      EOF
    end
    out
  end

  def ask_retry(failed)
    # Parsing failed: Ask if user wants to retry
    tokens = ['yes', 'abort']
    Readline.completion_proc = proc { |s| tokens.grep(/^#{Regexp.escape(s)}/) }
    doretry = nil

    loop do
      STDERR.puts "Parsing failed for line #{failed[0]}: #{failed[1]}"
      input = Readline.readline("Retry? [yes/abort] ").squeeze(" ").strip
      doretry = true  if input == "yes"
      doretry = false if input == "abort"
      break unless doretry.nil?
    end

    Readline.completion_proc = REPLContext.instance.completor
    doretry
  end

  def run(args)
    raise ArgumentError, "Usage: edit (modelfacts)" if args.length != 1

    opts, pml = REPLContext.instance.options, REPLContext.instance.pml

    case @tokens[0].coerce(args[0])
    when :modelfacts
      file = Tempfile.new(['modelfacts', '.platina'])
      lines = pml.modelfacts.map do |a|
        a.ppref.programpoint.qname + " " + a.type + " \"" + a.expr + "\""
      end
      file.write(lines.join("\n"))
      file.flush

      # Construction might be slow -> cache if hash matches ("read only access")
      pristineSHA256 = Digest::SHA256.file file.path

      facts  = nil
      failed = nil
      loop do
        editor = get_edit_command('platina') + [file.path]
        system *editor

        # Check if cache matches
        newSHA256 = Digest::SHA256.file file.path
        return if pristineSHA256 == newSHA256

        # File has changed => reparse
        file.close(false)
        file.open
        input = file.read.lines

        failed = nil
        facts = ModelFactList.new([])

        # Try to build modelfacts from input
        input.each_with_index do |line, i|
          components = line.shellsplit
          if components.length != 3
            failed = [i, line]
            break
          end
          begin
            mf = build_modelfact(components[0], components[1], components[2])
            facts.add(mf)
          rescue ArgumentError => ae
            puts ae
            failed = [i, line]
            break
          end
        end

        # All was well
        break if failed.nil?

        # Check whether the user wants to fix their error
        break unless ask_retry(failed)
      end

      file.close
      file.unlink

      REPLContext.instance.pml.modelfacts = facts unless failed
    when :model
      if opts.modelfile && File.readable_real?(opts.modelfile)
        editor = get_edit_command('platinmodel') + [opts.modelfile]
        system *editor
      else
        STDERR.puts "Cannot find or read file '#{opts.modelfile}'. " \
                    "Please update 'opts.modelfile' accordingly"
      end
    else
      raise ArgumentError, "Usage: edit (modelfacts)"
    end
  end

  def get_tokens
    @tokens
  end
end

class AnnotateCommand < ModelFactCommand
  def help(long = false)
    out = "Interactivly annotate modelfacts"
    if long
      out << <<-'EOF'

  annotate <block> (guard|lbound|callee) "expr"
    Please note that guard and lbound target bitcode blocks, while callee
    annotations are only available on MC level
      EOF
    end
    out
  end

  def run(args)
    raise ArgumentError, "Usage: annotate <block> (guard|lbound|callee) \"expr\"" if args.length != 3

    modelfact = build_modelfact(args[0], args[1], args[2])
    REPLContext.instance.pml.modelfacts.add(modelfact)
  end

  def get_tokens
    get_model_tokens
  end
end

class DiffCommand < Command
  def initialize
    @tokens = [DiffCommandToken.new]
  end

  def help(long = false)
    out = "List changed modelfacts of this analysis"
    if long
      out << <<-'EOF'

  diff annotations
    List the annotations that were passed interactively
      EOF
    end
    out
  end

  class DiffEntry
    attr_reader :op, :diff
    def initialize(op, diff)
      @op, @diff = op, diff
    end

    def emit(colorize = false)
      out = ""
      if colorize
        case op
        when :+
          out << "\e[32m" # green
        when :-
          out << "\e[31m" # red
        end
      end

      parts = diff.split(' ', 2)

      out << "#{parts[0]} #{op} #{parts[1]}"

      if colorize
        out << "\e[0m" # reset color
      end

      out
    end

    def <=>(other)
      res = diff <=> other.diff
      return res if res != 0
      return res if op == other.op
      return -1 if op == :-
      1
    end
  end

  def diff_annotations(colorize = false)
    old = REPLContext.instance.initial_modelfacts
    cur = REPLContext.instance.pml.modelfacts.to_set

    add = cur - old
    del = old - cur

    add.map! { |mf| DiffEntry.new(:+, mf.to_source) }
    del.map! { |mf| DiffEntry.new(:-, mf.to_source) }

    diffs = add.to_a + del.to_a
    diffs.sort!

    diffs.map do |d|
      d.emit(colorize)
    end.join("\n")
  end

  def run(args)
    raise ArgumentError, "Usage: diff (annotations)" if args.length != 1

    case @tokens[0].coerce(args[0])
    when :annotations
      puts diff_annotations(true)
    else
      raise ArgumentError, "Usage: diff (annotations)"
    end
  end

  def get_tokens
    @tokens
  end
end

class ApplyCommand < DiffCommand
  include FindEditor

  def help(long = false)
    out = "Apply changes to the sourcecode interactively"
    if long
      out << <<-'EOF'

  apply annotations
    List the annotations that were passed interactively and open
    coresponding sourcefiles
      EOF
    end
    out
  end

  def run(args)
    raise ArgumentError, "Usage: apply (annotations)" if args.length != 1

    opts = REPLContext.instance.options

    case @tokens[0].coerce(args[0])
    when :annotations
      file = Tempfile.new('annotations-quickfix')
      file.write(diff_annotations(false))
      file.flush
      Dir.chdir(opts.source_path) do
        editor = ['vim', '-c', 'copen', '-q', file.path]
        system *editor
      end
      file.close
      file.unlink
    else
      raise ArgumentError, "Usage: apply (annotations)"
    end
  end
end

class ResultsCommand < Command
  def help(long = false)
    out = "Show past analysis results"
    if long
      out << <<-'EOF'

  results
      EOF
    end
    out
  end

  def run(args)
    raise ArgumentError, "Usage: results" unless args.empty?

    puts "Analysis results:"
    REPLContext.instance.timing.each do |k,v|
      puts " Analysis-entry: #{k}"
      v.each do |t|
        puts "   - source: #{t.origin}"
        puts "     cycles: #{t.cycles}"
      end
    end
  end

  def get_tokens
    []
  end
end

class GetCommand < Command
  def initialize
    @tokens = [OptionMemberToken.new]
  end

  def help(long = false)
    out = "Inspect a config option"
    if long
      out << <<-'EOF'

  get path.in.options
      EOF
    end
    out
  end

  def get_tokens
    @tokens
  end

  def run(args)
    raise ArgumentError, "Usage: get <optionfield>" if args.length != 1

    segments = args[0].split(/\./)
    element  = REPLContext.instance.options

    until segments.empty?
      key = segments.shift.to_sym
      unless element.to_h.key?(key)
        pp element[key]
        raise ArgumentError, "No such key: #{key}"
      end
      element = element[key]
    end
    pp element
  end
end

class SetCommand < Command
  def initialize
    @tokens = [TypeToken.new, OptionMemberToken.new, OperationToken.new]
  end

  def help(long = false)
    out = "Set a config option"
    if long
      out << <<-'EOF'

  set <typeinfo> path.in.options (=|<<) value

  As we have actually some degree of typing, we cast based on the typinfo provided.
  Based on the capabilites of the optparser, We support the types: int, bool, string
  A list can be created by surrounding them in brackets, i.e.: [bool] or [int]
      EOF
    end
    out
  end

  def get_tokens
    @tokens
  end

  def run(args)
    raise ArgumentError, "Usage: <[...]|int,string,bool> <option> <=|<<> [<input>]" if args.length < 3

    conv     = @tokens[0].coerce(args.shift)
    segments = args.shift.split(/\./)
    op       = @tokens[2].coerce(args.shift)

    # now convert op to data
    data     = conv.call(args)

    element  = REPLContext.instance.options

    until segments.empty?
      key = segments.shift.to_sym
      raise ArgumentError, "No such key: #{key}" unless element.to_h.key?(key)
      if segments.empty?
        case op
        when '='
          element[key] = data
        when '<<'
          element[key].concat(data)
        else
          raise ArgumentError, "Unknown Operation: #{op}"
        end
        return data
      end
    end

    raise ArgumentError, "Failed to locate segment"
  end
end
# }}}

class REPLContext
  attr_accessor :debug
  attr_accessor :options
  attr_accessor :pml
  attr_accessor :timing
  attr_accessor :completor
  attr_accessor :initial_modelfacts

  def initialize
    @debug              = false
    @options            = OpenStruct.new
    @pml                = nil
    @timing             = {}
    @completor          = nil
    @initial_modelfacts = nil
  end

  # rubocop:disable Style/ClassVars
  @@instance = REPLContext.new

  def self.instance
    @@instance
  end
  # rubocop:enable Style/ClassVars

  private_class_method :new
end

class Dispatcher
  def initialize
    @commands = {}
  end

  # rubocop:disable Style/ClassVars
  @@instance = Dispatcher.new

  def self.instance
    @@instance
  end
  # rubocop:enable Style/ClassVars

  def register(name, command)
    @commands[name] = command
  end

  def get_commands
    @commands.keys.sort
  end

  def get_commands_map
    @commands
  end

  def [](cmd)
    @commands[cmd]
  end

  def show_unresolved(unresolvedindirectcallexception)
    srcpath = REPLContext.instance.options.source_path
    return if srcpath.nil?

    src = unresolvedindirectcallexception.src_hint
    file, _, line = src.rpartition(':')

    filepath = File.join(srcpath, file)

    begin
      code = File.read(filepath).lines
      zeroline = Integer(line) - 1
      context = 10
      from = [0, zeroline - context].max
      to   = [code.length - 1, zeroline + context].min
      maxlength = to.to_s.length

      out = "Sourcecode around #{file}:#{line}\n"

      code.slice(from, to - from).each_with_index do |line, idx|
        if idx == context
          out << "=> "
        else
          out << "   "
        end
        out << format("%#{maxlength}d: ", (idx + from + 1))
        out << line
      end
      puts out
    rescue Exception => e
      # Silently ignore all errors
    end
  end

  def dispatch(input)
    args = []

    # Tokenize
    begin
      args = input.shellsplit
    rescue ArgumentError => arg
      STDERR.puts arg
      return
    end

    # Skip empty lines
    if    args.empty?
      return
    # Check if an command exists
    elsif !@commands.key?(args[0])
      STDERR.puts("No subcommand #{args[0]} registered")
      return
    end

    cmd = @commands[args.shift]

    # Unfortunately, Pry.rescue is reeeeaaalllly bad with closures/procs/blocks
    # Therefore, we have to duplicate the code *sigh*
    if REPLContext.instance.debug
      Pry.rescue do
        begin
          cmd.run(args)
        rescue UnresolvedIndirectCall => uic
          STDERR.puts(uic)
          show_unresolved(uic)
        rescue ArgumentError => arg
          STDERR.puts(arg)
          return
        end
      end
    else
      begin
        begin
          cmd.run(args)
        rescue UnresolvedIndirectCall => uic
          STDERR.puts(uic)
          show_unresolved(uic)
        rescue ArgumentError => arg
          STDERR.puts(arg)
          return
        end
      rescue Peaches::PeachesError => e
        STDERR.puts("Evaluating a peaches expression resulted in an error:")
        STDERR.puts("  #{e.class.name}: #{e}")
      rescue Exception => e
        STDERR.puts("Exeption: #{e}")
        STDERR.puts e.backtrace
      end
    end
  end

  def extend_input(input)
    sanity = 0
    args = []
    valid = false
    loop do
      begin
        args = input.shellsplit
        valid = true
      rescue ArgumentError
        input << '"'
        sanity += 1
      end
      # Extend only once
      break if valid || sanity > 1
    end
    raise ArgumentError, "Failed to extend input" unless valid
    args
  end

  def complete(input)
    args = []
    begin
      args = extend_input(input)
    rescue ArgumentError
      # Well, ignore it then
      return
    end

    # Which token has to be completed?
    tokenindex = args.length - 1

    # Detect if we have to start with a new token:
    tokenindex += 1 if input =~ /\s$/

    # Now the actual completion
    if tokenindex <= 0
      return CommandToken.new.complete(args[0] || "")
    else
      # Ok, so we are inside a command
      cmd = args.shift
      tokenindex -= 1

      # Do we know the command?
      return nil unless @commands.key?(cmd)

      # Do we know the token?
      tokens = @commands[cmd].get_tokens
      return nil if tokens.length <= tokenindex

      # The acutal completion
      return tokens[tokenindex].complete(args[tokenindex] || "")
    end
  end

  private_class_method :new
end

class InteractTool
  def self.add_options(opts)
    WcetTool.add_options(opts)
    options = opts.options
    options.source_path = "."
    opts.on('--source-path DIR', "directory for source code lookup") { |d| options.source_path = d }
    options.server_bind_addr = "127.0.0.1"
    opts.on('--server-bind-addr IP', "adress to bind to") { |ip| options.server_bind_addr = ip }
    options.server_port = "2142"
    opts.on('--server-port PORT', Integer, "Port number to bind to") { |p| options.server_port = p }
    options.prohibit_directory_traversal = true
    opts.on('--[no-]allow-directory-traversal', "(not) allow directory traversal", "true or false") { |dt| options.prohibit_directory_traversal = !dt }
  end
end

if __FILE__ == $PROGRAM_NAME
  synopsis = <<EOF
  platin interactive console
EOF

  # Argument handling:
  options, args = PML::optparse([], "", synopsis) do |opts|
    opts.needs_pml
    InteractTool.add_options(opts)
  end

  # --- SNIP: Verbatim copy from tools/wcet.rb ---
  unless which(options.a3)
    warn("Commercial a3 tools is not available; use --disable-ait to hide this warning") unless options.disable_ait
    options.disable_ait = true
    options.enable_wca = true
    options.combine_wca = false
  end
  if options.combine_wca && options.disable_ait
    warn("Use of a3 has been disabled, combined WCET analysis is not available")
    options.combine_wca = false
    options.enable_wca = true
  end
  if options.combine_wca && options.compute_criticalities
    # We could still do it using aiT, but it would be rather imprecise
    die("Computing criticalities is not possible in combined-WCA mode")
  end
  # --- /SNIP

  # Setup the execution context
  REPLContext.instance.pml                = PMLDoc.from_files(options.input, options)
  REPLContext.instance.options            = options
  # Cheating: otherwise we cannot set a nonexistant modelfile
  REPLContext.instance.options.modelfile ||= ""
  # For diff command
  REPLContext.instance.initial_modelfacts = REPLContext.instance.pml.modelfacts.to_set

  # Register repl commands
  Dispatcher.instance.register('help', HelpCommand.new)

  Dispatcher.instance.register('set', SetCommand.new)
  Dispatcher.instance.register('get', GetCommand.new)

  Dispatcher.instance.register('wcet',      WCETCommand.new)
  Dispatcher.instance.register('visualize', VisualizeCommand.new)
  Dispatcher.instance.register('results',  ResultsCommand.new)
  Dispatcher.instance.register('annotate', AnnotateCommand.new)
  Dispatcher.instance.register('diff',     DiffCommand.new)
  Dispatcher.instance.register('edit',     EditCommand.new)
  Dispatcher.instance.register('apply',    ApplyCommand.new)
  begin
    require 'pry-rescue'
    require 'pry-stack_explorer'
    Dispatcher.instance.register('debug', DebugCommand.new)
  rescue LoadError
    STDERR.puts("Failed to load pry-stack_explorer or pry-rescue. Debugging will be disabled")
  end

  # Setup completion
  #   We need it in REPLContext as debug.pry sets its on completor, so we have
  #   to restore it
  REPLContext.instance.completor = proc do |_s|
    Dispatcher.instance.complete(Readline.line_buffer.slice(0,Readline.point))
  end
  Readline.completion_proc = REPLContext.instance.completor

  # The main loop
  while (buf = Readline.readline("> ", true))
    Dispatcher.instance.dispatch(buf)
    STDOUT.flush
  end
end
