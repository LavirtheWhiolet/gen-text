require 'parse'
require 'gen_text/vm'

module GenText
  
  class Compile < Parse
    
    # @method call(*args)
    #   @param (see Parse#call)
    #   @return [String] a code of a Ruby expression which evaluates to
    #     a class extending {GenText}
    #     (<code>"Class.new(GenText) do ... end"</code>).
    
    private
    
    # ---- AST & Code Generation ----
    
    # @!visibility private
    Context = Struct.new :rule_scope, :rule_labels
    
    Program = ASTNode.new :rules, :top_expr do
      
      def to_vm_code
        rule_labels = {}; begin
          rules.each do |rule|
            raise Parse::Error.new(rule.pos, "rule `#{rule.name} is defined twice") if rule_labels.has_key? rule.name
            rule_labels[rule.name] = VM::Label.new
          end
        end
        code = rules.map do |rule|
          [
            rule_labels[rule.name],
            *rule.body.to_vm_code(Context.new(new_binding, rule_labels)),
            lambda do |vm|
              vm.pc = vm.stack.pop
            end
          ]
        end.reduce(:concat)
      end
      
      def may_restore_output?
        top_expr.may_restore_output? or
        rules.map(&:body).any? { |b| b.may_restore_output? }
      end
      
      private
      
      # @return [Binding]
      def new_binding
        binding
      end
      
    end
    
    GenString = ASTNode.new :string do
      
      def to_vm_code(context)
        [
          lambda do |vm|
            vm.out.write(string)
            vm.pc += 1
          end
        ]
      end
      
      def may_restore_output?
        false
      end
      
    end
    
    GenNumber = ASTNode.new :from, :to do
      
      def to_vm_code(context)
        [
          lambda do |vm|
            vm.out.write(rand(from..to))
            vm.pc += 1
          end
        ]
      end
      
      def may_restore_output?
        false
      end
      
    end
    
    Repeat = ASTNode.new :subexpr, :from_times, :to_times do
      
      def to_vm_code(context)
        raise Parse::Error.new(pos, "`from' can not be greater than `to'") if from_times > to_times
        # 
        subexpr_code = subexpr.to_vm_code(context)
        # Mandatory part (0...from_times).
        if from_times > 0 then
          loop1 = VM::Label.new
          loop1_end = VM::Label.new
          [
            lambda do |vm|
              vm.stack.push counter = from_time
              vm.pc += 1
            end,
            loop1,
            lambda do |vm|
              if vm.stack.last == 0 then
                vm.stack.pop # counter
                vm.pc = loop1_end.address
              else
                vm.stack[-1] -= 1
                vm.pc += 1
              end
            end,
            *subexpr_code,
            lambda { |vm| vm.pc = loop1.address },
            loop1_end
          ]
        else
          []
        end +
        # Optional part (from_times...to_times)
        if (to_times - from_times) < INF
          loop2 = VM::Label.new
          loop2_end = VM::Label.new
          [
            lambda do |vm|
              vm.stack.push counter = rand(to_times - from_times + 1)
              vm.pc += 1
            end,
            loop2,
            lambda do |vm|
              if vm.stack.last == 0 then
                vm.pc = loop2_end.address
              else
                vm.push_rescue_point(loop2_end.address)
                vm.pc += 1
              end
            end,
            *subexpr_code,
            lambda do |vm|
              vm.pop # rescue point
              vm.pc = loop2.address
            end,
            loop2_end,
            lambda do |vm|
              vm.stack.pop # counter
              vm.pc += 1
            end
          ]
        else
          loop2 = VM::Label.new
          loop2_end = VM::Label.new
          [
            loop2,
            lambda do |vm|
              if rand >= 0.5 then
                vm.pc = loop2_end.address
              else
                vm.push_rescue_point(loop2_end.address)
                vm.pc += 1
              end
            end,
            *subexpr_code,
            lambda do |vm|
              vm.pop # rescue point
              vm.pc = loop2.address
            end,
            loop2_end
          ]
        end
      end
      
      def may_restore_output?
        subexpr.may_restore_output?
      end
      
    end
    
    GenCode = ASTNode.new :to_s do
      
      def to_vm_code(context)
        rule_scope = context.rule_scope
        [
          lambda do |vm|
            data = rule_scope.eval(self.to_s, pos.file, pos.line+1)
            vm.out.write(data)
            vm.pc += 1
          end
        ]
      end
      
      def may_restore_output?
        false
      end
      
    end
    
    CheckCode = ASTNode.new :to_s do
      
      def to_vm_code(context)
        rule_scope = context.rule_scope
        [
          lambda do |vm|
            check_passed = rule_scope.eval(self.to_s, pos.file, pos.line+1)
            if check_passed then
              vm.pc += 1
            else
              vm.rescue_ or raise Parse::Error.new(pos, "check failed")
            end
          end
        ]
      end
      
      def may_restore_output?
        true
      end
      
    end
    
    ActionCode = ASTNode.new :to_s do
      
      def to_vm_code(context)
        rule_scope = context.rule_scope
        [
          lambda do |vm|
            rule_scope.eval(self.to_s, pos.file, pos.line+1)
            vm.pc += 1
          end
        ]
      end
      
      def may_restore_output?
        false
      end
      
    end
    
    RuleCall = ASTNode.new :name do
      
      def to_vm_code(context)
        label = context.rule_labels[name] or raise Parse::Error.new(pos, "rule `#{name}' not defined")
        [
          lambda do |vm|
            vm.stack.push vm.pc
            vm.pc = label.address
          end
        ]
      end
      
      def may_restore_output?
        false  # Wrong but the rule referenced will be checked anyway.
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
              if alternative.probability == :auto
              then auto_probability
              else alternative.probability
              end
          end
        end
        # Populate alternatives' labels.
        alternatives.each { |a| a.label = VM::Label.new }
        # Generate the code.
        initial_weights_and_labels = alternatives.map { |a| [a.weight, a.label] }
        end_label = VM::Label.new
        [
          lambda do |vm|
            vm.push initial_weights_and_labels.dup
            vm.pc += 1
          end,
          lambda do |vm|
            weights_and_labels = vm.stack.last
            vm.push_rescue_point
            # If no alternatives left...
            if weights_and_labels.size == 1 then
              _, label = *weights_and_labels.first
              vm.pc = label
            # If there are alternatives...
            else
              chosen_weight_and_label = sample_weighed(weights_and_labels)
              weights_and_labels.delete chosen_weight_and_label
              _, chosen_label = *chosen_weight_and_label
              vm.pc = chosen_label
            end
          end,
          *alternatives.map do |alternative|
            [
              alternative.label,
              *alternative.subexpr.to_vm_code(context),
              lambda { |vm| vm.pc = end_label }
            ]
          end.reduce(:concat),
          end_label,
          lambda do |vm|
            vm.stack.pop # rescue_point
            vm.stack.pop # weights_and_labels
          end
        ]
      end
      
      def may_restore_output?
        alternatives.map(&:subexpr).any?(&:may_restore_output?)
      end
      
      private
      
      # @param [Array<Array<(Numeric, Object)>>] weights_and_items
      # @return [Array<(Numeric, Object)>]
      def sample_weighed(weights_and_items)
        weight_sum = weights_and_item.map(&:first).reduce(:+)
        chosen_partial_weight_sum = rand(0...weight_sum)
        current_partial_weight_sum = 0
        weights_and_items.find do |weight, item|
          current_partial_weight_sum += weight
          current_partial_weight_sum > chosen_partial_weight_sum
        end or
        weights_and_items.last
      end
      
    end
    
    ChoiceAlternative = ASTNode.new :probability, :subexpr do
      
      # Used by {Choice#to_vm_code} only.
      # @return [Numeric]
      attr_accessor :weight
      
      # Used by {Choice#to_vm_code} only.
      # @return [VM::Label]
      attr_accessor :label
      
    end
    
    Seq = ASTNode.new :subexprs do
      
      def to_vm_code(context)
        subexprs.map { |subexpr| subexpr.to_vm_code(context) }.reduce(:concat)
      end
      
      def may_restore_output?
        subexprs.any?(&:may_restore_output?)
      end
      
    end
    
    RuleDefinition = ASTNode.new :name, :body
    
    # ---- Syntax ----
    
    rule :start do
      whitespace_and_comments and
      rules_and_action_codes = many {
        _{ rule_definition } or
        _{ expr }
      } and
      _(Program[
        rules_and_action_codes.select { |x| x.is_a? RuleDefinition },
        _(Seq[rules_and_action_codes.select { |x| not x.is_a? RuleDefinition }])
      ]).to_vm_code
    end
    
    rule :expr do
      choice
    end
    
    rule :choice do
      first = true
      _{
        as = two_or_more {
          p = choice_alternative_start(first) and s = seq and
          act { first = false } and
          _(ChoiceAlternative[p, s])
        } and
        _(Choice[as])
      } or
      _{ seq }
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
    
    def two_or_more(&f)
      x1 = f.() and x2 = f.() and xn = many(&f) and [x1, x2, *xn]
    end
    
    rule :seq do
      e = repeat and many {
        e2 = repeat and e = Seq[to_seq_subexprs(e) + to_seq_subexprs(e2)]
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
      _{ n = nonterm and not_follows(:eq) and _(RuleCall[n]) } or
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
      n = nonterm and eq and e = choice and semicolon and
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
      if /[\.eE]/ === s
      then Float(s)
      else Integer(s)
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
        _{ (scan("//") or scan("--")) and scan(/[^\n]*\n/m) } or
        _{
          p = pos and scan("/*") and
          many { not_follows { scan("*/") } and scan(/./m) } and
          (scan("*/") or raise Expected.new(p, "`*/' at the end"))
        }
      }
    end
    
    # ---- Utilities ----
    
    # @!visibility private
    class ::Object
      
      # @return [String] a {String} x which eval(x) == self.
      def to_rb
        inspect
      end
      
    end
    
    # @!visibility private
    class ::Float
      
      # (see Object#to_rb)
      def to_rb
        case self
        when INF then "Float::INFINITY"
        when -INF then "(-Float::INFINITY)"
        else to_s
        end
      end
      
    end
    
    INF = Float::INFINITY
    
  end
  
end
