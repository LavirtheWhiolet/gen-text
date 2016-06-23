level = 0
STDIN.read.chars.each do |c|
  case c
  when '(' then level += 1
  when ')' then level -= 1
  end
end
puts level
