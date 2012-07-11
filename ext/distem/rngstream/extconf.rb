require 'mkmf'

libs=[]

libs.each { |lib| raise "Missing library '#{lib}'" unless have_library(lib) }

create_makefile('distem/rngstream')
