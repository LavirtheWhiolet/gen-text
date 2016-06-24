Description
-----------

A generator of texts from EBNF-like grammars.

Features
--------

- **Repetition, alteration, left recursion**. All features of EBNF are supported.
- **Probability management**. You may generate strings of 90% of "a"-s and 10% of "b"-s.
- **Code insertions**. Execute arbitrary code while generating the text.
- **Conditional generation**. Wanna cut some alternatives? No problem, write conditions in Ruby and you will never get the wrong texts again!
- **Virtual machine**. You may compile your grammar into some bytecode which may then be compiled to C!

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
    
Nonterminals start from a letter or "\_" and may contain alphanumeric characters, "\_", "-" or ":".

You may also use backquoted nonterminals:
    
    `nonterminal1` = expr1 ;
    
    `Nonterminal with arbitrary characters: [:|:]\/!` = expr2 ;
    
You may use the following expressions in the right part:

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
      <td>Generate an UTF-8 character sequence corresponding to the Unicode code. E. g.: <tt>U+000D</tt>.</td>
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
        
        <p>The alternatives with unspecified probability have their probability calculated automatically.</p>
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
        <p><em>Note:</em> you may use <tt>inf</tt> ("infinity") instead of <tt>m</tt> or <tt>n</tt>.</p>
      </td>
    </tr>
    <tr>
      <td colspan="2"><center><strong>Code insertions</strong></center></td>
    </tr>
    <tr>
      <td><tt>{ code }</tt></td>
      <td>
        <p>Execute the Ruby code when the generation reaches this expression.</p>
        <p><em>Note</em>: All code insertions inside a rule are executed in the same scope.</p>
      </td>
    </tr>
    <tr>
      <td><tt>{= code }</tt></td>
      <td>Generate a string returned by the Ruby code.</td>
    </tr>
    <tr>
      <td><tt>{? code }</tt></td>
      <td>
        <p>The code must evaluate to true when the generation reaches this expression.</p>
        
        <p><em>Note</em>: presence of this expression turns on output buffering and backtracking and may result in enormous memory usage.</p>
      </td>
    </tr>
  </tbody>
</table>

Examples
--------

See them in "sample" directory.

Links
-----

- [Documentation](http://www.rubydoc.info/gems/gen-text/0.0.1)
- [Source code](https://github.com/LavirtheWhiolet/gen-text)
