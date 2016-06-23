require 'restorable_output'

module RestorableOutput
  
  # {RestorableOutput} which has non-working {#restore} method.
  class NonRestorable
    
    include RestorableOutput
    
    # @param [IO] io
    def initialize(io)
      @io = io
    end
    
    # (see RestorableOutput#write)
    def write(str)
      @io.write(str)
    end
    
    # (see RestorableOutput#remember)
    def remember(&block)
      block.()
    end
    
    # (see RestorableOutput#restore)
    def restore
      raise "this is non-restorable output"
    end
    
    # (see RestorableOutput#close)
    def close
      @io.close
    end
    
  end
  
end
