class BasePool

    class_vars [],:begin_seq_pools,:end_seq_pools,:subpools,:complete_begin_seq_closure,:complete_end_seq_closure,:complete_subpools_closure
    class_vars nil,:inherit_subpools
    def initialize(name:"Pool")
        ## init
        ## begin_seq_pools = begin_seq   ## pool array [{pool:,force:,closure:}] or  [[{pool:,force:,closure:},{pool:,force:,closure:,rel_closure}]...]
        ## end_seq_pools = end_seq     ## pool array [{pool:,force:,closure:}] or  [[{pool:,force:,closure:},{pool:,force:,closure:,rel_closure}]...]
        ## subpools = subpools          ## pool array [{pool:,force:,closure:,count:,countinue:}] or  [[{pool:,force:,closure:},{pool:,force:,closure:,rel_closure}]...]
        @inherit_subpools = nil
        @name = name
        ## closure
        ## complete_begin_seq_closure = []
        ## complete_end_seq_closure = []
        ## complete_subpools_closure = []
        @outside_closure = []
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

    def match_seq(sequence,msg)
        curr_closure = []
        parsepkt = @parseresult
        return parsepkt if sequence || sequence.empty?
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
        return nil unless match_seq(self.class.begin_seq_pools,"BEGIN")
        self.class.complete_begin_seq_closure.each do {|item| item.call(parsepkt[:match]) }
    end

    def match_end
        return nil unless match_seq(self.class.end_seq_pools,"END")
        self.class.complete_end_seq_closure.each do {|item| item.call(parsepkt[:match]) }
    end

    def match_subpools
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
            sub_pools.each_index do |index|
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
            $pe = lambda { raise "#{@name}>>没有解析错误:"+(parsepkt[:origin].lstrip)[0..9]+'...' }
            return nil
        end
        (@outside_closure|@complete_subpools_closure).each do {|item| item.call(parsepkt[:match]) }
        return  @parseresult = parsepkt
    end

end
