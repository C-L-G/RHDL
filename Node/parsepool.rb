class ParsePool
    @@origin_str = ''
    @@processed_str = ''
    @@level_index = 0
    @@curr_exec_closure = []
    @@curr_subpools  = []

    attr_accessor :inherit_subpools,:name
    attr_reader :end_re,:begin_re
    def initialize(name:"Pool",begin_re:/\./,end_re:nil,pro_level:(:parse))
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
        @begin_seq_pool = []   ## pool array [{pool:,count:,force:,closure:}]
        @end_seq_pool = [] ## pool array [{pool:,count:,force:,closure:}]
        @subpools = [] ## pool array [ {pool:,count:,force:,continue:,closure:} ]
        @level = pro_level
        @inherit_subpools = nil
        @name = name
        @curr_begin_closure = []
        @curr_end_closure = []
        @curr_begin_closure << lambda { printf "START PARSE #{@name} --> ";p @subpools.map{|item| item[:pool].name}}
        @curr_end_closure   << lambda { puts "COMPLETE PARSE #{@name}"}
    end

    def self.origin_string(str)
        @@origin_str = str
    end

    def add_begin_execute(&block)
        @curr_begin_closure |= block
    end

    def add_end_execute(&block)
        @curr_end_closure |= block
    end

    def add_seq_to(direct:(:begin),pool:nil,count:nil,force:true,closure:nil)
        if direct == :begin
            @begin_seq_pool << {:pool=>pool,:count=>count,:force=>force,:closure=>closure}
        elsif direct == :end
            @end_seq_pool << {:pool=>pool,:count=>count,:force=>force,:closure=>closure}
        end
    end

    def add_subpool (pool: nil,count: nil,force: false,discontinue: false,closure:nil)
        @subpools.delete_if do |item|
            item[0] == pool
        end
        @subpools << {:pool=>pool,:count=>count,:force=>force,:discontinue=> discontinue,:closure=>closure}
    end

    def with_closure(*args,&block)
        @@curr_exec_closure = []
        args.each do |item|
            if item.is_a? Proc
                @@curr_exec_closure << item
            end
        end
        yield
        @@curr_exec_closure = []
    end

    def parse(*args,&block)
        closure_array = (args<<block)
        with_closure closure_array do
            unless match
                raise "无法解析错误:"+(@@origin_str.lstrip)[0..19]+'...'
            end
        end
        return @@origin_str
    end

    def can_parse?(*args,&block)
        closure_array = (args<<block)
        with_closure closure_array do
            unless match
                return nil
            end
        end
        return @@origin_str
    end

    def try_parse (*args,&block)
        closure_array = (args<<block)
        with_closure closure_array do
            match
        end
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
        (@@curr_exec_closure|@curr_begin_closure).each do |item|
            item.call(*curr_mch_avgs)
        end
        @@origin_str
    end

    def match_end
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
        @curr_end_closure.each do |item|
            item.call(*curr_mch_avgs)
        end

        @@origin_str
    end

    def set_envs
        if inherit_subpools
             @subpools |= @@curr_subpools
         else
             @up_subpools =  @@curr_subpools
             @@curr_subpools = @subpools
         end
     end

     def reset_envs
         unless inherit_subpools
             @@curr_subpools = @up_subpools
         end
     end

     def with_new_envirement(&block)
         up_subpools =  @@curr_subpools
         if inherit_subpools
              @@curr_subpools |= @subpools
          else
              @@curr_subpools = @subpools
          end
         yield
         @@curr_subpools = up_subpools
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
            if item[:count].integer?
                loop_times = item[:count]
            else
                loop_times = 1
            end
            (loop_times).times do
                if item[:force]
                    item[:pool].parse item[:closure]
                else
                    item[:pool].try_parse item[:closure]
                end
            end
        end
        ##excute match subpools
        parse_execute = nil
        force_execute = nil
        continue_execute = nil
        subpools_count = @subpools.map{|item| item[:count]}
        subpools_force = @subpools.map{|item| item[:force]}
        last_parse_sub = nil
        begin
            parse_execute = nil
            @subpools.each_index do |index|
                curr_subp = @subpools[index]
                parse_str_res = curr_subp[:pool].can_parse? curr_subp[:closure]
                if parse_str_res
                    parse_execute = true
                    if subpools_count[index] && subpools_count[index].integer?
                        raise "多次解析错误:"+(@@origin_str.lstrip)[0..9]+'...' unless subpools_count[index] > 0
                        subpools_count[index] -= 1
                    end
                    if subpools_force[index]    ## force
                        subpools_force[index]   = nil
                    end
                    if last_parse_sub == index
                        raise "连续解析错误:"+(@@origin_str.lstrip)[0..9]+'...' if curr_subp[:countinue]
                    end
                    last_parse_sub = index
                else
                    parse_execute = parse_execute
                end
            end
        end while parse_execute
        raise "#{@name}>>没有解析错误:"+(@@origin_str.lstrip)[0..9]+'...' unless subpools_force.reject{|item| item == nil }.empty?
        ##execute end match
        unless match_end
            #puts "#{@name} subpools = "+@subpools.map{|item| item[:pool].name}.to_s
            @subpools.each {|item|
                if item[:pool].name == "macro else if"
                #    p "OOOOk"
                #    p item[:pool].begin_re.match(@@origin_str)
                end
            }
            raise "#{@name}>>结尾异常:"+(@@origin_str.lstrip)[0..9]+'...'
        end
        ##excute match end sequence
        @end_seq_pool.each do |item|
            if item[:count].integer?
                loop_times = item[:count]
            else
                loop_times = 1
            end
            (loop_times).times do
                if item[:force]
                    cstr_res = item[:pool].parse item[:closure]
                else
                    cstr_res = item[:pool].try_parse item[:closure]
                end
            end
        end
        ## reset subpools
        reset_envs
        @@origin_str
    end

end

class TestPool
## field define
module_field = ParsePool.new(name:"module",begin_re:/\Amodule\s/,end_re:/\Aendmodule\b/)
id_name = ParsePool.new(name:"ID",begin_re:/\A\w+/)
one_line_comment = ParsePool.new(name:"one_line_comment",begin_re:/\A\/\//,end_re:/.*?\n/)
mul_lines_comment = ParsePool.new(name:"mul_lines_comment",begin_re:/\A\/\*/,end_re:/.*?\*\//m)
interface_field = ParsePool.new(name:"interface",begin_re:/\Ainterface\s/,end_re:/\Aendinterface\b/)
parameter_field = ParsePool.new(name:"parameter",begin_re:/\Aparameter\b/,end_re:/\Aendparameter\b/)
localparam_field = ParsePool.new(name:"localparam",begin_re:/\Alocalparam\b/,end_re:/\Aendlocalparam\b/)
ff_block_field = ParsePool.new(name:"ff_block",begin_re:/\Affblock\b/,end_re:/\Aendff\b/)
comb_block_field = ParsePool.new(name:"comb_block",begin_re:/\Acomb\b/,end_re:/\Aendcomb\b/)
macro_if_field = ParsePool.new(name:"macro if",begin_re:/\A\`IF/,end_re:/\A\`ENDIF/,pro_level:(:pre_parse))
macro_else_field = ParsePool.new(name:"macro else",begin_re:/\A\`ELSE/,pro_level:(:pre_parse))
macro_elsif_field = ParsePool.new(name:"macro else if",begin_re:/\A\`ELSIF/,pro_level:(:pre_parse))
io_field = ParsePool.new(name:"IO",begin_re:/\A(?-i:input|output|inout)\b/)
range_field = ParsePool.new(name:"[ ]",begin_re:/\A\[/,end_re:/\A\]/)
range_symb = ParsePool.new(name:"[ : ]",begin_re:/\A(?::|-:|\+:)/)
symbol_field = ParsePool.new(name:"symbols",begin_re:/\A(?:\*\*|\*|%|\+|-|\/|==|!=)/)
pre_symbol_field = ParsePool.new(name:"pre symbols",begin_re:/\A(?:~)/)
parenthese_field = ParsePool.new(name:" ( ) ",begin_re:/\A\(/,end_re:/\A\)/)

def ParsePool.add_public_subpools_to(*args)
    args.each do |pool|
        pool.add_public_subpools
    end
end

ParsePool.class_eval do
    define_method "add_public_subpools" do
        add_subpool(pool: macro_if_field,count: nil,force: nil,discontinue: nil)
        add_subpool(pool: one_line_comment,count: nil,force: nil,discontinue: nil)
        add_subpool(pool: mul_lines_comment,count: nil,force: nil,discontinue: nil)
    end
end
## module ##
module_field.add_seq_to(direct:(:begin),pool:id_name,count:1,force:(:force))
module_field.add_subpool(pool: macro_if_field,count: nil,force: nil,discontinue: nil)
module_field.add_subpool(pool: interface_field,count: 1,force: nil,discontinue: nil)
module_field.add_subpool(pool: parameter_field,count: nil,force: nil,discontinue: nil)
module_field.add_subpool(pool: localparam_field,count: nil,force: nil,discontinue: nil)
module_field.add_subpool(pool: ff_block_field,count: nil,force: nil,discontinue: nil)
module_field.add_subpool(pool: comb_block_field,count: nil,force: nil,discontinue: nil)
## interface ##
interface_field.add_seq_to(direct:(:begin),pool:id_name,count:1,force:(:force))
interface_field.add_subpool(pool: io_field,count: nil,force: nil,discontinue: nil)
## parameter
parameter_field.add_seq_to(direct:(:begin),pool:id_name,count:1,force:(:force))
## localparam
localparam_field.add_seq_to(direct:(:begin),pool:id_name,count:1,force:(:force))
## ff_block
ff_block_field.add_seq_to(direct:(:begin),pool:id_name,count:1,force:(:force))
## comb_block
comb_block_field.add_seq_to(direct:(:begin),pool:id_name,count:1,force:(:force))
## MACRO ##
macro_if_field.add_seq_to(direct:(:begin),pool:id_name,count:1,force:(:force))
macro_if_field.add_subpool(pool: macro_if_field,count: nil,force: nil,discontinue: nil)
macro_if_field.add_subpool(pool: macro_elsif_field,count: nil,force: nil,discontinue: nil)
macro_if_field.add_subpool(pool: macro_else_field,count: nil,force: nil,discontinue: true)
macro_elsif_field.add_seq_to(direct:(:begin),pool:id_name,count:1,force:(:force))
macro_if_field.inherit_subpools = true
macro_elsif_field.inherit_subpools = true
macro_else_field.inherit_subpools = true
## io ##
io_field.add_seq_to(direct:(:begin),pool:range_field,count:1,force:nil)
io_field.add_seq_to(direct:(:begin),pool:id_name,count:1,force:(:force))
io_field.add_seq_to(direct:(:begin),pool:range_field,count:1,force:nil)
## RANGE ##
range_field.add_subpool(pool: symbol_field,count: nil,force: nil,discontinue: true)
range_field.add_subpool(pool: id_name,count: nil,force: nil,discontinue: true)
range_field.add_subpool(pool: range_symb,count: 1,force: true,discontinue: true)
## -> ##
## symbol ##
## parenthese ##
parenthese_field.add_subpool(pool: symbol_field,count: nil,force: nil,discontinue: true)
parenthese_field.add_subpool(pool: id_name,count: nil,force: nil,discontinue: true)
parenthese_field.add_subpool(pool: range_field,count: nil,force: nil,discontinue: true)
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
    define_method :exec_test do
        module_field.parse
    end
end
