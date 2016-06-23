
prog =
  expr '\n'
  ;

expr =
  | expr ('+'|'-') expr
  | expr ('*'|'/') expr
  | '(' expr ')'
  | number
  ;

number =
  0.0...10000.0
  ;
