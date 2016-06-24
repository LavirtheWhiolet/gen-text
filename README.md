Description
-----------

A generator of random texts based on EBNF-like grammars.

Install
-------

- Install [Ruby](http://ruby-lang.org) 1.9.3 or higher.
- `gem install gen-text`

Usage
-----

Run it with the command:

    gen-text file.g

Here `file.g` is a file containing the grammar description which consists of the rule definitions:

    nonterminal1 = expr1 ;
    
    nonterminal2 = expr2 ;
    
    nonterminal3 = expr3 ;
    
Nonterminals start from a letter or "\_" and may contain alphanumeric characters, "\_", "-" and ":".

You may also use backquoted nonterminals:
    
    `nonterminal1` = expr1 ;
    
    `Nonterminal with arbitrary characters: [:|:]\/!` = expr2 ;

Trailing ";" can be omitted:

    nonterminal1 = expr1
    
    nonterminal2 = expr2
    
    nonterminal3 = expr3

Also you may omit the left part in the first rule:

    expr1
    
    nonterminal2 = expr2
    
    nonterminal3 = expr3

### Expressions ###

You may use the following expressions in the rules' right part:

<table>
  <thead>
    <tr> <td><strong>Expression</strong></td> <td><strong>Meaning</strong></td> </tr>
  </thead>
  <tbody>
    <tr>
      <td>
        <tt>"str"</tt><br/>
        <tt>'str'</tt>
      </td>
      <td>
        <p>Generate a string.</p>
        <p>Following escape sequences are allowed: "\n", "\t", "\e" and "\." where "." is an arbitrary character.</p>
      </td>
    </tr>
    <tr>
      <td><tt>U+HHHH</tt></td>
      <td>Generate an UTF-8 character sequence corresponding to the Unicode code. E. g.: <tt>U+000A</tt> is equivalent to <tt>"\n"</tt>.</td>
    </tr>
    <tr>
      <td><tt>n</tt> (a number)</td>
      <td>Generate a number</td>
    </tr>
    <tr>
      <td><tt>m...n</tt></td>
      <td>Generate a random number between <tt>m</tt> and <tt>n</tt> (inclusive).</td>
    </tr>
    <tr>
      <td><tt>nonterm</tt></td>
      <td>–</td>
    </tr>
    <tr>
      <td colspan="2"><center><strong>Combinators</strong></center></td>
    </tr>
    <tr>
      <td> <tt>expr expr</tt> </td>
      <td>Sequence.</td>
    </tr>
    <tr>
      <td>
        <tt>expr | expr</tt>
      </td>
      <td>Random choice.</td>
    </tr>
    <tr>
      <td>
        <tt>
          | expr <br/>
          | expr
        </tt>
      </td>
      <td>Random choice (another form).</td>
    </tr>
    <tr>
      <td>
        <tt>
          | [m%] expr <br/>
          | [n%] expr <br/>
          | expr
        </tt>
      </td>
      <td>
        <p>Random choice with specific probabilities.</p>
        <p>If probability is unspecified then it is calculated automatically.</p>
      </td>
    </tr>
    <tr>
      <td>
        <tt>
          | [0.1] expr <br/>
          | [0.3] expr <br/>
          | expr
        </tt>
      </td>
      <td>
        The same as above. Probabilities may be specified as floating point numbers between 0.0 and 1.0.
      </td>
    </tr>
    <tr>
      <td>
        <tt>expr*</tt> <br/>
        <tt>expr+</tt> <br/>
        <tt>expr?</tt> <br/>
        <tt>expr*[n]</tt> <br/>
        <tt>expr*[m...n]</tt> <br/>
      </td>
      <td>
        <p>Repeat <tt>expr</tt> many times:</p>
        <ul>
          <li>0 or more times</li>
          <li>1 or more times</li>
          <li>0 or 1 time</li>
          <li>exactly <tt>n</tt> times</li>
          <li>between <tt>m</tt> and <tt>n</tt> times</li>
        </ul>
        <p><strong>Note:</strong> you may use <tt>inf</tt> ("infinity") instead of <tt>m</tt> or <tt>n</tt>.</p>
      </td>
    </tr>
    <tr>
      <td colspan="2"><center><strong>Ruby code insertions</strong></center></td>
    </tr>
    <tr>
      <td><tt>{ code }</tt></td>
      <td>
        <p>Execute the code. Generate nothing.</p>
        <p><strong>Note</strong>: all code insertions inside a rule share the same scope.</p>
      </td>
    </tr>
    <tr>
      <td><tt>{= code }</tt></td>
      <td>Generate a string returned by the code.</td>
    </tr>
    <tr>
      <td><tt>{? code }</tt></td>
      <td>
        <p>Condition. A code which must evaluate to true.</p>
        <p><strong>Note</strong>: presence of this expression turns on backtracking and output buffering and may result in enormous memory usage.</p>
      </td>
    </tr>
  </tbody>
</table>

TODO: Capture the generated output.

### Alternate syntax ###

You may use "<-" instead of "=":

    nonterm1 <- expr1 ;
    
    nonterm2 <- expr2 ;

and "/" instead of "|":

    `simple choice` <- "a" / "b" ;

Examples
--------

See them in "sample" directory.

Links
-----

- [Documentation](http://www.rubydoc.info/gems/gen-text/0.0.4)
- [Source code](https://github.com/LavirtheWhiolet/gen-text)
