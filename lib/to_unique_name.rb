
# A map with automatically generated and unique values.
class ToUniqueName
  
  # @param [String] prefix
  def initialize(prefix)
    @impl = {}
    @prefix = prefix
  end
  
  # @param [Object] key
  # @return [String, nil] a String as specified in {#put} or nil if
  #   {#put}(+key+) was never called on this {ToUniqueName}.
  def [](key)
    @impl[key]
  end
  
  alias call []
  
  # @param [Object] key
  # @return [Boolean] true if {#[]}(+key+) returns non-nil and false
  #   otherwise.
  def has_key?(key)
    @impl.has_key? key
  end
  
  alias key? has_key?
  
  # For any {ToUniqueName} +m+ and Object +key+ it is true that:
  # 
  #   m.put(key);
  #   m[key] == prefix + n.to_s
  #   
  # where +prefix+ is the argument passed to {#initialize} and +n+ is a natural
  # number (as String).
  # 
  # For any {ToUniqueName} +m+ and Objects +key1+ and +key2+ it is true that
  #   
  #   m.put(key1);
  #   m.put(key2);
  #   m[key1] != m[key2]
  # 
  # See also {#[]}.
  # 
  # @param [Object] key
  # @return [self]
  def put(key)
    @impl[key] = @prefix + @impl.size.to_s
    return self
  end
  
end
