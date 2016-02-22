class ParseRoute
    @@filo_stack  = []## [@end_re,[lambda_closures]]
    @@execute_convayor = []
    def initialize(begin_re,end_re=nil)
        @begin_re = begin_re
        @end_re = end_re
        @next_parse = []
        @parse_end = false
        @curr_execute_closure = []
    end

    def add_next_parse(np)
        抛出非ParseRoute错误 unless np.is_a? ParseRoute
        @next_parse << np
    end

    def add_next_execute_if (condition,&block)
        if condition
            @next_parse.each do |item|

            end
        end
    end

    def add_curr_execute_if(condition,&block)
        if condition
            @curr_execute_closure << block
        end
    end


    def match (str)
        cstr = str.strip
        cmatch = cstr.match(@begin_re)
        return nil if cmatch
        ##execute current closure
        curr_mch_avgs = cmatch[1,@begin_re.length]
        @@execute_convayor.each do |item|
            item.call(*curr_mch_avgs)
        end
        ##execte


end
