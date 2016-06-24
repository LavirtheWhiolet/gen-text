require 'restorable_output'

# To disable YARD warnings:
# @!parse
#   class IO
#   end

#
module RestorableOutput
  
  # {RestorableOutput} which has non-working {#state=} method.
  # It writes all data directly to {IO} passed to it.
  class NonRestorable
    
    include RestorableOutput
    
    # @param [IO] io
    def initialize(io)
      @io = io
    end
    
    # @param (see RestorableOutput#write)
    # @return (see RestorableOutput#write)
    def write(str)
      @io.write(str)
    end
    
    # @param (see RestorableOutput#state)
    # @return (see RestorableOutput#state)
    def state
      nil
    end
    
    # @param (see RestorableOutput#state=)
    # @return (see RestorableOutput#state=)
    def state=(s)
      raise "this is non-restorable output"
    end
    
    # @param (see RestorableOutput#close)
    # @return (see RestorableOutput#close)
    def close
      @io.close
    end
    
  end
  
end
