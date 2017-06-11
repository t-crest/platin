#!/usr/bin/env ruby

require 'rsec'
require 'pp'
require 'pry'

# Define AST-Nodes

## Peaches borrows it syntax heavily from Dhall and therefore haskell
#
# All symbols are actually final. To simplify facts, they can be considered as
# constant functions. The language strives to be total (as in total functional
# programming) and therefore to guarantee termination. To prohibit cross
# recursion, all declarations are therefore implicitly scoped and evaluated top
# down.
# Recursion as such is also illegal (past a set of basic recursive functions in
# the standard lib that are chosen to not break the totalness)
#
# For now, the type system consists of booleans and integers, but uses duck
# typing. This will be fixed in the future, once the featureset has been
# finalized. The plan is to use type inference (most likely HM), but this is not
# yet implemented

module Peaches

class PeachesError < StandardError
end

class PeachesTypeError < PeachesError
end

class PeachesBindingError < PeachesError
end

class PeachesArgumentError < PeachesError
end

class PeachesUnsupportedError < PeachesError
end

class PeachesInternalError < PeachesError
end

class Context
  # The difference between a Context and a Map is that a Context lets you have
  # multiple ordered occurrences of the same key and you can query for the nth
  # occurrence of a given key.
  class Entry
    attr_reader :level, :val
    def initialize(level, val)
      @level = level
      @val   = val
    end
  end

  def initialize()
    @level    = 0
    @bindings = {}
  end

  def enter_scope()
    @level += 1
  end

  def leave_scope()
    @level -= 1

    @bindings.each do |k,v|
      v.select! { |e| e.level <= @level }
    end
  end

  def insert(label, val)
    list  = (@bindings[label] ||= [])
    entry = Entry.new(@level, val)
    if (!list.empty?) && (list.last.level >= level)
      raise PeachesBindingError.new "Variable #{label} already bound at same scope #{level}"
    end
    list << entry
  end

  def lookup(label, index = :last)
    entry = nil
    list  = @bindings[label]
    if list.nil?
      raise PeachesBindingError.new "Unknown variable #{label}"
    end
    if index == :last
      entry = list.last
    else
      list.each {|e| if e.level == index then entry = e end}
    end
    if entry.nil?
      raise PeachesBindingError.new "No binding for variable #{label} on level #{level}"
    end
    entry.val
  end
end

class ASTNode
  MESS = "SYSTEM ERROR: method missing"

  # Typecheck a variable
  def evaluate(context)
    raise MESS
  end

  def to_s
    raise MESS
  end

  def inspect
    self.to_s
  end

  def to_bool
    raise PeachesTypeError.new "No known conversion from #{self.class.name} to boolean"
  end

  def to_num
    raise PeachesTypeError.new "No known conversion from #{self.class.name} to number"
  end

  def visit(visitor)
    visitor.visit self
  end
end # class ASTNode

class ASTDecl < ASTNode
  attr_reader :ident, :params, :expr

  def initialize(ident, params, expr)
    @ident  = ident
    @params = params
    @params ||= []
    @expr   = expr
  end

  def evaluate(context)
    ident = @ident.label
    if params.empty?
      # Performance optimization: calculate constants now
      expr = @expr.evaluate(context)
      rhs = ASTDecl.new(@ident, @params, expr)
    else
      rhs = self
    end

    # Binding the variable here mitigates recursion
    context.insert(ident, rhs)
  end

  def to_s
    "#{@ident} #{@params.join(' ')} = #{@expr}"
  end

  def visit(visitor)
    visitor.visit self
    @ident.visit visitor
    @params.each {|p| p.visit(visitor)}
    @expr.visit(visitor)
  end
end

class ASTProgram
  attr_reader :decls

  def initialize(decls)
    @decls = decls
  end

  def evaluate(context = Context.new)
    @decls.each do |decl|
      decl.evaluate(context)
    end
    context
  end

  def inspect
    to_s
  end

  def to_s
    @decls.join("\n")
  end

  def visit(visitor)
    visitor.visit self
    @decls.each do |d|
      d.visit visitor
    end

  end
end

class ASTLiteral < ASTNode
  attr_reader :value

  def initialize(value)
    @value = value
  end

  def evaluate(context)
    # Is already fully evaluated
    self
  end

  def to_s
    "#{@value}"
  end

  def visit(visitor)
    visitor.visit self
  end
end

class ASTValueLiteral < ASTLiteral
end

class ASTBoolLiteral < ASTValueLiteral
  def to_bool
    value
  end
end

class ASTNumberLiteral < ASTValueLiteral
  def to_num
    value
  end
end

class ASTSpecialLiteral < ASTLiteral
end

class ASTUndefinedLiteral < ASTSpecialLiteral
end

class ASTErrorLiteral < ASTSpecialLiteral
end

class ASTIdentifier < ASTNode
  attr_reader :label

  def initialize(label)
    @label = label
  end

  def evaluate(context)
    context.lookup(@label).evaluate(context)
  end

  def to_s
    "#{@label}"
  end

  def visit(visitor)
    visitor.visit self
  end
end

class ASTCall < ASTNode
  attr_reader :label, :args

  def initialize(label, args = [])
    @label = label
    @args = args
  end

  def evaluate(context)
    decl = context.lookup(@label)

    if decl.params.length != @args.length
      raise PeachesArgumentError.new "Argument number mismatch for #{self}"
    end

    context.enter_scope
    @args.each_with_index do |argument,idx|
      expr = argument.evaluate(context)
      paramdecl = ASTDecl.new(decl.params[idx], [], expr)
      context.insert(decl.params[idx].label, paramdecl)
    end

    res = decl.expr.evaluate(context)

    context.leave_scope

    res
  end

  def to_s
    "(#{@label} #{@args.map {|a| a.to_s}.join(' ')})"
  end

  def visit(visitor)
    visitor.visit self
    @args.each do |expr|
      expr.visit visitor
    end
  end
end

class ASTExpr < ASTNode
  def assert_full_eval(node, context, types)
    val = node.evaluate(context)
    if !val.is_a?(ASTValueLiteral)
      raise "Expression #{node} is not of a terminal value type: #{val}"
    end

    typecheck = types.map { |type|
      match = false
      case type
      when :boolean
        if val.is_a?(ASTBoolLiteral)
          match = true
        end
      when :number
        if val.is_a?(ASTNumberLiteral)
          match = true
        end
      else
        raise PeachesInternalError.new "Unknown type: #{type}"
      end
      match
    }.inject(false) { |x,y| x || y}

    if !typecheck
      raise PeachesTypeError.new "Expression #{node.class.name}:#{node} is no instance of #{types}"
    end

    val
  end
end

class ASTIf < ASTExpr
  attr_reader :cond, :if_expr, :else_expr
  def initialize(cond, if_expr, else_expr)
    @cond      = cond
    @if_expr   = if_expr
    @else_expr = else_expr
  end

  def evaluate(context)
    cond = assert_full_eval(@cond, context, [:boolean])
    if cond.to_bool
      return @if_expr.evaluate(context)
    else
      return @else_expr.evaluate(context)
    end
  end

  def to_s
    "if #{@cond} then #{if_expr} else #{else_expr}"
  end

  def visit(visitor)
    visitor.visit self
    @cond.visit visitor
    @if_expr.visit visitor
    @else_expr.visit visitor
  end
end


class ASTArithmeticOp < ASTExpr
  def initialize(lhs, op, rhs)
    @op, @lhs, @rhs = op, lhs, rhs
  end

  OP_MAP = {
    "+" => { :op => :+, :types => [:number]},
    "-" => { :op => :-, :types => [:number]},
    "*" => { :op => :*, :types => [:number]},
    "/" => { :op => :/, :types => [:number]},
    "%" => { :op => :%, :types => [:number]},
  }

  def evaluate(context)
    desc = OP_MAP[@op]
    if desc.nil?
      raise PeachesInternalError.new "Unknown arithmetic operator: #{@op}"
    end

    lhs = assert_full_eval(@lhs, context, desc[:types])
    rhs = assert_full_eval(@rhs, context, desc[:types])

    ASTNumberLiteral.new(lhs.value.public_send(desc[:op], rhs.value))
  end


  def to_s
    "(#{@lhs} #{@op} #{@rhs})"
  end

  def visit(visitor)
    visitor.visit self
    @lhs.visit visitor
    @rhs.visit visitor
  end
end

class ASTLogicalOp < ASTExpr
  def initialize(lhs, op, rhs)
    @op, @lhs, @rhs = op, lhs, rhs
  end

  def evaluate(context)
    lhs = assert_full_eval(@lhs, context, [:boolean])
    # Only evaluate rhs when required
    if (lhs.to_bool && @op == '&&') || (!lhs.to_bool && @op == '||')
      return rhs.assert_full_eval(@rhs, context, [:boolean])
    end

    lhs
  end

  def to_s
    "(#{@lhs} #{@op} #{@rhs})"
  end

  def visit(visitor)
    visitor.visit self
    @lhs.visit visitor
    @rhs.visit visitor
  end
end

class ASTCompareOp < ASTExpr
  def initialize(lhs, op, rhs)
    @op, @lhs, @rhs = op, lhs, rhs
  end

  OP_MAP = {
    '<'  => { :op => "<".to_sym,  :types => [:number]},
    '<=' => { :op => "<=".to_sym, :types => [:number]},
    '>'  => { :op => ">".to_sym,  :types => [:number]},
    '>=' => { :op => ">=".to_sym, :types => [:number]},
    '==' => { :op => "==".to_sym, :types => [:number, :boolean]},
    '/=' => { :op => "/=".to_sym, :types => [:number, :boolean]},
  }

  def evaluate(context)
    desc = OP_MAP[@op]
    if desc.nil?
      raise PeachesInternalError.new "Unknown compare operator: #{@op}"
    end

    lhs = assert_full_eval(@lhs, context, desc[:types])
    rhs = assert_full_eval(@lhs, context, desc[:types])

    ASTBoolLiteral.new(lhs.value.send(desc[:op], rhs.value))
  end

  def to_s
    "(#{@lhs} #{@op} #{@rhs})"
  end

  def visit(visitor)
    visitor.visit self
    @lhs.visit visitor
    @rhs.visit visitor
  end
end

class ASTVisitor
  def visit(node)
  end
end


# IF
# Declaration
# Literal
#   - Boolean
#   - Number
# Identifier
# Error
# Undef
# Operator
#   - LogicalOp
#   - CompareOp
#   - ArithmeticOp

class Parser
  include Rsec::Helpers
  extend Rsec::Helpers


  SPACE      = /[\ \t]*/.r
  COMMENT    = ( seq_('{-', /((?!-}).)+/ ,'-}') \
               | seq(SPACE.maybe, /--((?!([\r\n]|$)).)+/.r) & (/[\r\n]/.r | ''.r.eof) \
               )
  CSPACE = (seq(SPACE, COMMENT, SPACE) | SPACE)

  # Specialisation of symbol that does not allow '\n'
  def self.symbol_(pattern, &p)
    symbol(pattern, CSPACE, &p)
  end

  NUM        = prim :int64 {|num| ASTNumberLiteral.new (Integer(num))}
  # Magic here: negative lookahead to prohibit keyword/symbol ambiguity
  IDENTIFIER = seq((''.r ^ lazy{KEYWORD}), symbol_(/[a-zA-Z]\w*/)) {|_,id| ASTIdentifier.new(id)}.expect('identifier')
  IF         = word('if').expect 'keyword_if'
  THEN       = word('then').expect 'keyword_then'
  ELSE       = word('else').expect 'keyword_else'
  CMP_OP     = symbol_(/(\<=|\<|\>|\>=|==|\/=)/).fail 'compare operator'
  LOGIC_OP   = symbol_(/(&&|\|\|)/).fail 'logical operator'
  MULT_OP    = symbol_(/[*\/%]/).fail 'multiplication operator'
  ADD_OP     = symbol_(/[\+\-]/).fail 'addition operator'
  BOOLEAN    = (symbol_('True') {|_| ASTBoolLiteral.new(true)} | symbol_('False') {|_| ASTBoolLiteral.new(false)}).fail 'boolean'
  UNDEF      = symbol_('undefined')
  ERROR      = symbol_('error')
  KEYWORD    = IF | THEN | ELSE | BOOLEAN | UNDEF | ERROR

  def space
    CSPACE
  end

  def comment
    COMMENT
  end

  # Specialisation of seq_ that does not allow '\n'
  def seq__(*xs,&p)
    seq_(*xs, skip: CSPACE, &p)
  end

  def arith_expr
    if @ARITH_EXPR.nil?
      arith_expr = ( seq__(lazy{term}, ADD_OP, lazy{arith_expr}) { |lhs, op, rhs|
                        ASTArithmeticOp.new(lhs, op, rhs)
                      } \
                   | lazy{term} \
                   )
      term       = ( seq__(lazy{factor}, MULT_OP, lazy{term}) { |lhs, op, rhs|
                        ASTArithmeticOp.new(lhs, op, rhs)
                      }\
                   | lazy{factor} \
                   )
      factor     = ( seq__('(', arith_expr, ')')[1] \
                   | lazy{call} \
                   | NUM \
                   )
      _ = factor # Silence warning
      @ARITH_EXPR = arith_expr.fail "arithmetic expression"
    end
    @ARITH_EXPR
  end

  def cond_expr
    if @COND_EXPR.nil?
      cond_expr = ( seq__(lazy{ao_expr}, LOGIC_OP, lazy{cond_expr}) { |lhs, op, rhs|
                       ASTLogicalOp.new(lhs, op, rhs)
                     } \
                  | lazy{ao_expr} \
                  )
      ao_expr   = ( seq__(lazy{arith_expr}, CMP_OP, lazy{arith_expr}) { |lhs, op, rhs|
                       ASTCompareOp.new(lhs, op, rhs)
                     } \
                  | seq__('(', cond_expr, ')')[1] \
                  | BOOLEAN \
                  )
      _ = ao_expr # Silence warning
      @COND_EXPR = cond_expr.fail "conditional expression"
    end
    @COND_EXPR
  end

  def expr
    if @EXPR.nil?
      expr      = ( seq__(IF, lazy{cond_expr}, THEN, lazy{expr}, ELSE, lazy{expr}) { |_,cond,_,e1,_,e2|
                      ASTIf.new(cond, e1, e2)
                    } \
                  | lazy{cond_expr} \
                  | lazy{arith_expr} \
                  | UNDEF \
                  | ERROR \
                  )
      @EXPR = expr.fail "expression"
    end
    @EXPR
  end

  # We declare a var decl because this will make it easier to add
  # type annotations if required
  def var_decl
    IDENTIFIER.fail "vardecl"
  end

  def call
    if @CALL.nil?
      arg_list = ( seq__(lazy{expr}, lazy{arg_list}) \
                 | lazy{expr} \
                 )
      callsite =  ( seq__(IDENTIFIER, arg_list) \
                  | IDENTIFIER \
                  )
      @CALL = seq(''.r, callsite).cached { |_,xs|
        id, args = *xs
        ASTCall.new(id.label, listify(args))
      }
    end
    @CALL
  end

  def decl
    if @DECL.nil?
      par_list    = ( seq__(var_decl, lazy{par_list}) \
                    | var_decl \
                    ).fail "parameterlist"
      declaration = ( seq__(var_decl, par_list) \
                    | var_decl \
                    ).fail "function declaration"
      definition  = expr

      @DECL = seq__(declaration, '=', definition, comment.maybe) { |decl,_,expr|
        id, params = decl
        ASTDecl.new(id, listify(params), expr)
      }
    end
    @DECL
  end

  def listify(astlist)
    if astlist.nil?
      astlist = []
    elsif !astlist.respond_to?(:flatten)
      astlist = [astlist]
    else
      astlist = astlist.flatten
    end
    astlist
  end

  def program
    program = ( seq_(comment, lazy{program}, skip:/[\r\n]+/)[1] \
              | seq_(decl, lazy{program}, skip: /[\r\n]+/) \
              | seq_(decl, /[\r\n]+/.r.maybe) {|d, _| [d]} \
              )
    seq(/[\r\n]+/.r.maybe, program, /[\r\n]+/.r.maybe).eof { |_,p,_| ASTProgram.new(p.flatten) }
  end
end # class Parser

end # module Peaches

if __FILE__ == $PROGRAM_NAME
  parser = Peaches::Parser.new
  pp parser.arith_expr.eof.parse! ("hugo4")
  pp parser.arith_expr.eof.parse! ("42 - 8 * 4*25 + 20 - 32")
  pp parser.arith_expr.eof.parse! ("2*42 - 8 * 4*25 + 20 - 32")
  pp parser.arith_expr.eof.parse! ("4 + 25 * 8")

  pp parser.cond_expr.eof.parse! ("(32 - 1) /= 42")
  pp parser.cond_expr.eof.parse! ("(4 /= 5)")
  pp parser.cond_expr.eof.parse! ("(4 /= 5) && ((32 - 1) /= 42)")
  pp parser.cond_expr.eof.parse! ("4 /= 5 && 32 - 1 /= 42")

  puts "IFS"
  pp parser.expr.eof.parse! ("if 4 /= 5 then 42 else 21")

  pp parser.decl.eof.parse! ("x = if 4 /= 5 then 42 else 21")
  pp parser.decl.eof.parse! ("f x y = if 4 /= 5 then 42 else 21")

  pp parser.program.eof.parse! %Q[
    x = 4
    y = 10 * x + 20
    f a b = if 2 /=4 || (10 / 2 == 5) then a + b else a * b
  ]
  pp parser.program.eof.parse! %Q[
    x = 4

    y = 10 * x + 20
    f a b = if 2 /=4 || (10 / 2 == 5) then a + b else a * b
  ]

  pp parser.program.eof.parse! %Q[
    x = 4
    y = 10 * x + 20 {-
      ASDF
    -}
    f a b = if 2 /=4 || (10 / 2 == 5) then a + b else a * b
  ]

  pp parser.comment.parse! ("{- asdf -}")
  pp parser.comment.parse! ("-- ASDF ASDF")
  pp parser.comment.eof.parse! ("-- ASDF ASDF")
  pp parser.space.parse! (" {- asdf -}")

  pp parser.program.eof.parse! ("x = 1 + {- asdf -} 4")
  pp parser.program.eof.parse! ("x = 1 +{- asdf -}4")
  pp parser.program.eof.parse! ("x = 1 + 4 -- asdf")

  program = parser.program.parse!  %Q[
    x = 4
    y = 10 * x + 20
    z = if y > 10 && 1 /= 2 then x else y
  ]

  pp program.evaluate.lookup("z")

  program = parser.program.parse!  %Q[
    -- Full size comment
    x ={- "ASDF" -} 4
    y = 10 * x + 20 -- ASDF 4 + 5
    z = if y > 10 && 1 /= 2 then{-ASDF-} x else y
  ]
  pp program.evaluate.lookup("z")

end
