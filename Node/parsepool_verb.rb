class BasePool
    @@curr_subseqs = []
    @@level = 0
    attr_accessor   :name,:inherit_subseqs,:match_space,:re_closure,:pro_closure,:error_closure,
                    :force,:discontinue,:count,:outside_closures,:dynamic_subseqs
    def initialize(name:"Pool")
        @name = name
        @outside_closures = []
        @inherit_subseqs = nil
        @error_closure = Proc.new {puts "#{'  '*@@level} #{name} error"}
    end

    def new(force:nil,discontinue:nil,count:nil,outside_closures:[])
        new_pool = self.clone
        new_pool.force = force
        new_pool.discontinue = discontinue
        new_pool.count = count
        new_pool.outside_closures = outside_closures
        return new_pool
    end

    def with_new_envirement(&block)
        up_subseqs =  @@curr_subseqs
        @@level += 1
        if inherit_subseqs
             @dynamic_subseqs = @@curr_subseqs
         else
             @@curr_subseqs = subseqs
         end
        yield
        @@curr_subseqs = up_subseqs
        @@level -= 1
    end

    def indent_puts(str)
        printf "#{'  '*@@level}"
        puts str
    end

end
class ParsePool < BasePool
    attr_accessor   :begin_seq_pools,:end_seq_pools,:subseqs,:complete_begin_seq_closure,
                    :complete_end_seq_closure,:complete_subseqs_closure,
                    :inherit_subseqs,:generic_subs

    def initialize(name:"Pool")
        @begin_seq_pools = []
        @end_seq_pools = []
        @subseqs = []
        @generic_subs = []
        @complete_begin_seq_closure = nil
        @complete_end_seq_closure = nil
        @complete_subseqs_closure = nil
        super
    end

    ## FILL SEQUENCE ##
    def add_to_begin_of(pool)
        new_slot = PoolSlot.new(pool:pool,force:true)
        pool.begin_seq_pools << new_slot
        return pool
    end

    def add_to_end_of(pool)
        new_slot = PoolSlot.new(pool:pool,force:true)
        pool.end_seq_pools << new_slot
        return pool
    end

    def add_to_subseqs_of(pool)
        new_slot = PoolSlot.new(pool:pool,force:nil)
        pool.subseqs << new_slot
        return pool
    end

    def contain (director,*pools)
        case(director)
        when :begin
            *pool.each do |item|
                item.add_to_begin_of self
            end
        when :end
            *pool.each do |item|
                item.add_to_end_of self
            end
        when :sub
            *pool.each do |item|
                item.add_to_subseqs_of self
            end
        else
        end
    end

    def begin_contain(*pools)
        contain(:begin,*pools)
    end

    def end_contain(*pools)
        contain(:end,*pools)
    end

    def sub_contain(*pools)
        contain(:sub,*pools)
    end
    ##> FILL SEQUENCE <##
    ## add new method to Regexp ##
    class << Regexp
        def gen_atom_pool
            AtomPool.new(name:self.to_s,self)
        end

        def add_to_begin_of(pool)
            pool.begin_seq_pools << gen_atom_pool
            return pool
        end

        def add_to_end_of(pool)
            pool.end_seq_pools << gen_atom_pool
            return pool
        end

        def add_to_subseqs_of(pool)
            pool.subseqs << gen_atom_pool
            return pool
        end
    end
    ##> add new method to Regexp <##
    def parse(parsepkt)
        with_new_envirement do
            indent_puts "LEVEL>>#{@@level}<<PARSE #{@name}"
            parseresult = core_parse parsepkt
            indent_puts "LEVEL<<#{@@level}>>END #{@name} "
            #@parseresult[:rest] += @parseresult[:match]
            #p @arseresult
        end
        return parseresult
    end

    def core_parse(parsepkt)
        parseresult = ParseResult.new(result:nil,origin:parsepkt[:origin],match:'',rest:parsepkt[:rest])
        parseresult.strip unless @match_space
        @begin_archor = parseresult[:rest].length
        match parseresult
    end

    def match (parseresult)
        return parseresult if match_begin(parseresult).result==nil
        match_subseqs parseresult
        return parseresult if match_end(parseresult).result==nil
        @outside_closures.each {|item| item.call(parseresult[:match])}
        parseresult[:rest] += @re_closure.call(parseresult[:match]) if @re_closure
        return parseresult
    end

    def match_seq(parseresult,sequence)
        curr_closure = []
        return parseresult if sequence==nil || sequence.empty?
        parseresult[:result] = nil
        sequence.each do |slot_item|
            new_pool = slot_item.active
            do
                generic_subs.each {|item_sub| parseresult = item_sub.parse=parseresult }
            end while parseresult[:result]
            curr_result =  new_pool.parse(parseresult)
            #p @parseresult
            ## curr_protein match
            if curr_result[:result]
                ##resord closure
                curr_closure << new_pool.pro_closure if new_pool.pro_closure
            else
                ## curr_sequence not force
                unless new_pool.force
                    parseresult.error_stack = []
                    next
                else
                    parseresult.error_stack << lambda { @error_closure.call(curr_result[:origin]) }
                    return  parseresult
                end
            end
            parseresult.eat_all curr_result
        end
        curr_closure.each {|item| item.call }
        return  parseresult
    end

    def match_begin(parseresult)
        indent_puts "LEVEL>>#{@@level}<<BEGIN POOLS -------------"
        match_seq(parseresult,@begin_seq_pools)
        return parseresult unless parseresult[:result]
        @complete_begin_seq_closure.each {|item| item.call(parseresult[:match]) }
        return parseresult
    end

    def match_end(parseresult)
        indent_puts "LEVEL>>#{@@level}<<END POOLS ________________"
        match_seq(parseresult,@end_seq_pools)
        return parseresult unless @parseresult[:result]
        (@complete_end_seq_closure | @outside_closures).each {|item| item.call(parseresult[:match]) }
        return parseresult
    end

    def match_subseqs(parseresult)
        indent_puts "=========SUB POOLS==============="
        curr_closure = []
        ## subpools status
        parse_execute = nil
        mask_seq_index = nil
        sub_seqs = @subseqs | @dynamic_subseqs
        return parseresult if sub_seqs==nil || sub_seqs.empty?
        subseqs_count = Array.new(sub_seqs.size,0)
        ## loop
        begin
            parse_execute = nil
            sub_seqs.each_index do |sub_slot_index|
                ## mask discontinue seq
                if (mask_seq_index==sub_slot_index)
                    next
                end
                ##
                curr_slot = sub_seqs[sub_slot_index]
                new_pool = curr_slot.active
                #parsepkt.eat protein.parse(parsepkt)
                sub_parsepkt = new_pool.parse parseresult
                parseresult.eat sub_parsepkt
                unless sub_parsepkt.result

                else
                    parse_execute = true
                    ## record next mask
                    if new_pool.discontinue
                        mask_seq_index = sub_slot_index
                    else
                        mask_seq_index = nil
                    end
                    ##
                    subseqs_count[sub_slot_index] += 1
                    if new_pool.count < subseqs_count[sub_slot_index]
                        parseresult.result = nil
                        parseresult.error_stack << lambda { raise "多次解析 #{protein.name} 错误"}
                        #puts "多次解析 #{protein.name} 错误"
                        return parseresult
                    end
                end
            end
        end while parse_execute
        ##
        indent_puts "**************SUB POOLS***************"
        subseqs_count.each_index do |index|
            if sub_seqs[index] > subseqs_count[index]
                parseresult.error_stack << lambda { raise "解析次数不足 #{protein.name} 错误"}
            end
        end
        ## eval closure
        @complete_subseqs_closure.each {|item| item.call(parseresult[:match])}
        return parseresult
    end

end

class AtomPool < BasePool
    def initialize(name:"AtomPool",re:nil)
        super(name)
        @re = re
    end

    def parse(parsepkt)
        with_new_envirement do
            indent_puts "LEVEL>>#{@@level}<<PARSE ATOM #{@name}"
            parseresult = ParseResult.new(result:nil,origin:parsepkt[:origin],match:'',rest:parsepkt[:rest])
            parseresult.strip unless @match_space
            parseresult.match @re,@re_closure,@pro_closure
            if parseresult[:result]
                @outside_closures.each {|item| item.call(parseresult[:match])}
            end
            indent_puts "LEVEL<<#{@@level}>>END ATOM #{@name}"
        #    p @parseresult
        end
        return parseresult
    end

end

class TwinPool < BasePool
    attr_accessor :pools
    def initialize(name:"TwinPool",twinpools:[])
        super(name:name)
        @pools = twinpools  ## parsepool array
        @pools.each do |pool_item|
            pool_item.outside_closures = outside_closures
        end
    end

    def parse(parsepkt)
        with_new_envirement do
            indent_puts "LEVEL>>#{@@level}<<PARSE TWIN #{@name}"
            parseresult = ParseResult.new(result:nil,origin:parsepkt[:origin],match:'',rest:parsepkt[:rest])
            parseresult.strip unless @match_space
            @pools.each do |pool|
                rel =  pool.parse(parseresult)
                if rel[:result]
                    parseresult.eat rel
                    break
                end
            end
            parseresult[:rest] += parseresult[:match]
            indent_puts "LEVEL<<#{@@level}>>END TWIN #{@name}"
        end
        return parseresult
    end
end
