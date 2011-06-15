require 'rake/testtask'
require 'rake/rdoctask'
require 'rake/packagetask'

Rake::TestTask.new('test:unit') do |t|
  t.libs << "test"
  t.test_files = FileList['test/unit/**/*.rb']
  t.verbose = true
end

Rake::RDocTask.new do |t|
  t.rdoc_dir = 'doc'
  t.title    = 'Wrekavoc'
  t.options << '--line-numbers'
  t.options << '--charset' << 'utf-8'
  t.options << '--diagram'
  t.rdoc_files.include('README')
  t.rdoc_files.include('lib/**/*.rb')
end

Rake::PackageTask::new("wrekavoc","0.1") do |p|
  p.need_tar_gz = true
  p.package_files.include('lib/**/*')
  p.package_files.include('bin/**/*')
  p.package_files.include('test/**/*')
  p.package_files.include('Rakefile', 'COPYING','README','TODO')
end

desc "Generate the documentation of the REST API"
task :doc_netapi do
  $LOAD_PATH.unshift File.join(File.dirname(__FILE__),'lib')
  require 'docapi'
  require 'rdoc/generator/docapi'
  Docapi::CLI.new.generate(["lib/wrekavoc/netapi/server.rb"], "doc/netapi")
end

desc "Builds a Debian package"
task :debian do
  sh 'dpkg-buildpackage -us -uc'
end
