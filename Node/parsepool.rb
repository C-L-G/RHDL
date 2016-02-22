class ParsePool

    def initialize(begin_re,end_re=nil)
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
    end

    def add_curr_execute(&block)
        @curr_execute_closure << block
    end

    def add_seq_to(direct=:begin,pool,count=nil,force=true)
        if direct == :begin
            @begin_seq_pool << [pool,count,force]
        elsif direct == :end
            @end_seq_pool << [pool,count,force]
        end
    end

    def parse(str)
        str_res = match(str)
        unless str_res
            抛出无法解析错误
        end
        return str_res
    end

    def can_parse?(str)
        str_res = match(str)
        unless str_res
            return nil
        end
        return str_res
    end

    def try_parse(str)
        str_res = match(str)
        unless str_res
            return str
        end
        return str_res
    end

    def match_begin(str)
        $~ = nil
        cstr_res = cstr.sub(@begin_re) do
            cmatch = $~
            ''
        end
        return nil if cmatch
        ##execute current closure
        curr_mch_avgs = cmatch[1,@begin_re.length]
        @curr_execute_closure.each do |item|
            item.call(*curr_mch_avgs)
        end
        cstr_res
    end

    def match_end(str)
        return str unless @end_re
        $~ = nil
        cstr_res = cstr.sub(@end_re) do
            cmatch = $~
            ''
        end
        return nil if cmatch
        ##execute current closure
        curr_mch_avgs = cmatch[1,@begin_re.length]
        @curr_end_exe_closure.each do |item|
            item.call(*curr_mch_avgs)
        end
        cstr_res
    end

    def match(str)
        cstr = str.lstrip
        ##execute match begin
        cstr_res = match_begin(str)
        return nil unless cstr_res
        ##excute match begin sequence
        @begin_seq_pool.each do |item|
            if item[1].integer?
                loop_times = item[1]
            else
                loop_times = 1
            end
            (loop_times).times do
                if item[3]
                    cstr_res = item[0].parse(cstr_res)
                else
                    cstr_res = item[0].try_parse(cstr_res)
                end
            end
        end
        ##excute match subpools
        parse_execute? = nil
        force_execute? = nil
        continue_execute? = nil
        subpools_count = @subpools.map{|item| item[1]}
        subpools_force = @subpools.map{|item| item[2]}
        last_parse_sub = nil
        begin
            parse_execute? = nil
            @subpools.each_index do |index|
                parse_str_res = @subpools[index][0].can_parse? cstr_res
                if parse_str_res
                    parse_execte? = true
                    cstr_res = parse_str_res
                    if subpools_count[index].integer?
                        抛出多次解析错误 unless subpools_count[index] > 0
                        subpools_count[index] -= 1
                    end
                    if subpools_force[index]    ## force
                        subpools_force[index]   = nil
                    end
                    if last_parse_sub == index
                        抛出连续解析错误 if @subpools[index][3]
                    end
                    last_parse_sub = index
                else
                    parse_execute? = parse_execute?
                    if subp_count[2]    ## force
                        subp_count[2]   = nil
                    end
                end
                subp_count
            end
        end while parse_execute?
        抛出没有解析错误 if subpools_force.include?(true)
        ##execute end match
        cstr_res = match_end(cstr_res)
        抛出结尾异常 unless cstr_res
        ##excute match end sequence
        @end_seq_pool.each do |item|
            if item[1].integer?
                loop_times = item[1]
            else
                loop_times = 1
            end
            (loop_times).times do
                if item[3]
                    cstr_res = item[0].parse(cstr_res)
                else
                    cstr_res = item[0].try_parse(cstr_res)
                end
            end
        end
        return cstr_res
    end

end

module_filed = ParsePool(/^module\s/,/^endmodule\b/)
module_id_name = ParsePool(/^\w+/)
module_one_line_comment = ParsePool(/^\/\//,/.*?\n/)
module_mul_lines_comment = ParsePool(/^\/\*/,/.*?\*\//m)
interface_field = ParsePool(/^interface\s/,/^endinterface\b/)
parameter_field = ParsePool(/^parameter\b/,/^endparameter\b/)
localparam_filed = ParsePool(/^localparam\b/,/^endlocalparam\b/)
ff_block_filed = ParsePool(/^ffblock\b/,/^endff\b/)
comb_block_filed = ParsePool(/^comb\b/,/^endcomb\b/)
## io ##
io_field = ParsePool(/^(?-i:input|output|inout)\b/)
range_filed = ParsePool(/^\[/,/^\]/)
symbol_filed = ParsePool(/^(?:\*\*|\*|%|\+|-|\/|==|!=)/)
pre_symbol_filed = ParsePool(/^(?:~)/)
