class ParsseResult
    attr_accessor :result,:origin,:match_str,:rest
    def initialize(result:nil,skip:nil,origin:"",match_str:"",rest:"")
        @result = result
        @origin = origin
        @match_str = match_str
        @rest = rest
        @pro_closure = []
        @error_stack = []
    #    @error_stack = lambda { puts "No Error"}
    end

    def match(re,re_closure,seq_closure)
        cmatch = nil
        mstr = ''
        rel = false
        $~ = nil
        ostr = @origin.sub(re) do |mch|
            cmatch = $~
            mstr = mch
            rel = true
            curr_mch_avgs = cmatch[1,@re.names.length]
            @pro_closure <<  lambda { seq_closure.call(*curr_mch_avgs) } if seq_closure
            end
        end
        mmstr = re_closure.call(mstr) if rel_closure.is_a? Proc
        @result = rel
        @origin = ostr
        @match_str = @match_str+mstr
        @rest = (@rest+mmstr)
        self
    end

    def match!(re,rel_closure,&block)
        self = match(re,rel_closure,block)
    end

    def [](sym)
        case sym.to_sym
        when :result
            @result
        when :origin
            @origin
        when :match
            @match_str
        when :rest
            @rest
        when :error
            @error_closure
        else
            missing_method
        end
    end

    def []=(sym,value)
        case sym.to_sym
        when :result
            @result = value
        when :origin
            @origin = value
        when :match
            @match_str = value
        when :rest
            @rest = value
        when :error
            @error_closure = value
        else
            missing_method
        end
    end

    def eat (new_rel)
        match_str = @match_str + new_rel[:match]
        self = new_rel
        @match_str = match_str
        return self
    end




end
