require 'restorable_output'

module GenText
  
  class VM
    
    # @param [RestorableOutput] out
    def initialize(out)
      @stack = []
      @out = out
      @pc = 0
      @halted = false
    end
    
    # @param (see #run)
    # @return [Boolean] true if +program+ may result in calling
    #   {RestorableOutput#state=}.
    def self.may_set_output_state?(program)
      program.any? { |instruction| instruction.first == :rescue_ }
    end
    
    # @param program is Array of <code>[:method_id, *args]</code>.
    # @param [Boolean] do_not_run if true then +program+ will not be run
    #   (some checks and initializations will be performed only).
    # @return [void]
    def run(program, do_not_run = false)
      if $DEBUG
        STDERR.puts "PROGRAM:"
        program.each_with_index do |instruction, addr|
          STDERR.puts "  #{addr}: #{inspect_instruction(instruction)}"
        end
      end
      return if do_not_run
      STDERR.puts "RUN TRACE:" if $DEBUG
      until halted?
        instruction = program[@pc]
        method_id, *args = *instruction
        STDERR.puts "  #{@pc}: #{inspect_instruction(instruction)}" if $DEBUG
        self.__send__(method_id, *args)
        if $DEBUG then
          STDERR.puts "    PC: #{@pc}"
          STDERR.puts "    STACK: #{@stack.inspect}"
        end
      end
    end
    
    # @return [Integer]
    attr_reader :pc
    
    # @return [RestorableOutput]
    attr_reader :out
    
    # @return [Boolean]
    def halted?
      @halted
    end
    
    # Sets {#halted?} to true.
    # 
    # @return [void]
    def halt
      @halted = true
    end
    
    # NOP
    # 
    # @return [void]
    def generated_from(*args)
      @pc += 1
    end
    
    # Pushes +o+ to the stack.
    # 
    # @param [Object] o
    # @return [void]
    def push(o)
      @stack.push o
      @pc += 1
    end
    
    # {#push}(o.dup)
    # 
    # @param [Object] o
    # @return [void]
    def push_dup(o)
      push(o.dup)
    end
    
    # {#push}(rand(+r+) if +r+ is specified; rand() otherwise)
    # 
    # @param [Object, nil] r
    # @return [void]
    def push_rand(r = nil)
      push(if r then rand(r) else rand end)
    end
    
    # Pops the value from the stack.
    # 
    # @return [Object] the popped value.
    def pop
      @stack.pop
      @pc += 1
    end
    
    # If {#pop} is true then {#pc} := +addr+.
    # 
    # @param [Integer] addr
    # @return [void]
    def goto_if(addr)
      if @stack.pop then
        @pc = addr
      else
        @pc += 1
      end
    end
    
    # @return [void]
    def dec
      @stack[-1] -= 1
      @pc += 1
    end
    
    # If the value on the stack != 0 then {#goto}(+addr).
    # 
    # @param [Integer] addr
    # @return [void]
    def goto_if_not_0(addr)
      if @stack.last != 0 then
        @pc += 1
      else
        @pc = addr
      end
    end
    
    # If rand > +v+ then {#goto}(addr)
    # 
    # @param [Numeric] v
    # @param [Integer] addr
    # @return [void]
    # 
    def goto_if_rand_gt(v, addr)
      if rand > v then
        @pc = addr
      else
        @pc += 1
      end
    end
    
    # @param [Integer] addr
    # @return [void]
    def goto(addr)
      @pc = addr
    end
    
    # Writes {#pop} to {#out}.
    # 
    # @return [void]
    def gen
      @out.write @stack.pop
      @pc += 1
    end
    
    # {#push}(eval(+ruby_code+, +file+, +line+))
    # 
    # @param [Binding] binding_
    # @param [String] ruby_code
    # @param [String] file original file of +ruby_code+.
    # @param [Integer] line original line of +ruby_code+.
    # @return [void]
    def eval_ruby_code(binding_, ruby_code, file, line)
      @stack.push binding_.eval(ruby_code, file, line)
      @pc += 1
    end
    
    # {#push}(state of {#out} and {#pc} as {RescuePoint})
    # 
    # @param [Integer, nil] pc if specified then it is pushed instead of {#pc}.
    # @return [void]
    def push_rescue_point(pc = nil)
      @stack.push RescuePoint[(pc or @pc), @out.state]
      @pc += 1
    end
    
    # {#pop}s until a {RescuePoint} is found then restore {#out} and {#pc} from
    # the {RescuePoint}.
    # 
    # @param [Proc] on_failure is called if no {RescuePoint} is found
    # @return [void]
    def rescue_(on_failure)
      @stack.pop until @stack.empty? or @stack.last.is_a? RescuePoint
      if @stack.empty? then
        on_failure.()
      else
        rescue_point = @stack.pop
        @pc = rescue_point.return_pc
        @out.state = rescue_point.out_state
      end
    end
    
    # @param [Integer] addr
    # @return [void]
    def call(addr)
      @stack.push(@pc + 1)
      @pc = addr
    end
    
    # @return [void]
    def ret
      @pc = @stack.pop
    end
    
    # Let stack contains +wa+ = [[weight1, address1], [weight2, address2], ...].
    # This function:
    # 
    # 1. Picks a random address from +wa+ (the more weight the
    #    address has, the more often it is picked);
    # 2. Deletes the chosen address from +wa+;
    # 3. If there was the only address in +wa+ then it does {#push}(nil);
    #    otherwise it does {#push_rescue_point};
    # 4. {#goto}(the chosen address).
    # 
    # @return [void]
    def weighed_choice
      weights_and_addresses = @stack.last
      # If no alternatives left...
      if weights_and_addresses.size == 1 then
        _, address = *weights_and_addresses.first
        @stack.push nil
        @pc = address
      # If there are alternatives...
      else
        chosen_weight_and_address = sample_weighed(weights_and_addresses)
        weights_and_addresses.delete chosen_weight_and_address
        _, chosen_address = *chosen_weight_and_address
        push_rescue_point
        @pc = chosen_address
      end
    end
    
    RescuePoint = Struct.new :return_pc, :out_state
    
    private
    
    # @param [Array<Array<(Numeric, Object)>>] weights_and_items
    # @return [Array<(Numeric, Object)>]
    def sample_weighed(weights_and_items)
      weight_sum = weights_and_items.map(&:first).reduce(:+)
      chosen_partial_weight_sum = rand(0...weight_sum)
      current_partial_weight_sum = 0
      weights_and_items.find do |weight, item|
        current_partial_weight_sum += weight
        current_partial_weight_sum > chosen_partial_weight_sum
      end or
      weights_and_items.last
    end
    
    def inspect_instruction(instruction)
      method_id, *args = *instruction
      "#{method_id} #{args.map(&:inspect).join(", ")}"
    end
    
  end
  
end
