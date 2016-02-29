class BasePool
    @@curr_subpools = nil
    @@record_error = true
    @@report_error = true
    @@pe = lambda {puts "No Error"}
    class_vars [],:begin_seq_pools,:end_seq_pools,:subpools,:complete_begin_seq_closure,:complete_end_seq_closure,:complete_subpools_closure
    class_vars nil,:inherit_subpools
    def initialize(name:"Pool")
        ## init
                                         ## BaseSeq [bs0,bs1]
        ## begin_seq_pools = begin_seq   ## pool array [{pool:,force:,closure:}] or  [[{pool:,force:,closure:},{pool:,force:,closure:,rel_closure}]...]
        ## end_seq_pools = end_seq     ## pool array [{pool:,force:,closure:}] or  [[{pool:,force:,closure:},{pool:,force:,closure:,rel_closure}]...]
        ## subpools = subpools          ## pool array [{pool:,force:,closure:,count:,countinue:}] or  [[{pool:,force:,closure:},{pool:,force:,closure:,rel_closure}]...]
        ## closure
        ## complete_begin_seq_closure = []
        ## complete_end_seq_closure = []
        ## complete_subpools_closure = []
        @force = true
        @outside_closure = []
        @dynamic_subpools = []
        @parseresult = ParsseResult.new
        @complete_begin_seq_closure << lambda { printf "START PARSE #{@name} --> ";p @subpools.map{|item| item[:pool].name}}
        @complete_end_seq_closure   << lambda { puts "COMPLETE PARSE #{@name}"}
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

    def self.gen_protein_pool(hash_item)
        protein = hash_item[:pool].new
        protein.force = hash_item[:force]
        protein.outside_closure = hash_item[:closure]
        return protein
    end

    def parse(parsepkt,open_error)
        core_parse(parsepkt,args.join(block)) do
            match
            if @parsepkt[:result] == nil
                if open_error
                    @@pe = @parsepkt[:error]
                    @@pe.call
                else
                    @@pe = @parsepkt[:error]
                end
            end
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
        core_parse(parsepkt) do
            if match
                return @parseresult
            else
                return nil
            end
        end
    end

    def core_parse(parsepkt,&block)
        @parseresult = ParseResult.new(result:nil,orgin:parsepkt[:origin],match:'',rest:parsepkt[:rest])
        @parseresult[:origin].sub!(/\A\s*/) do |mstr|
            curr_parsepkt[:rest] += mstr
            ''
        end
        @begin_archor = curr_parsepkt[:rest].length
        yield
    end

    def set_envs
        if inherit_subpools
             @dynamic_subpools = @@curr_subpools
         else
             @up_subpools =  @@curr_subpools    ## hand up
             @@curr_subpools = subpools ## sync subp
         end
     end

     def reset_envs
         unless inherit_subpools
             @@curr_subpools = @up_subpools ## hand down
         end
     end

     def with_new_envirement(&block)
         up_subpools =  @@curr_subpools
         if inherit_subpools
              @dynamic_subpools = @@curr_subpools
          else
              @@curr_subpools = subpools
          end
         yield
         @@curr_subpools = up_subpools
     end

    def match_seq(sequence,msg)
        curr_closure = []
        parsepkt = @parseresult
        return parsepkt if sequence || sequence.empty?
        sequence.each do |baseseq_item|
            protein = baseseq_item.protein
            array_force = nil
            if item[:pool].is_a? Regexp
                parsepkt.match! item[:pool],item[:rel_closure] do |args|
                    if item[:closure]
                        curr_closure << lambda { item[:closure].call(*args)}
                    end
                end
            elsif item[:pool].is_a? ParsePool
                protein = item[:pool].protein
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
                parsepkt[:error]  = lambda { raise "#{@name} 没有解析Force错误 #{msg} >>>"+parsepkt[:origin][0..19]+'......'}
                return @parseresult = parsepkt
            end
        end
        curr_closure.each do |item|
            item.call
        end
        return  @parseresult = parsepkt
    end

    def match_begin
        @@record_error = nil
        match_seq(self.class.begin_seq_pools,"BEGIN")
        return @parseresult unless @parseresult[:result]
        self.class.complete_begin_seq_closure.each {|item| item.call(parsepkt[:match]) }
        @@record_error = true
    end

    def match_end
        @@record_error = nil
        match_seq(self.class.end_seq_pools,"END")
        return @parseresult unless @parseresult[:result]
        self.class.complete_end_seq_closure.each {|item| item.call(parsepkt[:match]) }
        @@record_error = true
    end

    def match_subpools
        tmp_record = @@record_error
        @@record_error = true
        curr_closure = []
        parsepkt = @parseresult
        ## subpools status
        parse_execute = nil
        force_execute = nil
        continue_execute = nil
        sub_pools = self.class.subpools
        return parsepkt if sub_pools || sub_pools.empty?
        subpools_count = sub_pools.map{|item| item[:count]}
        subpools_force = sub_pools.map{|item| item[:force]}
        last_parse_sub = nil
        cc = Proc.new do |pool,index,origin_str|
            parse_execute = true
            if subpools_count[index] && subpools_count[index].integer?
                unless subpools_count[index] > 0
                    parsepkt[:error] = lambda { raise "#{@name} #{pool} 多次解析错误:"+(origin_str.lstrip)[0..19]+'...'}
                    return @parseresult = parsepkt
                end
                subpools_count[index] -= 1
            end
            force_execute[index] = nil
            if last_parse_sub == index
                parsepkt[:error] == lambda { raise "#{@name} #{pool} 连续解析错误:"+(origin_str.lstrip)[0..19]+'...' if curr_subp[:countinue] }
                return @parseresult = parsepkt
            end
            last_parse_sub = index
        end
        ## loop
        begin
            parse_execute = nil
            (sub_pools|@dynamic_subpools).each_index do |index|
                curr_subp = sub_pools[index]
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
            parsepkt[:error] = lambda { raise "#{@name}>>没有解析错误:"+(parsepkt[:origin].lstrip)[0..9]+'...' }
            return @parseresult = parsepkt
        end
        (@outside_closure|@complete_subpools_closure).each{|item| item.call(parsepkt[:match]) }
        @@record_error = tmp_record
        return  @parseresult = parsepkt
    end

end
