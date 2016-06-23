require 'restorable_output'

class GenText
  
  # Generates some text and writes it to +out+.
  # 
  # It sets the output to +out+ and calls {#call0}.
  # 
  # @param [RestorableOutput] out
  # @return [Boolean] true if the text is generated successfully and false
  #   otherwise.
  # 
  def call(out)
    @__out__ = out
    restore_on_fail { call0 }
  end
  
  # @!method may_restore_output?
  #   @abstract
  #   @return [Boolean] true if this {GenText} may call
  #     {RestorableOutput#restore} on an output passed to {#call} and
  #     false otherwise.
  
  protected
  
  # @!method call0
  #   @abstract
  #   
  #   Implementation of {#call}.
  #   
  #   @return [Boolean]
  
  INF = Float::INFINITY
  
  # Writes +str+ to the output.
  # 
  # @param [#to_s] str
  # @return [true]
  def gen(str)
    @__out__.write(str)
    return true
  end
  
  # Calls {#restore_on_fail}(&f) +from+–+to+ times.
  # 
  # @param [Integer] from
  # @param [Integer] to
  # @yieldreturn [Boolean]
  # @return [Boolean] false if +f+ returns false before +from+ times and
  #   true otherwise
  def repeat(from, to, &f)
    raise "#{from} > #{to}" if from > to
    from.times do
      restore_on_fail(&f) or return false
    end
    if to == INF then
      while rand < 0.5
        restore_on_fail(&f) or break
      end
    else
      rand(to - from + 1).times do
        restore_on_fail(&f) or break
      end
    end
    return true
  end
  
  # Chooses an action randomly. The higher its weight, the more often the action
  # is chosen. Then it executes {#restore_on_fail}(&+action+). If the action
  # returns true then this method returns what the action returns. If the action
  # returns false then it is deleted from +weights_and_actions+ and this method
  # runs again.
  # 
  # It returns false if +weights_and_actions+ is empty.
  # 
  # @param [Array<Array<(Numeric, Proc<Boolean>)>>] weights_and_actions
  # @return [Boolean] what the chosen action returns.
  # 
  def weighed_choice(weights_and_actions)
    weight_sum = weights_and_actions.map(&:first).reduce(:+)
    while true
      return false if weights_and_actions.empty?
      chosen_partial_weight_sum = rand(0...weight_sum)
      current_partial_weight_sum = 0
      chosen_weight_and_action = begin
        weights_and_actions.find do |weight, action|
          current_partial_weight_sum += weight
          current_partial_weight_sum > chosen_partial_weight_sum
        end or
        weights_and_actions.last[1]
      end
      begin
        weight, action = *chosen_weight_and_action
        r = restore_on_fail(&action)
        if not r then
          weights_and_actions.delete chosen_weight_and_action
          weight_sum -= weight
          redo
        end
      end
      break(r)
    end
  end
  
  # Calls +f+ inside {RestorableOutput#remember} of the output. If +f+ returns
  # false then it calls {RestorableOutput#restore} on the output.
  # 
  # @return [Boolean] what +f+ returns.
  # 
  def restore_on_fail(&f)
    @__out__.remember do
      r = f.() or (@__out__.restore; r)
    end
  end
  
end
