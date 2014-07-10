Gem::Specification.new do |s|
  s.name        = 'sinatra-redis-cache'
  s.version     = '0.1'
  s.licenses    = ['MIT']
  s.summary     = 'A simple redis backed cache for Sinatra'
  s.description = 'A simple redis backed cache for Sinatra'
  s.authors     = ['Warren Guy']
  s.email       = 'warren@guy.net.au'
  s.homepage    = 'https://github.com/warrenguy/sinatra-redis-cache'

  s.files       = Dir['README.md', 'lib/**/*']

  s.add_dependency('sinatra', '~> 1.3')
  s.add_dependency('rake',    '~> 10.0')
  s.add_dependency('redis',   '~> 3.0')
end
