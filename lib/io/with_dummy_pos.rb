
class IO
  
  # {IO} with {IO#pos} returning invalid value.
  class WithDummyPos
    
    def self.new(io)
      def io.pos
        0
      end
      return io
    end
    
  end
  
  # To disable YARD warnings:
  #@!method pos
  #@!method pos=(p)
  
end
