require 'rake/testtask'
require 'rake/rdoctask'

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
  t.rdoc_files.include('README')
  t.rdoc_files.include('lib/**/*.rb')
end

desc "Builds a Debian package"
task :debian do
  sh 'dpkg-buildpackage -us -uc'
end
