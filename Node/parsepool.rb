require "parseresult"
class ParsePool
    @@curr_subpools  = []

    attr_accessor :inherit_subpools,:name
    attr_reader :end_re,:begin_re
    def initialize(name:"Pool")
        @begin_seq_pools = []   ## pool array [{pool:,force:,closure:}] or  [[{pool:,force:,closure:},{pool:,force:,closure:,rel_closure}]...]
        @end_seq_pools = []     ## pool array [{pool:,force:,closure:}] or  [[{pool:,force:,closure:},{pool:,force:,closure:,rel_closure}]...]
        @subpools = []          ## pool array [{pool:,force:,closure:,count:,countinue:}] or  [[{pool:,force:,closure:},{pool:,force:,closure:,rel_closure}]...]
        @inherit_subpools = nil
        @name = name
        ## closure
        @complete_begin_seq_closure = []
        @complete_end_seq_closure = []
        @complete_subpools_closure = []

        @parseresult = ParsseResult.new
        @complete_begin_seq_closure << lambda { printf "START PARSE #{@name} --> ";p @subpools.map{|item| item[:pool].name}}
        @complete_end_seq_closure   << lambda { puts "COMPLETE PARSE #{@name}"}
    end


    def add_seq_to(direct:(:begin),pool:nil,force:true,closure:nil)
        if direct == :begin
            @begin_seq_pools << {:pool=>pool,:force=>force,:closure=>closure}
        elsif direct == :end
            @end_seq_pools << {:pool=>pool,:force=>force,:closure=>closure}
        end
    end

    def add_list_to(direct:(:begin),pool_closure_array:nil)
        list = []
        pool_closure_array.each do |item|
            list << {:pool=>item[:pool],:closure=>item[:closure]}
        end
        return  if list.empty?
        if direct == :begin
            @begin_seq_pools << {:pool=>list}
        elsif direct == :end
            @end_seq_pools <<  {:pool=>list}
        end
    end

    def have_same?(a,b)
        ab = [a,b].flatten
        ab.length != [a,b].length
    end

    def add_subpool (pool: nil,count: nil,force: false,discontinue: false,closure:nil)
        @subpools.each do |item|
            puts "警告:subpools 有重复项 #{subitem[:pool].name}" if have_same? item[:pool],pool
        end
        @subpools << {:pool=>pool,:count=>count,:force=>force,:discontinue=> discontinue,:closure=>closure}
    end

    def add_sublist (count:nil,force:false,discontinue: false,pool_closure_array:nil)
        list = []
        pool_closure_array.each do |item|
            @subpools.each do |subitem|
                puts "警告:subpools 有重复项 #{subitem[:pool].name}" if have_same? subitem[:pool],item[:pool]
            end
            list << {:pool=>item[:pool],:closure=>item[:colsure]}
        end
        @subpools << {:pool=>list,:count=>count,:force=>force,:discontinue=> discontinue}
    end

    def order_outside_closure(*args)
        @outside_closure = []
        args.each do |item|
            if item.is_a? Proc
                @outside_closure << item
            end
        end
    end

    def parse(parsepkt,*args,&block)
        core_parse(parsepkt,args.join(block)) do
            $pe.call unless match
        end
        return @parseresult
    end

    def try_parse(parsepkt,*args,&block)
        core_parse(parsepkt,args.join(block)) do
            if match
                return @parseresult
            else
                parsepkt[:result] = false
                return parsepkt
            end
        end
    end

    def can_parse?(parsepkt,*args,&block)
        core_parse(parsepkt,args.join(block)) do
            if match
                return @parseresult
            else
                return nil
            end
        end
    end

    def core_parse(parsepkt,*closure_args,&block)
        @parseresult = ParseResult.new(result:nil,orgin:parsepkt[:origin],match:'',rest:parsepkt[:rest])
        @parseresult[:origin].sub!(/\A\s*/) do |mstr|
            curr_parsepkt[:rest] += mstr
            ''
        end
        @begin_archor = curr_parsepkt[:rest].length
        order_outside_closure(*closure_args)
        yield
    end


    def match_seq(sequence,msg)
        curr_closure = []
        parsepkt = @parseresult
        sequence.each do |item|
            array_force = nil
            if item[:pool].is_a? Regexp
                parsepkt.match! item[:pool],item[:rel_closure] do |args|
                    if item[:closure]
                        curr_closure << lambda { item[:closure].call(*args)}
                    end
                end
            elsif item[:pool].is_a? ParsePool
                if item[:force]
                    rel_parsepkt = item[:pool].parse(parsepkt)
                else
                    rel_parsepkt = item[:pool].try_parse(parsepkt)
                end
                if rel_parsepkt[:result]
                    parsepkt.eat rel_parsepkt
                    curr_closure << lambda { item[:closure].call(rel_parsepkt[:match]) } if item[:closure]
                end
            elsif item[:pool].is_a? Array
                item[:pool].each do |arrayitem|
                    if arrayitem[:force]
                        rel_parsepkt = arrayitem[:pool].parse(parsepkt)
                    else
                        rel_parsepkt = arrayitem[:pool].try_parse(parsepkt)
                    end
                    if rel_parsepkt[:result]
                        parsepkt.eat rel_parsepkt
                        curr_closure << lambda { arrayitem[:closure].call(rel_parsepkt[:match]) if arrayitem[:closure]
                        break
                    end
                end
                array_force = true
            end
            if (parsepkt[:result]==nil) && (item[:force] || array_force)
                $pe  = lambda { raise "#{@name} 解析错误 #{msg} >>>"+parsepkt[:origin][0..19]+'......'}
                return nil
            end
        end
        curr_closure.each do |item|
            item.call
        end
        return  @parseresult = parsepkt
    end

    def match_begin
        return nil unless match_seq(@begin_seq_pools,"BEGIN")
        @complete_begin_seq_closure.each do {|item| item.call(parsepkt[:match]) }
    end

    def match_end
        return nil unless match_seq(@end_seq_pools,"END")
        @complete_end_seq_closure.each do {|item| item.call(parsepkt[:match]) }
    end

    def match_subpools
        curr_closure = []
        parsepkt = @parseresult
        ## subpools status
        parse_execute = nil
        force_execute = nil
        continue_execute = nil
        subpools_count = @subpools.map{|item| item[:count]}
        subpools_force = @subpools.map{|item| item[:force]}
        last_parse_sub = nil
        cc = Proc.new do |pool,index,origin_str|
            parse_execute = true
            if subpools_count[index] && subpools_count[index].integer?
                unless subpools_count[index] > 0
                    $pes = lambda { raise "#{@name} #{pool} 多次解析错误:"+(origin_str.lstrip)[0..19]+'...'}
                    return nil
                end
                subpools_count[index] -= 1
            end
            force_execute[index] = nil
            if last_parse_sub == index
                $pe == lambda { raise "#{@name} #{pool} 连续解析错误:"+(origin_str.lstrip)[0..19]+'...' if curr_subp[:countinue] }
                return nil
            end
            last_parse_sub = index
        end
        ## loop
        begin
            parse_execute = nil
            @subpools.each_index do |index|
                curr_subp = @subpools[index]
                array_force = nil
                if curr_subp[:pool].is_a? Regexp
                    parsepkt.match! item[:pool],item[:rel_closure] do |args|
                        if item[:closure]
                            item[:closure].call(*args)
                        end
                    end
                    cc.call "None",index,parsepkt[:origin]
                elsif curr_subp[:pool].is_a? ParsePool
                    if curr_subp[:force]
                        rel_parsepkt = item[:pool].parse(parsepkt,*item[:closure])
                    else
                        rel_parsepkt = item[:pool].try_parse(parsepkt,*item[:closure])
                    end
                    if rel_parsepkt[:result]
                        parsepkt.eat rel_parsepkt
                    end
                    cc.call curr_subp[:pool].name,index,parsepkt[:origin]
                elsif curr_subp[:pool].is_a? Array
                    curr_subp[:pool].each do |arrayitem|
                        if arrayitem[:force]
                            rel_parsepkt = arrayitem[:pool].parse(parsepkt,*arrayitem[:closure])
                        else
                            rel_parsepkt = arrayitem[:pool].try_parse(parsepkt,*arrayitem[:closure])
                        end
                        if rel_parsepkt[:result]
                            parsepkt.eat rel_parsepkt
                            cc.call arrayitem[:pool].name,index,parsepkt[:origin]
                            break
                        end
                    end
                    array_force = true
                end
            end
        end while parse_execute
        unless subpools_force.reject{|item| item == nil }.empty?
            $pe = lambda { raise "#{@name}>>没有解析错误:"+(parsepkt[:origin].lstrip)[0..9]+'...' }
            return nil
        end
        (@outside_closure|@complete_subpools_closure).each do {|item| item.call(parsepkt[:match]) }
        return  @parseresult = parsepkt
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
        ## set subpools
        set_envs
        ##execute match begin
        return nil unless match_begin
        ##excute match subpools
        return nil unless match_subpools
        ##excute match end sequence
        return nil unless match_end
        ## reset subpools
        @parseresult[:result] = true
        reset_envs
        @parseresult
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

variable_field = ParsePool.new(name:"变量 ",begin_re:/\A\w+/)
operator_field = ParsePool.new(name:" 赋值语句 ",end_re:/\A[;\n]/)
brace_field =  ParsePool.new(name:" 花括号 ",begin_re:/\A\{/,end_re:/\A\}/)

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
## operator ##
operator_field.add_seq_to(direct:(:begin),pool:variable_field,count:1,force:true)
operator_field.add_seq_to(direct:(:begin),pool:ParsePool.new(begin_re:/\A\=/),count:1,force:true)
operator_field.add_subpool(pool: variable_field,count: nil,force:true,discontinue: true)
operator_field.add_subpool(pool: symbol_field,count: nil,force: nil,discontinue: true)
operator_field.add_subpool(pool: parenthese_field,count: nil,force: nil,discontinue: true)
operator_field.add_subpool(pool: brace_field,count: nil,force: nil,discontinue: true)
## brace ##
brace_field.add_subpool(pool: variable_field,count: nil,force:true,discontinue: true)
brace_field.add_subpool(pool: ParsePool.new(begin_re:/\A,/),count: nil,force:nil,discontinue: true)
## Variable ##
variable_field.add_seq_to(direct:(:begin),pool:range_field,count:1,force:nil)
## add_public_subpools_t

ParsePool.add_public_subpools_to(   module_field,
                                    interface_field,
                                    parameter_field,
                                    localparam_field,
                                    ff_block_field,
                                    comb_block_field,
                                    io_field,
                                    range_field,
                                    parenthese_field
                                    operator_field)
    define_method :exec_test do
        module_field.parse
    end
end
