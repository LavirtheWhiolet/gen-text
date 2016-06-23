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
      @remembered_pos = nil
    end
    
    # (see RestorableOutput#write)
    def write(str)
      @buffer.write(str)
    end
    
    # (see RestorableOutput#remember)
    def remember(&block)
      old_remembered_pos = @remembered_pos
      @remembered_pos = @buffer.pos
      begin
        return block.()
      ensure
        @remembered_pos = old_remembered_pos
      end
    end
    
    # (see RestorableOutput#restore)
    def restore
      @buffer.pos = @remembered_pos
    end
    
    # (see RestorableOutput#close)
    def close
      n = @buffer.pos
      @buffer.pos = 0
      IO.copy_stream(@buffer, @io, n)
      @io.close
    end
    
  end
  
end
