$: << File::dirname(File::expand_path(__FILE__))

require "parseresult.rb"
require "DNA.rb"

file_name = File.join(File::dirname(File::expand_path(__FILE__)),"example_hdl.v")

origin_rel = ParseResult.new(origin:File.open(File.expand_path(file_name)).read)

TestPoolSeqs.new.exec_test(origin_rel)
