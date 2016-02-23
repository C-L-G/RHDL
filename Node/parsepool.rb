class ParsePool
    @@origin_str = ''
    @@processed_str = ''
    @@level_index = 0
    @@curr_subpools  = nil
    @@curr_subpools_closure = nil

    attr_accessor :inherit_subpools
    def initialize(begin_re,end_re=nil,pro_level=:PARSE,name = 'DEFAULT')
        if begin_re.is_a? String
            @begin_re = Regexp.new(begin_re)
        else
            @begin_re = begin_re
        end
        if end_re.is_a? String
            @end_re  = Regexp.new(end_re)
        else
            @end_re = end_re
        end
        @begin_seq_pool = []   ## pool array [pool,count,force]
        @end_seq_pool = [] ## pool array [pool,count,force]
        @subpools = [] ## pool array [pool,count,force,continue]
        @curr_execute_closure = []
        @curr_end_exe_closure = []
        @level = pro_level
        @inherit_subpools = nil
        @name = name
    end

    def self.origin_string(str)
        @@origin_str = str
    end

    def self.add_public_subpools_to(*args)
        args.each do |pool|
            pool.add_public_subpools
        end
    end

    def add_curr_execute(&block)
        @curr_execute_closure << block
    end

    def add_seq_to(direct=:begin,pool=nil,cnt=nil,force=true)
        if direct == :begin
            @begin_seq_pool << [pool,cnt,force]
        elsif direct == :end
            @end_seq_pool << [pool,cnt,force]
        end
    end

    def add_subpool (pool=nil,count=nil,force=false,discontinue=false)
        @subpools.delete_if do |item|
            item[0] == pool
        end
        @subpools << [pool,count,force,discontinue]
    end
    def parse
        unless match
            raise "无法解析错误:"+(@@origin_str.lstrip)[0..9]+'...'
        end
        return @@origin_str
    end

    def can_parse?
        unless match
            return nil
        end
        return @@origin_str
    end

    def try_parse
        match
        @@origin_str
    end

    def match_begin
        $~ = nil
        cmatch = nil
        @@origin_str.sub!(@begin_re) do |mstr|
            cmatch = $~
            if @level == :pre_parse
                @@processed_str << "<<<LEVEL_PRE_PARSE_#{@@level_index}>>>"+mstr
                @curr_level_index = @@level_index
                @@level_index += 1
            else
                @@processed_str << mstr
            end
            ''
        end
        return nil unless cmatch
        ##execute current closure
        curr_mch_avgs = cmatch[1,@begin_re.names.length]
        @curr_execute_closure.each do |item|
            item.call(*curr_mch_avgs)
        end
        @@origin_str
    end

    def match_end
        p @name
        p @@origin_str
        unless @end_re
            @@processed_str << "<<<END_LEVEL_PRE_PARSE_#{@curr_level_index}>>>"
            return @@origin_str
        end
        $~ = nil
        cmatch = nil
        @@origin_str.sub!(@end_re) do |mstr|
            cmatch = $~
            if @level == :pre_parse
                @@processed_str << mstr+"<<<END_LEVEL_PRE_PARSE_#{@curr_level_index}>>>"
                @@level_index += 1
            else
                @@processed_str << mstr
            end
            ''
        end
        return nil unless $~
        ##execute current closure
        curr_mch_avgs = cmatch[1,@end_re.names.length]
        @curr_end_exe_closure.each do |item|
            item.call(*curr_mch_avgs)
        end
        @@origin_str
    end

    def set_envs
        if inherit_subpools
             @subpools << @@curr_subpools
             @curr_execute_closure << @@curr_subpools_closure
         else
             @@curr_subpools = @subpools
             @@curr_subpools_closure = @curr_execute_closure
         end
     end

     def reset_envs
         unless inherit_subpools
             @@curr_subpools = @subpools
             @@curr_subpools_closure = @curr_execute_closure
         end
     end

    def match
        ## compact str
        if @@origin_str[0] =~ /\s/
            @@origin_str.sub!(/^\s+/m) do |mstr|
                @@processed_str << mstr
                ''
            end
        end
        ## set subpools
        set_envs
        ##cstr = str.lstrip
        ##execute match begin
        return nil unless match_begin
        ##excute match begin sequence
        @begin_seq_pool.each do |item|
            if item[1].integer?
                loop_times = item[1]
            else
                loop_times = 1
            end
            (loop_times).times do
                if item[2]
                    item[0].parse
                else
                    item[0].try_parse
                end
            end
        end
        ##excute match subpools
        parse_execute = nil
        force_execute = nil
        continue_execute = nil
        subpools_count = @subpools.map{|item| item[1]}
        subpools_force = @subpools.map{|item| item[2]}
        last_parse_sub = nil
        begin
            parse_execute = nil
            @subpools.each_index do |index|
                parse_str_res = @subpools[index][0].can_parse?
                if parse_str_res
                    parse_execte = true
                    if subpools_count[index].integer?
                        raise "多次解析错误:"+(@@origin_str.lstrip)[0..9]+'...' unless subpools_count[index] > 0
                        subpools_count[index] -= 1
                    end
                    if subpools_force[index]    ## force
                        subpools_force[index]   = nil
                    end
                    if last_parse_sub == index
                        raise "连续解析错误:"+(@@origin_str.lstrip)[0..9]+'...' if @subpools[index][3]
                    end
                    last_parse_sub = index
                else
                    parse_execute = parse_execute
                    if @subpools[index][2]    ## force
                        @subpools[index][2]   = nil
                    end
                end
            end
        end while parse_execute
        raise "没有解析错误:"+(@@origin_str.lstrip)[0..9]+'...' if subpools_force.include?(true)
        ##execute end match
        raise "结尾异常:"+(@@origin_str.lstrip)[0..9]+'...' unless match_end
        ##excute match end sequence
        @end_seq_pool.each do |item|
            if item[1].integer?
                loop_times = item[1]
            else
                loop_times = 1
            end
            (loop_times).times do
                if item[2]
                    cstr_res = item[0].parse
                else
                    cstr_res = item[0].try_parse
                end
            end
        end
        ## reset subpools
        reset_envs
        @@origin_str
    end

end

## field define
module_field = ParsePool.new(/^module\s/,/^endmodule\b/)
id_name = ParsePool.new(/^\w+/)
one_line_comment = ParsePool.new(/^\/\//,/.*?\n/)
mul_lines_comment = ParsePool.new(/^\/\*/,/.*?\*\//m)
interface_field = ParsePool.new(/^interface\s/,/^endinterface\b/)
parameter_field = ParsePool.new(/^parameter\b/,/^endparameter\b/)
localparam_field = ParsePool.new(/^localparam\b/,/^endlocalparam\b/)
ff_block_field = ParsePool.new(/^ffblock\b/,/^endff\b/)
comb_block_field = ParsePool.new(/^comb\b/,/^endcomb\b/)
macro_if_field = ParsePool.new(/^\`IF/,/^\`ENDIF/,:pre_parse)
macro_else_field = ParsePool.new(/^\`ELSE/,nil,:pre_parse)
macro_elsif_field = ParsePool.new(/^\`ELSIF/,nil,:pre_parse)
io_field = ParsePool.new(/^(?-i:input|output|inout)\b/)
range_field = ParsePool.new(/^\[/,/^\]/)
range_symb = ParsePool.new(/^(?::|-:|\+:)/)
symbol_field = ParsePool.new(/^(?:\*\*|\*|%|\+|-|\/|==|!=)/)
pre_symbol_field = ParsePool.new(/^(?:~)/)
parenthese_field = ParsePool.new(/^\(/,/^\)/)

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

AAA = "pppppppppp"

ParsePool.add_public_subpools_to(   module_field,
                                    interface_field,
                                    parameter_field,
                                    localparam_field,
                                    ff_block_field,
                                    comb_block_field,
                                    io_field,
                                    range_field,
                                    parenthese_field)
