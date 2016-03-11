require "poolslot.rb"
require "parsepool_verb.rb"
require "parseresult.rb"
class TestPools
block_id = AtomPool.new(name:"block_id",re:/\A\w+\s/)
one_line_comment = AtomPool.new(name:"one_line_comment",re:/\A\/\/.*?\n/)
block_id = AtomPool.new(name:"block_id",re:/\A\w+\s/)
end
