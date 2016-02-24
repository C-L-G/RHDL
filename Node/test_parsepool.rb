$: << File::dirname(File::expand_path(__FILE__))

require "parsepool.rb"

file_name = File.join(File::dirname(File::expand_path(__FILE__)),"example_hdl.v")

ParsePool.origin_string File.open(File.expand_path(file_name)).read

TestPool.new.exec_test
