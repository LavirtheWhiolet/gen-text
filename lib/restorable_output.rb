
module RestorableOutput
  
  # @!method state
  #   @abstract
  #   @return [Object]
  
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
  
  # @!method state=(s)
  #   @abstract
  #   @param [Object] s the state returned by {#state}.
  #   @return [void]
  
end
