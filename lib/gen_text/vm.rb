require 'restorable_output'

module GenText
  
  class VM
    
    def initialize(out)
      @stack = []
      @out = out
      @pc = 0
    end
    
    # @return [Integer]
    attr_accessor :pc
    
    # @return [Array]
    attr_reader :stack
    
    # @return [RestorableOutput]
    attr_reader :out
    
    # Pushes {RescuePoint} which holds +pc+ and the state of {#out} to {#stack}.
    # 
    # @param [Integer] pc
    # @return [void]
    def push_rescue_point(pc = self.pc)
      vm.push RescuePoint[pc, out.state]
    end
    
    # It pops {#stack} until it finds a {RescuePoint}, restores this {VM} state
    # from the {RescuePoint} and pops the {RescuePoint}.
    # 
    # @return [Boolean] true if the {RescuePoint} is found and false otherwise.
    def rescue_
      vm.stack.pop until vm.stack.empty? or vm.stack.last.is_a? VM::RescuePoint
      if vm.stack.empty? then
        false
      else
        rescue_point = vm.stack.pop
        self.pc = rescue_point.return_pc
        self.out.state = rescue_point.out_state
        true
      end
    end
    
    ReturnPoint = Struct.new :return_pc
    
    RescuePoint = Struct.new :return_pc, :out_state
    
    class Label
      
      def initialize
        @address = nil
      end
      
      # @return [Integer, nil]
      attr_accessor :address
      
    end
    
  end
  
end