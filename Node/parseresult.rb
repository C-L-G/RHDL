class ParsseResult
    attr_accessor :result,:origin,:match_str,:rest
    def initialize(result:nil,origin:"",match_str:"",rest:"")
        @result = result
        @origin = origin
        @match_str = match_str
        @rest = rest
    end

    def match(re,rel_closure,&block)
        cmatch = nil
        mstr = ''
        rel = false
        ostr = @origin.sub(re) do |mch|
            cmatch = $~
            mstr = mch
            rel = true
            if block_given?
                curr_mch_avgs = cmatch[1,@re.names.length]
                yield curr_mch_avgs
            end
        end
        mmstr = rel_closure.call(mstr) if rel_closure.is_a? Proc
        return ParseResult.new(result:rel,origin:ostr,match_str:@match_str+mstr,rest:(@rest+mmstr))
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
        else
            nil
        end
    end

    def eat (new_rel)
        @origin = new_rel[:origin]
        @match_str += new_rel[:match]
        @rest = new_rel[:rest]
        @result = new_rel[:result]
    end




end
