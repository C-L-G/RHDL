class BondSeq
    attr_accessor :discontinue
    def initialize(force:nil,outside_closures:[],re_closure:nil,count:1,discontinue:false,pro_closure:nil)
        @force = force
        @outside_closures = outside_closures
        @rel_closure = rel_closure
        @count = count
        @discontinue = discontinue
    end

    def <(arg)
        if @count
            @count < arg
        else
            true
        end
    end

    def >(arg)
        if @count
            @count > arg
        else
            false
        end
    end

end

class SingleBondSeq < BondSeq

    def initialize (re:nil,force:true,closure:nil,rel_closure:nil,count:1,discontinue:false)
        @re = re
        super(force:force,closure:closure,rel_closure:rel_closure,count:count,discontinue:discontinue)
    end

    def protein
        new_protein = AtomPool.new(re:@re,outside_closures:@outside_closures,re_closure:@rel_closure)
    end
end

class PoolBondSeq < BondSeq

    def initialize (pool_class:nil,force:true,closure:nil,rel_closure:nil,count:1)
        @pool_class = pool_class
        super(force:force,closure:closure,rel_closure:rel_closure,count:count,discontinue:discontinue)
    end

    def protein
        new_protein = @pool_class.new
        new_protein.force = @force
        new_protein.outside_closures = @outside_closures
        new_protein.rel_closure = @rel_closure
        return new_protein
    end
end

class TwinPoolSeq

    def initialize(twinpools:nil,force:true,:closure,nil,rel_closure:nil,count:1,discontinue:false)
        @pools = twinpools  ## parsepool array
        super(force:force,closure:closure,rel_closure:rel_closure,count:count,discontinue:discontinue)
        @pools.each do |pool_item|
            pool_item.outside_closures = @outside_closures
            pool_item.rel_closure = @rel_closure
        end
    end

    def protein
        twin_protein = TwinPool.new(@pools,@force,@outside_closures)
    end
end

class AtomPool < BasePool
    def initialize(name:"AtomPool",re:nil,outside_closures:[],pro_closure:nil,re_closure:nil)
        super(name:name,outside_closures:outside_closures,pro_closure:pro_closure,re_closure:re_closure)
        @re = re
        #@parseresult = ParsseResult.new
    end

    def parse(parsepkt)
        @parseresult = parsepkt
        @parseresult.match @re,@re_closure,@pro_closure
        if @parseresult[:result]
            @outside_closures.each {|item| item.call(@parseresult[:match])}
        end
        return @parseresult
    end

end

class TwinPool < BasePool

    def initialize(name:"TwinPool",twinpools:[],outside_closures:[],pro_closure:nil)
        super(name:name,outside_closures:outside_closures,pro_closure:pro_closure,re_closure:re_closure)
        @pools = twinpools  ## parsepool array
        @pools.each do |pool_item|
            pool_item.outside_closures = outside_closures
            pool_item.force = nil
        end
    end

    def parse(parsepkt)
        @parseresult = parsepkt
        @pools.each do |pool|
            rel =  pool.parse(@parseresult)
            if rel[:result]
                @parseresult.eat rel
                break
            end
        end
        return @parseresult
    end
end
