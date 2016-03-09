require "parseresult.rb"
class BasePool

    ## Class method
    def self.define_class_var(name,default=nil)
        self.class.class_eval do
            define_method name do
                if class_variable_defined?('@@'+name.to_s)
                    class_variable_get('@@'+name.to_s)
                else
                    default
                end
            end
            define_method name.to_s+'=' do |arg|
                class_variable_set("@@"+name.to_s,arg)
            end
        end
        ## instance method
        define_method name do
            if self.class.class_variable_defined?('@@'+name.to_s)
                self.class.class_variable_get('@@'+name.to_s)
            else
                nil
            end
        end
    end

    def self.class_vars(default,*names)
        names.each do|item|
            self.define_class_var item,default
        end
    end
    ##
    @@curr_subseqs = []
    @@level = 0
    class_vars [],  :begin_seq_pools,:end_seq_pools,:subseqs,:complete_begin_seq_closure,
                    :complete_end_seq_closure,:complete_subseqs_closure,:complete_closure
    class_vars nil,:inherit_subseqs
    class_vars "Pool",:name
    attr_accessor :outside_closures,:dynamic_subseqs,:re_closure,:pro_closure
    def initialize(name:"Pool",outside_closures:[],pro_closure:nil,re_closure:nil)
        ## init
                                         ## BaseSeq [bs0,bs1]
        ## begin_seq_pools = begin_seq   ## pool array [{pool:,force:,closure:}] or  [[{pool:,force:,closure:},{pool:,force:,closure:,rel_closure}]...]
        ## end_seq_pools = end_seq     ## pool array [{pool:,force:,closure:}] or  [[{pool:,force:,closure:},{pool:,force:,closure:,rel_closure}]...]
        ## subpools = subpools          ## pool array [{pool:,force:,closure:,count:,countinue:}] or  [[{pool:,force:,closure:},{pool:,force:,closure:,rel_closure}]...]
        ## closure
        ## complete_begin_seq_closure = []
        ## complete_end_seq_closure = []
        ## complete_subpools_closure = []
        @outside_closures = outside_closures       ## eval at the end of parse
        @re_closure = nil           ## process match string and add to rest
        @dynamic_subseqs = []
        @parseresult = nil
        @pro_closure = pro_closure
        @error_closure = lambda { |origin_str| puts "解析#{name}错误 不期望 #{origin_str[0..19]} ...."}
    #    @complete_begin_seq_closure << lambda { printf "START PARSE #{@name} --> ";p @subpools.map{|item| item[:pool].name}}
    #    @complete_end_seq_closure   << lambda { puts "COMPLETE PARSE #{@name}"}
        @inst_name = name
    end

    def parse(parsepkt)
        puts "#{'  '*@@level}LEVEL>>#{@@level}<<PARSE #{name} #{@inst_name}"
        @@level += 1
        core_parse parsepkt
        @@level -= 1
        printf "#{'  '*@@level}LEVEL<<#{@@level}>>END #{name} "
        p @parseresult
        return @parseresult
    end


    def core_parse(parsepkt)
        @parseresult = ParseResult.new(result:nil,origin:parsepkt[:origin],match:'',rest:parsepkt[:rest])
        @parseresult.strip
        @begin_archor = @parseresult[:rest].length
        match @parseresult
    end

     def with_new_envirement(&block)
         up_subseqs =  @@curr_subseqs
         if inherit_subseqs
              @dynamic_subseqs = @@curr_subseqs
          else
              @@curr_subseqs = subseqs
          end
         yield
         @@curr_subseqs = up_subseqs
     end

     def match (parsepkt)
         @parseresult = parsepkt
         with_new_envirement do
             return @parseresult if match_begin().result==nil
             match_subseqs
             return @parseresult if match_end().result==nil
         end
         @outside_closures.each {|item| item.call(@parseresult[:match])}
         @parseresult[:rest] += @re_closure.call(@parseresult[:match]) if @re_closure
         return @parseresult
     end

     def match_seq(sequence,msg)
         curr_closure = []
         return @parseresult if sequence==nil || sequence.empty?
         sequence.each do |baseseq_item|
             protein = baseseq_item.protein
             curr_result =  protein.parse(@parseresult)
             #p @parseresult
             ## curr_protein match
             if curr_result[:result]
                 ##resord closure
                 curr_closure << protein.pro_closure if protein.pro_closure
             else
                 ## curr_sequence not force
                 unless baseseq_item.force
                     @parseresult.error_stack = []
                     next
                 else
                     @parseresult.error_stack << lambda { @error_closure.call(curr_result[:origin]) }
                     return  @parseresult
                 end
             end
             @parseresult.eat_all curr_result
         end
         curr_closure.each {|item| item.call }
         return  @parseresult
     end


    def match_begin
        puts "#{'  '*@@level}LEVEL>>#{@@level}<<BEGIN POOLS -------------"
        match_seq(self.class.begin_seq_pools,"BEGIN")
        return @parseresult unless @parseresult[:result]
        self.class.complete_begin_seq_closure.each {|item| item.call(parsepkt[:match]) }
        return @parseresult
    end

    def match_end
        puts "#{'  '*@@level}LEVEL>>#{@@level}<<END POOLS ________________"
        match_seq(self.class.end_seq_pools,"END")
        return @parseresult unless @parseresult[:result]
        (self.class.complete_end_seq_closure | @outside_closures).each {|item| item.call(parsepkt[:match]) }
        return @parseresult
    end

    def match_subseqs
        puts "#{'  '*@@level}LEVEL>>#{@@level}<<SUB POOLS==============="
        curr_closure = []
        parsepkt = @parseresult
        ## subpools status
        parse_execute = nil
        mask_seq_index = nil
        sub_seqs = self.class.subseqs | @dynamic_subseqs
        return parsepkt if sub_seqs==nil || sub_seqs.empty?
        subseqs_count = Array.new(sub_seqs.size,0)
        ## loop
        begin
            parse_execute = nil
            sub_seqs.each_index do |baseseq_item_index|
                ## mask discontinue seq
                if (mask_seq_index==baseseq_item_index)
                    next
                end
                ##
                baseseq_item = sub_seqs[baseseq_item_index]
                protein = baseseq_item.protein
                parsepkt.eat protein.parse(parsepkt)
                if (parsepkt.result == nil)

                else
                    parse_execute = true
                    ## record next mask
                    if sub_seqs[baseseq_item_index].discontinue
                        mask_seq_index = baseseq_item_index
                    else
                        mask_seq_index = nil
                    end
                    ##
                    subseqs_count[baseseq_item_index] += 1
                    if baseseq_item < subseqs_count[baseseq_item_index]
                        parsepkt.result = nil
                        parsepkt.error_stack << lambda { raise "多次解析 #{protein.name} 错误"}
                        return parsepkt
                    end
                end
            end
        end while parse_execute
        ##
        subseqs_count.each_index do |index|
            if sub_seqs[index] > subpools_count[index]
                parsepkt.error_stack << lambda { raise "解析次数不足 #{protein.name} 错误"}
            end
        end
        ## eval closure
        self.class.complete_subseqs_closure.each {|item| item.call(parsepkt[:match])}
        return  @parseresult = parsepkt
    end

end

class AtomPool < BasePool
    def initialize(name:"AtomPool",re:nil,outside_closures:[],pro_closure:nil,re_closure:nil)
        super(name:name,outside_closures:outside_closures,pro_closure:pro_closure,re_closure:re_closure)
        @re = re
        #@parseresult = ParsseResult.new
    end

    def parse(parsepkt)
        puts "#{'  '*@@level}LEVEL>>#{@@level}<<PARSE ATOM #{@inst_name}"
        @@level += 1
        @parseresult = ParseResult.new(result:nil,origin:parsepkt[:origin],match:'',rest:parsepkt[:rest])
        @parseresult.strip
        @parseresult.match @re,@re_closure,@pro_closure
        if @parseresult[:result]
            @outside_closures.each {|item| item.call(@parseresult[:match])}
        end
        @@level -= 1
        printf "#{'  '*@@level}LEVEL<<#{@@level}>>END ATOM #{@inst_name}"
        p @parseresult
        return @parseresult
    end

end

class TwinPool < BasePool

    def initialize(name:"TwinPool",twinpools:[],outside_closures:[],pro_closure:nil,re_closure:nil)
        super(name:name,outside_closures:outside_closures,pro_closure:pro_closure,re_closure:re_closure)
        @pools = twinpools  ## parsepool array
        @pools.each do |pool_item|
            pool_item.outside_closures = outside_closures
        end
    end

    def parse(parsepkt)
        puts "#{'  '*@@level}LEVEL>>#{@@level}<<PARSE TWIN #{@inst_name}"
        @@level += 1
        @parseresult = ParseResult.new(result:nil,origin:parsepkt[:origin],match:'',rest:parsepkt[:rest])
        @parseresult.strip
        @pools.each do |pool|
            rel =  pool.parse(@parseresult)
            if rel[:result]
                @parseresult.eat rel
                break
            end
        end
        @@level -= 1
        printf "#{'  '*@@level}LEVEL<<#{@@level}>>END TWIN #{@inst_name}"
        p @parseresult
        return @parseresult
    end
end
