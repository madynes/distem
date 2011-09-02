require 'mkmf'

libs=['pthread','rt']

libs.each { |lib| raise "Missing library '#{lib}'" unless have_library(lib) }

create_makefile('distem/cpuhogs')
