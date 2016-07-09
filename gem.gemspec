
Gem::Specification.new do |s|
  s.name        = 'gen-text'
  s.version     = '0.0.7'
  s.licenses    = ['MIT']
  s.summary     = "Random texts generator based on EBNF-like grammars."
  s.description = <<-TEXT
A generator of random texts from EBNF-like grammars. It features probability management, code insertions and conditional generation with conditions written in Ruby.
  TEXT
  s.author      = "Lavir the Whiolet"
  s.email       = 'Lavir.th.Whiolet@gmail.com'
  s.required_ruby_version = '>= 1.9.3'
  s.files       = Dir["lib/**/*.rb"] +
                  ["README.md", "LICENSE", ".yardopts", "yardopts_extra.rb"]
  s.bindir      = "bin"
  s.homepage    = "http://lavirthewhiolet.github.io/gen-text"
  s.executables << "gen-text"
  s.add_dependency "parse-framework"
end
