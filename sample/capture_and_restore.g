
program =
  (
    n:10 " "
  )
  (
    / "abc" n:20 "def" {?false}
    / {=n}
  )
  "\n"
  ;

/* 
 * Sample output:
 * 
 *   10 10
 */
