require 'rake/testtask'
require 'rake/rdoctask'
require 'rake/packagetask'

Rake::TestTask.new('test:unit') do |t|
  t.libs << "test"
  t.test_files = FileList['test/unit/**/*.rb']
  t.verbose = true
end

desc "Compilation of external resources"
task :prepare do
  sh 'make -C lib/utils'
  sh 'make -C lib/utils clean'
end

desc "Generate basic Documentation"
Rake::RDocTask.new do |t|
  t.rdoc_dir = 'doc'
  t.title    = 'Wrekavoc'
  t.options << '--line-numbers'
  t.options << '--charset' << 'utf-8'
  t.options << '--diagram'
  t.rdoc_files.include('README')
  t.rdoc_files.include('lib/**/*.rb')
end


desc "Run basic tests"
Rake::TestTask.new("test_units") { |t|
  t.pattern = 'test/test_*.rb'
  t.ruby_opts = ['-rubygems'] if defined? Gem
  t.verbose = true
  t.warning = true
}

desc "Generate source tgz package"
Rake::PackageTask::new("wrekavoc","0.1") do |p|
  p.need_tar_gz = true
  p.package_files.include('lib/**/*')
  p.package_files.include('bin/**/*')
  p.package_files.include('test/**/*')
  p.package_files.include('Rakefile', 'COPYING','README','TODO')
end

desc "Generate the REST API Documentation"
task :doc_netapi do
  $LOAD_PATH.unshift File.join(File.dirname(__FILE__),'lib')
  require 'docapi'
  require 'rdoc/generator/docapi'
  Docapi::CLI.new.generate(["lib/wrekavoc/netapi/server.rb"], "doc/netapi")
  system('scripts/gendoc-netapi.sh')
end

desc "Builds a Debian package"
task :debian do
  sh 'dpkg-buildpackage -us -uc'
end
