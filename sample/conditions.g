
expr =
  { n = 10 }
  (
    (
      | [90%] "a" {? n > 0 }
      |       "b"
    )
    { n -= 1 }
  )*[50]
  '\n'
  ;

/*
 * It generates something like:
 *    
 *    aabaaaabaabbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
 *   
 */
