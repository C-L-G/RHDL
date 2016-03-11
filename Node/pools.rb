require "poolslot.rb"
require "parsepool_verb.rb"
require "parseresult.rb"
class TestPools
## Atom Pool
block_id = AtomPool.new(name:"block_id",re:/\A\w+\s/)
vari_id = AtomPool.new(name:"varible_id",re:/\A\w+\s/)
@@one_line_comment = AtomPool.new(name:"one_line_comment",re:/\A\/\/.*?\n/)
@@mul_lines_comment = AtomPool.new(name:"mul_lines_comment",re:/\A\/\*.*?\*\//m)
pri1_symbol_pool = AtomPool.new(name:'symbol',re:/\A(?:\*\*|\*|%|\+|-|\/|==|!=)/);symbol.discontinue = true
pre_symbol_pool = AtomPool.new(name:'pre_symbol',re:/\A(?:~)/);pre_symbol.discontinue=true
comma = AtomPool.new(name:'comma',re:/\A,/);comma.discontinue=true
close_block_with_name = AtomPool.new(name:'close_block_with_name',re:/(?:\A:\s*(?<name>\w+)\s|\s)/);
close_block_with_name.discontinue=true,match_space:true
##
## Pool
close_block_with_name_slot = PoolSlot.new(pool:close_block_with_name,force:nil)

def self.define_frame_pools(*names)
    names.each do |item|
        new_pool = ParsePool.new(name:item.to_s)
        new_pool.begin_contain(Regexp.new("\\A#{item.to_s}\\s"),block_id)
        new_pool.end_contain(Regexp.new("\\Aend#{item.to_s}"),close_block_with_name_slot)
        new_pool.sub_contain(@@one_line_comment,@@mul_lines_comment)
        class_variable_set("@@"+item.to_s+'_pool',new_pool)
        self.class.send :define_method,(name.to_s+'_pool'),Proc.new { class_variable_get('@@'+name.to_s+'_pool')}
    end
end

def self.define_couple_pool(name,left,right)
    new_pool = ParsePool.new(name:name)
    new_pool.begin_contain(left)
    new_pool.end_contain(right)
    new_pool.sub_contain(@@one_line_comment,@@mul_lines_comment)
    class_variable_set("@@"+item.to_s+'_pool',new_pool)
    self.class.send :define_method,(name.to_s+'_pool'),Proc.new { class_variable_get('@@'+name.to_s+'_pool')}
end

## rebuid sub_contain
=begin
ParsePool.class_eval do
    alias :super_sub_contain,:sub_contain
end
ParsePool.define_method :sub_contain do |*pools|
    new_pools = pools | [one_line_comment,mul_lines_comment]
    super_sub_contain(*new_pools)
end
=end
##

define_frame_pools :module,:parameter,:interface,:always_c,:always_f,:localparam
define_couple_pool "parenthese",/\A\(/,/\A\)/
define_couple_pool "square_brackets",/\A\[/,/\A\]/
define_couple_pool "brace",/\A\{/,/\A\}/
## varaible build
variable_pool = ParsePool.new(name:"varible_id")
variable_pool.begin_contain(varible_id)
variable_pool.sub_contain(@@one_line_comment,@@mul_lines_comment,define_couple_pool)

implict_variable_pool = ParsePool.new(name:"implict_variable")
implict_variable_pool

all_variable_pool = TwinPool.new(name:"all_variable",twinpools:[variable_pool,parenthese_pool,brace_pool])
## pri0  ##
pri0_pool = ParsePool.new(name:"priority_0_operator")
pri0_pool.begin_contain(pre_symbol,all_variable_pool.new(:match_space:true))
##
## implict_variable ##
### level 1 variable ###
level1_variable_pool = TwinPool.new(name:"level_1_variable",twinpools:[all_variable_pool,pri0_pool])
###
### priority 1 opretor ###
pri1_pool = ParsePool.new(name:"priority_1_operator")
pri1_pool.begin_contain(level1_variable_pool,pri1_symbol_pool,
                        TwinPool.new(name:"priority_1_operator_next",twinpools:[pri1_pool,level1_variable_pool]))
pri1_pool.generic_subs = [@@one_line_comment,@@mul_lines_comment]
##
level2_variable_pool = TwinPool.new(name:"level_2_variable",twinpools:[all_variable_pool,pri0_pool,pri1_pool])
pri2_pool.begin_contain(level2_variable_pool,pri2_symbol_pool,
                        TwinPool.new(name:"priority_1_operator_next",twinpools:[pri2_pool,level2_variable_pool]))
pri2_pool.generic_subs = [@@one_line_comment,@@mul_lines_comment]
## range ##
single_index_square_brackets_pool = define_couple_pool.clone
single_index_square_brackets_pool.sub_contain(all_variable_pool.new(force:true,discontinue:true,count:1))
range_pool = ParsePool.new(name:"range")
range_pool.begin_contain(all_variable_pool)
module_pool.sub_contain interface_pool,parameter_pool,localparam_pool,always_c_pool,always_f_pool



end
