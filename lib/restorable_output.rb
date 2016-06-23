
module RestorableOutput
  
  # @!method remember(&block)
  #   @abstract
  #   
  #   Remembers the current state of self. Inside +block+ {#restore} restores
  #   self to the remembered state.
  #   
  #   {#remember} allows nested calls. Inside the most inner +block+ {#restore}
  #   restores self to the state remembered by the most inner {#remember}.
  #   
  #   @return what +block+ returns.
  
  # @!method write(str)
  #   @abstract
  #   @param [#to_s] str
  #   @return [Integer] number of bytes written.
  
  # The same as {#write} except that it returns self.
  # 
  # @param [#to_s] str
  # @return [self]
  def << str
    write(str)
    return self
  end
  
  # @!method close
  #   @abstract
  #   @return [void]
  
  # @!method restore
  #   @abstract
  #   @return [void]
  
end
