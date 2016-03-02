class BasePool
    @@curr_subseqs = []
    class_vars [],  :begin_seq_pools,:end_seq_pools,:subseqs,:complete_begin_seq_closure,
                    :complete_end_seq_closure,:complete_subseqs_closure,:complete_closure
    class_vars nil,:inherit_subseqs,

    attr_accessor :outside_closure,:dynamic_subseqs,:rel_closure
    def initialize(name:"Pool",outside_closure:[],pro_closure:nil,re_closure:nil)
        ## init
                                         ## BaseSeq [bs0,bs1]
        ## begin_seq_pools = begin_seq   ## pool array [{pool:,force:,closure:}] or  [[{pool:,force:,closure:},{pool:,force:,closure:,rel_closure}]...]
        ## end_seq_pools = end_seq     ## pool array [{pool:,force:,closure:}] or  [[{pool:,force:,closure:},{pool:,force:,closure:,rel_closure}]...]
        ## subpools = subpools          ## pool array [{pool:,force:,closure:,count:,countinue:}] or  [[{pool:,force:,closure:},{pool:,force:,closure:,rel_closure}]...]
        ## closure
        ## complete_begin_seq_closure = []
        ## complete_end_seq_closure = []
        ## complete_subpools_closure = []
        @outside_closure = outside_closure       ## eval at the end of parse
        @re_closure = nil           ## process match string and add to rest
        @dynamic_subseqs = []
        @parseresult = nil
        @pro_closure = pro_closure
        @error_closure = lambda { |origin_str| puts "解析#{name}错误 不期望 #{origin_str[0..19]} ...."}
    #    @complete_begin_seq_closure << lambda { printf "START PARSE #{@name} --> ";p @subpools.map{|item| item[:pool].name}}
    #    @complete_end_seq_closure   << lambda { puts "COMPLETE PARSE #{@name}"}
    end

    ## Class method
    def self.define_class_var(name,default=nil,define_check,vari_get)
        self.class.class_eval do
            define_method name do
                if define_check.call('@@'+name.to_s)
                    vari_get.call('@@'+name.to_s)
                else
                    default
                end
            end
        end
    end

    def self.class_var(default=nil,name)
        self.define_class_var(name,default,self.class_variable_defined?.to_proc,self.class_variable_get.to_proc)
    end

    def self.class_vars(default,&names)
        names.each do|item|
            self.class_var default,item
        end
    end

    def parse(parsepkt,open_error)
        ## dont parse same class nearby
        core_parse parsepkt do
            match
        end
        return @parseresult
    end


    def core_parse(parsepkt)
        @parseresult = ParseResult.new(result:nil,orgin:parsepkt[:origin],match:'',rest:parsepkt[:rest])
        @parseresult[:origin].sub!(/\A\s*/) do |mstr|
            curr_parsepkt[:rest] += mstr
            ''
        end
        @begin_archor = curr_parsepkt[:rest].length
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
             if     match_begin.[:result] == nil ||
                    match_subseqs.[:result] == nil ||
                    match_end.[:result] == nil
                return @parseresult
            end
         end
         @outside_closure.each {|item| item.call(@parseresult[:match])}
         @parseresult[:rest] += @re_closure.call(@parseresult[:match])
         return @parseresult
     end

     def match_seq(sequence,msg)
         curr_closure = []
         return @parseresult if sequence || sequence.empty?
         sequence.each do |baseseq_item|
             protein = baseseq_item.protein
             @parseresult.eat protein.parse(@parseresult)
             ## curr_protein match
             if @parseresult[:result]
                 ##resord closure
                 curr_closure << protein.pro_closure if protein.pro_closure
             else
                 ## curr_sequence not force
                 unless baseseq_item.force
                     @parseresult.error_stack = []
                     next
                 else
                     @parseresult.error_stack << lambda { @error_closure.call(@parseresult[:origin]) }
                     return  @parseresult
                 end
             end
         end
         curr_closure.each {|item| item.call }
         return  @parseresult
     end


    def match_begin
        match_seq(self.class.begin_seq_pools,"BEGIN")
        return @parseresult unless @parseresult[:result]
        self.class.complete_begin_seq_closure.each {|item| item.call(parsepkt[:match]) }
        return @parseresult
    end

    def match_end
        match_seq(self.class.end_seq_pools,"END")
        return @parseresult unless @parseresult[:result]
        (self.class.complete_end_seq_closure | @outside_closure).each {|item| item.call(parsepkt[:match]) }
        return @parseresult
    end

    def match_subseqs
        curr_closure = []
        parsepkt = @parseresult
        ## subpools status
        parse_execute = nil
        mask_seq_index = nil
        sub_seqs = self.class.subseqs | @dynamic_subseqs
        return parsepkt if sub_seqs || sub_seqs.empty?
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
                    if baseseq_item < subseqs_count
                        parsepkt.result = nil
                        parsepkt.skip = false
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
        self.class.complete_subseqs_closure.each {|item| item.call(parsepkt[:match])
        return  @parseresult = parsepkt
    end

end
