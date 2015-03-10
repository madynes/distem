require 'rubygems'
require 'rake/testtask'
require 'rdoc/task'
require 'rake/packagetask'

DISTEM_VERSION='1.0'

begin
  require 'rake/extensiontask'

  Rake::ExtensionTask.new do |ext|
    ext.name = 'cpuhogs'
    ext.ext_dir = 'ext/distem/cpuhogs'
    ext.lib_dir = 'lib/ext'
  end

  Rake::ExtensionTask.new do |ext|
    ext.name = 'cpugov'
    ext.ext_dir = 'ext/distem/cpugov'
    ext.lib_dir = 'lib/ext'
  end

  Rake::ExtensionTask.new do |ext|
    ext.name = 'rngstream'
    ext.ext_dir = 'ext/distem/rngstream'
    ext.lib_dir = 'lib/ext'
  end
  
rescue LoadError
  puts "You need the 'rake-compiler' to build extensions from the Rakefile"
end

Rake::TestTask.new('test:unit') do |t|
  t.libs << "test"
  t.test_files = FileList['test/**/*.rb']
  t.verbose = true
end

desc "Generate basic Documentation"
Rake::RDocTask.new do |t|
  t.rdoc_dir = 'doc'
  t.title    = 'Distem'
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
Rake::PackageTask::new("distem",DISTEM_VERSION) do |p|
  p.need_tar_gz = true
  p.package_files.include('lib/**/*')
  p.package_files.include('ext/**/*')
  p.package_files.include('bin/**/*')
  p.package_files.include('test/**/*')
  p.package_files.include('Rakefile', 'COPYING','README')
end

begin
  require 'yard/sinatra'
  require 'nokogiri'
  desc "Generate the YARD documentation"
  task :yard do
    system("yard --plugin 'sinatra' doc --title \"YARD documentation for distem #{DISTEM_VERSION}\" --files files/resources_desc.md --list-undoc")
    if File::directory?('../distem-private/www/doc/')
      # edit *.html and remove footer to avoid the date that will change on each
      # generation of the docs.
      Dir['doc/**/*.html'].each do |f|
        doc = Nokogiri::HTML::Document::parse(IO::read(f))
        footer = doc.at_css("div#footer")
        footer.remove unless footer.nil?
        File::open(f, 'w') do |fd|
          fd.puts doc
        end
      end
      puts "\n\nCopying to ../distem-private/www/doc/..."
      system("rsync -a doc/ ../distem-private/www/doc/")
      puts "Remember to use git add -f (.html ignored by default)"
    end
    # cleanup
    system("rm -rf .yardoc")
  end
rescue LoadError
  puts "yard-sinatra or nokogiri not found. Cannot generate documentation."
end

desc "Generate the REST API Documentation"
task :doc_netapi do
  $LOAD_PATH.unshift File.join(File.dirname(__FILE__),'lib')
  require 'docapi'
  require 'rdoc/generator/docapi'
  Docapi::CLI.new.generate(["lib/distem/netapi/server.rb"], "doc/netapi")
  system('scripts/gendoc-netapi.sh')
end

desc "Builds a Debian package"
task :debian do
  sh 'dpkg-buildpackage -us -uc'
end

desc "Builds a git snapshot package"
task :snapshot do
  sh 'cp debian/changelog debian/changelog.git'
  date = `date --iso=seconds |sed 's/+.*//' |sed 's/[-T:]//g'`.chomp
  sh "sed -i '1 s/)/+git#{date})/' debian/changelog"
  sh 'dpkg-buildpackage -us -uc'
  sh 'mv debian/changelog.git debian/changelog'
end

desc "Build the last distem package built inside sbuild"
task :sbuild do
  pkg = `cd .. ; ls distem*dsc | tail -1`.chomp

  Dir::chdir('..') do
    sh "sbuild -d distem32 --arch i386 #{pkg}"
    sh "sbuild -d distem64 #{pkg}"
  end
end

desc "Generate the manpages using help2man"
task :man do
  (Dir['bin/*'] + ['scripts/distem-bootstrap', 'scripts/distem-devbootstrap']).each do |f|
    FileUtils.mkdir_p('man')
    # This hack is required so that the executables can find the extension and load them
    ENV['RUBYLIB'] = File.join(File.dirname(__FILE__), 'debian', 'distem', Config::CONFIG['vendorarchdir'])
    system("help2man --no-info --version-string='#{DISTEM_VERSION}' #{f} > man/#{File.basename(f)}.1")
    system("man -Hcat man/#{File.basename(f)}.1 | sed 's/&minus;/-/g' > man/#{File.basename(f)}.html")
  end
  if File::directory?('../distem-private/www/man/')
    # edit *.html and remove footer to avoid the date that will change on each
    # generation of the docs.
    puts "\n\nCopying to ../distem-private/www/man/..."
    system("rsync -a man/*.html ../distem-private/www/man/")
    puts "Remember to use git add -f (.html ignored by default)"
  end
end

desc "Reindent everything"
task :reindent do
  system('find bin lib -type f -exec vim -s .vim-reindent {} \;')
end

desc "Find patterns that confuse vim"
task :makevimfriendly do
  Dir['**/*.rb'].each do |f|
    if IO::read(f) =~ /\\\n\s*(unless|if)/
      puts f
    end
  end
end
