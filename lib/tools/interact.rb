require 'platin'
include PML

require 'readline'
require 'shellwords'

require 'tools/wcet'

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
  def complete(prefix)
    raise ArgumentError, 'This should be overwritten in the child class'
  end
end

class ListToken < Token
  def get_list
    raise ArgumentError 'This should be overwritten in the child class'
  end
  def complete(prefix)
    return get_list().grep(/^#{Regexp.escape(prefix)}/i)
  end
end

class MachineFunctionToken < ListToken
  def get_list
    return REPLContext.instance.pml.machine_functions.keys_label
  end
end

class CommandToken < ListToken
  def get_list
    return Dispatcher.instance.get_commands()
  end
end

class BooleanToken < ListToken
  TRUE  = ["true", "yes", "y", "on"]
  FALSE = ["false", "no", "n", "off"]

  def get_list
    return TRUE + FALSE
  end

  def coerce(arg)
    return true if !TRUE.grep(arg).empty?
    return false if !FALSE.grep(arg).empty?
    raise ArgumentError, "Not a boolean option #{arg}"
  end
end

class TypeToken < ListToken
  TYPES = ['string', 'int', 'bool']

  def get_list
    return TYPES + TYPES.map {|m| '[' + m + ']'}
  end

  def coerce(input)
    list = false
    if input =~ /^\[(.*)\]$/
      list = true
      input = $1
    end

    if TYPES.grep(input).empty?
      raise ArgumentError, "No such type: #{input}"
    end

    return lambda { |args|
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
    return OPS
  end

  def coerce(tok)
    if OPS.grep(tok).empty?
      raise ArgumentError, "Unknown op: #{tok}"
    end
    return tok
  end
end

class OptionMemberToken < ListToken
  def get_list
    return REPLContext.instance.options.to_h.keys
  end
end

# }}}

# Command Implementations {{{
class Command
  def run(args)
    raise 'This should be overwritten in the child class'
  end

  def help(long = false)
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
      Dispatcher.instance.get_commands_map.each { |k,v|
        help << "  " + k.ljust(20) + " - " + v.help(false)
      }
      puts help.join("\n")
    when 1
      puts "  " + Dispatcher.instance[args[1]].help(true)
    else
      puts "  " + help(true)
    end
  end

  def get_tokens
    return @tokens
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
      while Readline::HISTORY.length != hist
        Readline::HISTORY.pop
      end
      Readline.completion_proc = REPLContext.instance.completor
    when 1
      REPLContext.instance.debug = @tokens[0].coerce(args[0])
    else
      raise ArgumentError, "Usage: debug (on|off)"
    end
  end

  def get_tokens
    return @tokens
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
    if args.length <= 0
      raise ArgumentError, "Usage: wcet <symbolname>"
    end

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
    return @tokens
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
    if args.length != 0
      raise ArgumentError, "Usage: results"
    end

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
    return []
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
    return @tokens
  end

  def run(args)
    if args.length != 1
      raise ArgumentError, "Usage: get <optionfield>"
    end

    segments = args[0].split(/\./)
    element  = REPLContext.instance.options

    while segments.length > 0
      key = segments.shift.to_sym
      if !element.to_h.has_key?(key)
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
    return @tokens
  end

  def run(args)
    if args.length < 3
      raise ArgumentError, "Usage: <[...]|int,string,bool> <option> <=|<<> [<input>]"
    end

    conv     = @tokens[0].coerce(args.shift)
    segments = args.shift.split(/\./)
    op       = @tokens[2].coerce(args.shift)

    # now convert op to data
    data     = conv.call(args)

    element  = REPLContext.instance.options

    while segments.length > 0
      key = segments.shift.to_sym
      if !element.to_h.has_key?(key)
        raise ArgumentError, "No such key: #{key}"
      end
      if segments.length == 0
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

  def initialize
    @debug     = false
    @options   = OpenStruct.new
    @pml       = nil
    @timing    = {}
    @completor = nil
  end

  @@instance = REPLContext.new

  def self.instance
    return @@instance
  end

  private_class_method :new
end

class Dispatcher
  def initialize
    @commands = {}
  end

  @@instance = Dispatcher.new

  def self.instance
    return @@instance
  end

  def register(name, command)
    @commands[name] = command
  end

  def get_commands()
    return @commands.keys.sort
  end

  def get_commands_map()
    return @commands
  end

  def [](cmd)
    return @commands[cmd]
  end

  def dispatch(input)
    args = []

    # Tokenize
    begin
      args = input.shellsplit
    rescue ArgumentError => arg
      STDERR.puts (arg)
      return
    end

    # Skip empty lines
    if    args.length == 0
      return
    # Check if an command exists
    elsif ! @commands.has_key?(args[0])
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
        rescue ArgumentError => arg
          STDERR.puts(arg)
          return
        end
      end
    else
      begin
        begin
          cmd.run(args)
        rescue ArgumentError => arg
          STDERR.puts(arg)
          return
        end
      rescue Exception => e
        STDERR.puts("Exeption: #{e}")
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
      break if valid || sanity > 1;
    end
    if !valid
      raise ArgumentError, "Failed to extend input"
    end
    return args
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
    tokenindex = args.length - 1;

    # Detect if we have to start with a new token:
    tokenindex += 1 if input =~ /\s$/

    # Now the actual completion
    if tokenindex <= 0
      return CommandToken.new.complete(args[0] || "")
    else
      # Ok, so we are inside a command
      cmd = args.shift
      tokenindex -= 1;

      # Do we know the command?
      return nil unless @commands.has_key?(cmd)

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
  def InteractTool.add_options(opts)
    WcetTool.add_options(opts)
  end
end

if __FILE__ == $0
  synopsis=<<EOF
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
  if options.combine_wca and options.disable_ait
    warn("Use of a3 has been disabled, combined WCET analysis is not available")
    options.combine_wca = false
    options.enable_wca = true
  end
  if options.combine_wca and options.compute_criticalities
    # We could still do it using aiT, but it would be rather imprecise
    die("Computing criticalities is not possible in combined-WCA mode")
  end
  # --- /SNIP

  # Setup the execution context
  REPLContext.instance.pml     = PMLDoc.from_files(options.input, options)
  REPLContext.instance.options = options


  # Register repl commands
  Dispatcher.instance.register('help', HelpCommand.new)

  Dispatcher.instance.register('set', SetCommand.new)
  Dispatcher.instance.register('get', GetCommand.new)

  Dispatcher.instance.register('wcet',    WCETCommand.new)
  Dispatcher.instance.register('results', ResultsCommand.new)
  begin
    require 'pry-rescue'
    require 'pry-stack_explorer'
    Dispatcher.instance.register('debug', DebugCommand.new)
  rescue LoadError
    STDERR.puts ("Failed to load pry-stack_explorer or pry-rescue. Debugging will be disabled")
  end

  # Setup completion
  #   We need it in REPLContext as debug.pry sets its on completor, so we have
  #   to restore it
  REPLContext.instance.completor = proc do |s|
    Dispatcher.instance.complete(Readline.line_buffer.slice(0,Readline.point))
  end
  Readline.completion_proc = REPLContext.instance.completor

  # The main loop
  while buf = Readline.readline("> ", true)
    Dispatcher.instance.dispatch(buf)
  end
end
