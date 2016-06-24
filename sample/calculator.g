/* Simple arithmetic expressions */

prog =
  expr '\n'
  ;

expr =
  | expr ('+'|'-') expr
  | expr ('*'|'/') expr
  | '(' expr ')'
  | [50%] number
  ;

number =
  0...1000
  ;
