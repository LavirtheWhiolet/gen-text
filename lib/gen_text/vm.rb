
module GenText
  
  class VM
    
    # @param program Array of <code>[:method_id, *args]</code>.
    # @return [Boolean] true if +program+ may result in calling
    #   {IO#pos=} and false otherwise.
    def self.may_set_out_pos?(program)
      program.any? do |instruction|
        [:rescue_, :capture].include? instruction.first
      end
    end
    
    # Executes +program+.
    # 
    # If +program+ may result in calling {IO#pos=} (see {VM::may_set_out_pos?}
    # then after the execution the +out+ may contain garbage after its {IO#pos}.
    # It is up to the caller to truncate the garbage or to copy the useful data.
    # 
    # @param program Array of <code>[:method_id, *args]</code>.
    # @param [IO] out
    # @param [Boolean] do_not_run if true then +program+ will not be run
    #   (some checks and initializations will be performed only).
    # @return [void]
    def run(program, out, do_not_run = false)
      # 
      if $DEBUG
        STDERR.puts "PROGRAM:"
        program.each_with_index do |instruction, addr|
          STDERR.puts "  #{addr}: #{inspect_instruction(instruction)}"
        end
      end
      #
      return if do_not_run
      # Init.
      @stack = []
      @out = out
      @pc = 0
      @halted = false
      @local_vars = {}
      # Run.
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
    
    # @return [IO]
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
    
    # @return [Hash<String, String>] variables set by {#capture}.
    attr_reader :local_vars
    
    # {#local_vars}[+name+] = substring of {#out} from {#pop} to current
    # {IO#pos}.
    # 
    # @param [String] name
    # @return [void]
    def capture(name)
      @local_vars[name] = begin
        current_pos = @out.pos
        @out.pos = @stack.pop
        r = @out.read(current_pos - @out.pos)
        @out.pos = current_pos
        r
      end
      @pc += 1
    end
    
    # {#push}({#local_vars});
    # {#local_vars} = empty;
    # 
    # @return [void]
    def new_local_vars
      @stack.push(@local_vars)
      @local_vars = {}
      @pc += 1
    end
    
    # {#local_vars} = {#pop}
    # 
    # @return [void]
    def restore_local_vars
      @local_vars = @stack.pop
      @pc += 1
    end
    
    # {#push}(eval({#local_vars} + +ruby_code+, +file+, +line+))
    # 
    # @param [Binding] binding_
    # @param [String] ruby_code
    # @param [String] file original file of +ruby_code+.
    # @param [Integer] line original line of +ruby_code+.
    # @return [void]
    def eval_ruby_code(binding_, ruby_code, file, line)
      # Put local_vars into binding_.
      begin
        # TODO: Use Binding#local_variable_set(...).
        binding_.eval(
          @local_vars.map { |name, value| "#{name} = #{value.inspect};" }.join
        )
      end
      # Evaluate the code in binding_ and push the result.
      @stack.push binding_.eval(ruby_code, file, line)
      # Update local_vars from binding_.
      begin
        # TODO: Use Binding#local_variable_get(...).
        local_var_names = @local_vars.keys
        local_var_values = *binding_.eval("[#{local_var_names.join(", ")}]")
        local_var_names.zip(local_var_values).each do |name, value|
          unless value.is_a? String or value.is_a? Numeric then
            binding_.eval(
              "raise %(captured variables can be set to a string or a number only: #{name} = #{value.inspect})",
              file,
              line
            )
          end
          @local_vars[name] = value
        end
      end
      # 
      @pc += 1
    end
    
    # {#push}({#out}'s {IO#pos})
    # 
    # @return [void]
    def push_pos
      @stack.push(@out.pos)
      @pc += 1
    end
    
    # {#push}({#out}'s {IO#pos}, {#pc} as {RescuePoint}, {#local_vars})
    # 
    # @param [Integer, nil] pc if specified then it is pushed instead of {#pc}.
    # @return [void]
    def push_rescue_point(pc = nil)
      @stack.push RescuePoint[(pc or @pc), @out.pos, @local_vars.dup]
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
        @pc = rescue_point.pc
        @out.pos = rescue_point.out_pos
        @local_vars = rescue_point.local_vars
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
    
    RescuePoint = Struct.new :pc, :out_pos, :local_vars
    
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
