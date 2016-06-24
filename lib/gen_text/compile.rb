require 'parse'
require 'gen_text/vm'

module GenText
  
  class Compile < Parse
    
    # @param (see Parse#call)
    # @return the program as an Array of <code>[:method_id, *args]</code> where
    #   <code>method_id</code> is ID of {VM}'s method. The program may raise
    #   {CheckFailed}.
    def call(*args)
      super(*args).to_vm_code
    end
    
    private
    
    # ---- Utils ----
    
    INF = Float::INFINITY
    
    # @!visibility private
    module ::ASTNode
      
      module_function
      
      # @return [Array<Array<(:generated_from, String)>>]
      def generated_from(pos)
        if $DEBUG then
          [[:generated_from, "#{pos.file}:#{pos.line+1}:#{pos.column+1}"]]
        else
          []
        end
      end
      
    end
    
    # ---- AST & Code Generation ----
    
    # @!visibility private
    Context = Struct.new :rule_scope, :rule_labels
    
    # @!visibility private
    class Label
    end
    
    Program = ASTNode.new :rules do
      
      def to_vm_code
        rule_labels = {}; begin
          rules.each do |rule|
            raise Parse::Error.new(rule.pos, "rule `#{rule.name}' is defined twice") if rule_labels.has_key? rule.name
            rule_labels[rule.name] = Label.new
          end
        end
        code =
          [
            [:call, rule_labels[rules.first.name]],
            [:halt],
            *rules.map do |rule|
              [
                *generated_from(rule.pos),
                rule_labels[rule.name],
                *rule.body.to_vm_code(Context.new(new_binding, rule_labels)),
                [:ret]
              ]
            end.reduce(:concat)
          ]
        return replace_labels_with_addresses(code)
      end
      
      private
      
      # @return [Binding]
      def new_binding
        binding
      end
      
      def replace_labels_with_addresses(code)
        # Remove labels and remember their addresses.
        addresses = {}
        new_code = []
        code.each do |instruction|
          case instruction
          when Label
            addresses[instruction] = new_code.size
          else
            new_code.push instruction
          end
        end
        # Replace labels in instructions' arguments.
        this = lambda do |x|
          case x
          when Array
            x.map(&this)
          when Label
            addresses[x]
          else
            x
          end
        end
        return this.(new_code)
      end
      
    end
    
    GenString = ASTNode.new :string do
      
      def to_vm_code(context)
        [
          *generated_from(pos),
          [:push, string],
          [:gen]
        ]
      end
      
    end
    
    GenNumber = ASTNode.new :from, :to do
      
      def to_vm_code(context)
        [
          *generated_from(pos),
          [:push_rand, from..to],
          [:gen]
        ]
      end
      
    end
    
    Repeat = ASTNode.new :subexpr, :from_times, :to_times do
      
      def to_vm_code(context)
        raise Parse::Error.new(pos, "`from' can not be greater than `to'") if from_times > to_times
        # 
        subexpr_code = subexpr.to_vm_code(context)
        # Code.
        subexpr_label = Label.new
        generated_from(pos) +
        # Mandatory part (0...from_times).
        if from_times > 0
          loop1 = Label.new
          loop1_end = Label.new
          [
            [:push, from_times], # counter
            loop1,
            [:goto_if_not_0, loop1_end], # if counter == 0 then goto loop1_end
            [:call, subexpr_label],
            [:dec], # counter
            [:goto, loop1],
            loop1_end,
            [:pop] # counter
          ]
        else
          []
        end +
        # Optional part (from_times...to_times)
        if (to_times - from_times) == 0
          []
        elsif (to_times - from_times) < INF
          loop2 = Label.new
          loop2_end = Label.new
          [
            [:push_rand, (to_times - from_times + 1)], # counter
            loop2,
            [:goto_if_not_0, loop2_end], # if counter == 0 then goto loop2_end
            [:push_rescue_point, loop2_end],
            [:call, subexpr_label],
            [:pop], # rescue point
            [:dec], # counter
            [:goto, loop2],
            loop2_end,
            [:pop], # counter
          ]
        else # if (to_times - from_times) is infinite
          loop2 = Label.new
          loop2_end = Label.new
          [
            loop2,
            [:goto_if_rand_gt, 0.5, loop2_end],
            [:push_rescue_point],
            [:call, subexpr_label],
            [:pop], # rescue point
            [:goto, loop2],
            loop2_end
          ]
        end +
        # Subexpr as subroutine.
        begin
          after_subexpr = Label.new
          [
            [:goto, after_subexpr],
            subexpr_label,
            *subexpr.to_vm_code(context),
            [:ret],
            after_subexpr
          ]
        end
      end
      
    end
    
    GenCode = ASTNode.new :to_s do
      
      def to_vm_code(context)
        [
          *generated_from(pos),
          [:eval_ruby_code, context.rule_scope, self.to_s, pos.file, pos.line+1],
          [:gen]
        ]
      end
      
    end
    
    CheckCode = ASTNode.new :to_s do
      
      def to_vm_code(context)
        passed = Label.new
        [
          *generated_from(pos),
          [:eval_ruby_code, context.rule_scope, self.to_s, pos.file, pos.line+1],
          [:goto_if, passed],
          [:rescue_, lambda { raise CheckFailed.new(pos) }],
          passed
        ]
      end
      
    end
    
    ActionCode = ASTNode.new :to_s do
      
      def to_vm_code(context)
        [
          *generated_from(pos),
          [:eval_ruby_code, context.rule_scope, self.to_s, pos.file, pos.line+1],
          [:pop]
        ]
      end
      
    end
    
    RuleCall = ASTNode.new :name do
      
      def to_vm_code(context)
        [
          *generated_from(pos),
          [:call, (context.rule_labels[name] or raise Parse::Error.new(pos, "rule `#{name}' not defined"))]
        ]
      end
      
    end
    
    Choice = ASTNode.new :alternatives do
      
      def to_vm_code(context)
        # Populate alternatives' weights.
        if alternatives.map(&:probability).all? { |x| x == :auto } then
          alternatives.each { |a| a.weight = 1 }
        else
          known_probabilities_sum =
            alternatives.map(&:probability).reject { |x| x == :auto }.reduce(:+)
          raise Parse::Error.new(pos, "probabilities sum exceed 100%") if known_probabilities_sum > 1.00 + 0.0001
          auto_probability =
            (1.00 - known_probabilities_sum) / alternatives.map(&:probability).select { |x| x == :auto }.size
          alternatives.each do |alternative|
            alternative.weight =
              if alternative.probability == :auto then
                auto_probability
              else
                alternative.probability
              end
          end
        end
        # Populate alternatives' labels.
        alternatives.each { |a| a.label = Label.new }
        # Generate the code.
        initial_weights_and_labels = alternatives.map { |a| [a.weight, a.label] }
        end_label = Label.new
        [
          *generated_from(pos),
          [:push_dup, initial_weights_and_labels],
          [:weighed_choice],
          *alternatives.map do |alternative|
            [
              alternative.label,
              *alternative.subexpr.to_vm_code(context),
              [:goto, end_label],
            ]
          end.reduce(:concat),
          end_label,
          [:pop], # rescue_point
          [:pop], # weights_and_labels
        ]
      end
      
    end
    
    ChoiceAlternative = ASTNode.new :probability, :subexpr do
      
      # Used by {Choice#to_vm_code} only.
      # @return [Numeric]
      attr_accessor :weight
      
      # Used by {Choice#to_vm_code} only.
      # @return [Label]
      attr_accessor :label
      
    end
    
    Seq = ASTNode.new :subexprs do
      
      def to_vm_code(context)
        generated_from(pos) +
          subexprs.map { |subexpr| subexpr.to_vm_code(context) }.reduce(:concat)
      end
      
    end
    
    RuleDefinition = ASTNode.new :name, :body
    
    # ---- Syntax ----
    
    rule :start do
      whitespace_and_comments and
      rules = many { rule_definition } and
      _(Program[rules])
    end
    
    rule :expr do
      choice
    end
    
    rule :choice do
      first = true
      as = one_or_more {
        p = choice_alternative_start(first) and s = seq and
        act { first = false } and
        _(ChoiceAlternative[p, s])
      } and
      if as.size == 1 then
        as.first.subexpr
      else
        _(Choice[as])
      end
    end
    
    # Returns probability or :auto.
    def choice_alternative_start(first)
      _{
        (_{ slash } or _{ pipe }) and
        probability = (
          _{
            lbracket and
            x = ufloat and opt { percent and act { x /= 100.0 } } and
            rbracket and
            x
          } or
          :auto
        )
      } or
      (if first then :auto else nil end)
    end
    
    rule :seq do
      e = repeat and many {
        e2 = repeat and e = _(Seq[to_seq_subexprs(e) + to_seq_subexprs(e2)])
      } and
      e
    end
    
    def to_seq_subexprs(e)
      case e
      when Seq then e.subexprs
      else [e]
      end
    end
    
    rule :repeat do
      e = primary and many {
        _{
          asterisk and
          from = 0 and to = INF and
          opt {
            lbracket and
            n = times and act { from = n and to = n } and
            opt {
              ellipsis and
              n = times and act { to = n }
            } and
            rbracket
          } and
          e = _(Repeat[e, from, to]) } or
        _{ question and e = _(Repeat[e, 0, 1]) } or
        _{ plus and e = _(Repeat[e, 1, INF]) }
      } and
      e
    end
    
    def times
      _{ uint } or
      _{ inf and INF }
    end
    
    rule :primary do
      _{ s = string and _(GenString[s]) } or
      _{ c = code("{=") and _(GenCode[c]) } or
      _{ c = code("{?") and _(CheckCode[c]) } or
      _{ action_code } or
      _{ n = nonterm and not_follows(:eq, :larrow) and _(RuleCall[n]) } or
      _{ gen_number } or
      _{ lparen and e = expr and rparen and e }
    end
    
    def gen_number
      n1 = number and n2 = opt { ellipsis and number } and
      act { n2 = (n2.first or n1) } and
      _(GenNumber[n1, n2])
    end
    
    rule :action_code do
      c = code("{") and _(ActionCode[c])
    end
    
    rule :rule_definition do
      n = nonterm and (_{eq} or _{larrow}) and e = choice and semicolon and
      _(RuleDefinition[n, e])
    end
    
    # ---- Tokens ----
    
    token :inf, "inf"
    token :asterisk, "*"
    token :question, "?"
    token :plus, "+"
    token :pipe, "|"
    token :slash, "/"
    token :eq, "="
    token :semicolon, ";"
    token :percent, "%"
    token :ellipsis, "..."
    token :lbrace, "{"
    token :rbrace, "}"
    token :lparen, "("
    token :rparen, ")"
    token :lbracket, "["
    token :rbracket, "]"
    token :dot, "."
    token :larrow, "<-"
    
    # Parses "#{start} #{code_part} } #{whitespace_and_comments}".
    # Returns the code_part.
    def code(start)
      p = pos and
      scan(start) and c = code_part and
      (rbrace or raise Expected.new(p, "`}' at the end")) and
      c
    end
    
    rule :code_part do
      many {
        _{ scan(/\\./) } or
        _{ scan(/[^{}]+/) } or
        _{
          pp = pos and
          p1 = scan("{") and p2 = code_part and
          (p3 = scan("}") or raise Expected.new(pp, "`}' at the end")) and
          p1 + p2 + p3
        }
      }.join
    end
    
    token :string do
      _{ string0('"') } or
      _{ string0("'") } or
      _{ scan("U+") and c = scan(/\h+/) and [c.hex].pack("U") }
    end
    
    def string0(quote)
      p = pos and scan(quote) and
      s = many {
        _{ scan(/\\n/) and "\n" } or
        _{ scan(/\\t/) and "\t" } or
        _{ scan(/\\e/) and "\e" } or
        _{ scan(/\\./) } or
        scan(/[^#{quote}]/)
      }.join and
      (scan(quote) or raise Expected.new(p, "`#{quote}' at the end")) and s
    end
    
    token :nonterm do
      _{ scan(/`.*?`/) } or
      _{ scan(/[[:alpha:]_:][[:alnum:]\-_:]*/) }
    end
    
    token :int, "integer number" do
      n = number and n.is_a? Integer and n
    end
    
    token :uint, "non-negative integer number" do
      n = int and n >= 0 and n
    end
    
    token :number do
      s = scan(/[\-\+]?\d+(\.\d+)?([eE][\-\+]?\d+)?/) and
      if /[\.eE]/ === s then
        Float(s)
      else
        Integer(s)
      end
    end
    
    token :float, "floating point number" do
      number
    end
    
    token :ufloat, "non-negative floating point number" do
      n = number and n >= 0 and n
    end
    
    def whitespace_and_comments
      many {
        _{ scan(/\s+/) } or
        _{ scan("//") and scan(/[^\n]*\n/m) } or
        _{
          p = pos and scan("/*") and
          many { not_follows { scan("*/") } and scan(/./m) } and
          (scan("*/") or raise Expected.new(p, "`*/' at the end"))
        }
      }
    end
    
  end
  
  class CheckFailed < Exception
    
    # @param [Parse::Position] pos
    def initialize(pos)
      super("check failed")
      @pos = pos
    end
    
    # @return [Parse::Position] pos
    attr_reader :pos
    
  end
  
end
