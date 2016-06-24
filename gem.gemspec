
Gem::Specification.new do |s|
  s.name        = 'gen-text'
  s.version     = '0.0.1'
  s.licenses    = ['MIT']
  s.summary     = "A generator of texts from EBNF-like grammars."
  s.author      = "Lavir the Whiolet"
  s.email       = 'Lavir.th.Whiolet@gmail.com'
  s.required_ruby_version = '>= 1.9.3'
  s.files       = Dir["lib/**/*.rb"] +
                  ["README.md", "LICENSE", ".yardopts", "yardopts_extra.rb"]
  s.bindir      = "bin"
  s.homepage    = "http://lavirthewhiolet.github.io/gen-text"
  s.executables << "gen-text"
end
