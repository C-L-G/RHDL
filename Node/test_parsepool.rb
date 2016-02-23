$: << File::dirname(File::expand_path(__FILE__))

load "parsepool.rb",false

file_name = File.join(File::dirname(File::expand_path(__FILE__)),"example_hdl.v")

ParsePool.origin_string File.open(File.expand_path(file_name)).read

## field define
module_field = ParsePool.new(/\Amodule\s/,/\Aendmodule\b/,:parse,name = "module")
id_name = ParsePool.new(/\A\w+/,nil,:parse,name = "ID")
one_line_comment = ParsePool.new(/\A\/\//,/.*?\n/)
mul_lines_comment = ParsePool.new(/\A\/\*/,/.*?\*\//m)
interface_field = ParsePool.new(/\Ainterface\s/,/\Aendinterface\b/,nil,name="interface")
parameter_field = ParsePool.new(/\Aparameter\b/,/\Aendparameter\b/)
localparam_field = ParsePool.new(/\Alocalparam\b/,/\Aendlocalparam\b/)
ff_block_field = ParsePool.new(/\Affblock\b/,/\Aendff\b/)
comb_block_field = ParsePool.new(/\Acomb\b/,/\Aendcomb\b/)
macro_if_field = ParsePool.new(/\A\`IF/,/\A\`ENDIF/,:pre_parse)
macro_else_field = ParsePool.new(/\A\`ELSE/,nil,:pre_parse)
macro_elsif_field = ParsePool.new(/\A\`ELSIF/,nil,:pre_parse)
io_field = ParsePool.new(/\A(?-i:input|output|inout)\b/)
range_field = ParsePool.new(/\A\[/,/\A\]/)
range_symb = ParsePool.new(/\A(?::|-:|\+:)/)
symbol_field = ParsePool.new(/\A(?:\*\*|\*|%|\+|-|\/|==|!=)/)
pre_symbol_field = ParsePool.new(/\A(?:~)/)
parenthese_field = ParsePool.new(/\A\(/,/\A\)/)

ParsePool.class_eval do
    define_method "add_public_subpools" do
        add_subpool(pool=macro_if_field,count=nil,force=nil,discontinue=nil)
        add_subpool(pool=one_line_comment,count=nil,force=nil,discontinue=nil)
        add_subpool(pool=mul_lines_comment,count=nil,force=nil,discontinue=nil)
    end
end
## module ##
module_field.add_seq_to :begin,id_name,1,:force
module_field.add_subpool(pool=macro_if_field,count=nil,force=nil,discontinue=nil)
module_field.add_subpool(pool=interface_field,count=1,force=nil,discontinue=nil)
module_field.add_subpool(pool=parameter_field,count=nil,force=nil,discontinue=nil)
module_field.add_subpool(pool=localparam_field,count=nil,force=nil,discontinue=nil)
module_field.add_subpool(pool=ff_block_field,count=nil,force=nil,discontinue=nil)
module_field.add_subpool(pool=comb_block_field,count=nil,force=nil,discontinue=nil)
## interface ##
interface_field.add_seq_to :begin,id_name,1,:force
interface_field.add_subpool(pool=io_field,count=nil,force=nil,discontinue=nil)
## parameter
parameter_field.add_seq_to :begin,id_name,1,:force
## localparam
localparam_field.add_seq_to :begin,id_name,1,:force
## ff_block
ff_block_field.add_seq_to :begin,id_name,1,:force
## comb_block
ff_block_field.add_seq_to :begin,id_name,1,:force
## MACRO ##
macro_if_field.add_seq_to :begin,id_name,1,:force
macro_if_field.add_subpool(pool=macro_if_field,count=nil,force=nil,discontinue=nil)
macro_if_field.add_subpool(pool=macro_elsif_field,count=nil,force=nil,discontinue=nil)
macro_if_field.add_subpool(pool=macro_else_field,count=nil,force=nil,discontinue=true)
macro_if_field.inherit_subpools = true
## io ##
## RANGE ##
range_field.add_subpool(pool=symbol_field,count=nil,force=nil,discontinue=true)
range_field.add_subpool(pool=id_name,count=nil,force=nil,discontinue=true)
range_field.add_subpool(pool=range_symb,count=1,force=true,discontinue=true)
## -> ##
## symbol ##
## parenthese ##
parenthese_field.add_subpool(pool=symbol_field,count=nil,force=nil,discontinue=true)
parenthese_field.add_subpool(pool=id_name,count=nil,force=nil,discontinue=true)
parenthese_field.add_subpool(pool=range_field,count=nil,force=nil,discontinue=true)
## add_public_subpools_t

ParsePool.add_public_subpools_to(   module_field,
                                    interface_field,
                                    parameter_field,
                                    localparam_field,
                                    ff_block_field,
                                    comb_block_field,
                                    io_field,
                                    range_field,
                                    parenthese_field)


module_field.parse
