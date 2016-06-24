require 'restorable_output'
require 'stringio'

module RestorableOutput
  
  # {RestorableOutput} which uses in-memory buffer.
  class MemoryBuffered
    
    include RestorableOutput
    
    # @param [IO] io
    def initialize(io)
      @io = io
      @buffer = StringIO.new
    end
    
    # @param (see RestorableOutput#write)
    # @return (see RestorableOutput#write)
    def write(str)
      @buffer.write(str)
    end
    
    # @param (see RestorableOutput#state)
    # @return (see RestorableOutput#state)
    def state
      @buffer.pos
    end
    
    # @param (see RestorableOutput#state=)
    # @return (see RestorableOutput#state=)
    def state=(s)
      @buffer.pos = s
    end
    
    # @param (see RestorableOutput#close)
    # @return (see RestorableOutput#close)
    def close
      n = @buffer.pos
      @buffer.pos = 0
      IO.copy_stream(@buffer, @io, n)
      @io.close
    end
    
  end
  
end
