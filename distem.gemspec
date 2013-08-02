Gem::Specification.new do |s|
  s.name               = "distem"
  s.version            = open('Rakefile') { |f| f.grep(/^DISTEM_VERSION/) }.first.strip.split('=')[1].delete("'")
  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Luc Sarzyniec","Lucas Nussbaum","Emmanuel Jeanvoine"]
  s.date = Time.now.to_s.split(' ')[0]
  s.description = <<-EOS
Distem is a distributed systems emulator. When doing research on Cloud, P2P, High Performance Computing or Grid systems, it can be used to transform an homogenenous cluster (composed of identical nodes) into an experimental platform where nodes have different performance, and are linked together through a complex network topology, making it the ideal tool to benchmark applications targetting such environments.
EOS
  s.email = ['luc.sarzyniec@inria.fr', 'lucas.nussbaum@loria.fr', 'emmanuel.jeanvoine@inria.fr']
  s.executables = ['distem','distemd']
  s.files = Dir.glob('lib/**/*.rb') + Dir.glob('ext/**/*.{c,h,rb}')
  s.extensions = Dir.glob('ext/**/extconf.rb')
  s.homepage = 'http://distem.gforge.inria.fr/'
  s.require_paths = ["lib"]
  s.summary = 'Distem'
  s.add_runtime_dependency 'rest-client'
  s.add_runtime_dependency 'ipaddress'
  s.add_runtime_dependency 'sinatra'
  s.add_runtime_dependency 'json'
  s.add_runtime_dependency 'net-ssh'

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
    else
    end
  else
  end
end
