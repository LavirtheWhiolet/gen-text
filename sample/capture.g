
program =
  // Generate something.
  s:(0...10 '+' 0...10 " ")
  // Generate it 4 more times.
  {=s}*[4]
  "\n"
  ;

/*
 * Sample output:
 * 
 *     2+5 2+5 2+5 2+5 2+5
 * 
 */
