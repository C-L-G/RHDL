require "basepool.rb"
class BondSeq
    attr_accessor :discontinue,:force
    def initialize(name:"Pool",force:nil,outside_closures:[],re_closure:nil,count:1,discontinue:false,pro_closure:nil)
        @force = force
        @outside_closures = outside_closures
        @re_closure = re_closure
        @count = count
        @discontinue = discontinue
        @name = name
    end

    def new(force:@force,discontinue:@discontinue)
        new_self = self.clone
        new_self.force = force
        new_self.discontinue = discontinue
        return new_self
    end

    def <(arg)
        if @count
            @count < arg
        else
            false
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
    def initialize( name:"Single",re:nil,force:true,outside_closures:[],re_closure:nil,count:nil,
                    discontinue:false,pro_closure:nil,match_space:nil)
        @re = re
        @apool = Class.new(AtomPool)
        @apool.class_variable_set("@@match_space",match_space)
        super(name:name,force:force,outside_closures:outside_closures,re_closure:re_closure,count:count,discontinue:discontinue,pro_closure:pro_closure)
    end

    def protein
        new_protein = @apool.new(name:@name,re:@re,outside_closures:@outside_closures,re_closure:@rel_closure)
    end
end

class PoolBondSeq < BondSeq

    def initialize (name:"Pool",pool_class:nil,force:true,outside_closures:[],re_closure:nil,count:1,discontinue:false,pro_closure:nil)
        @pool_class = pool_class
        super(name:name,force:force,outside_closures:outside_closures,re_closure:re_closure,count:count,discontinue:discontinue,pro_closure:pro_closure)
    end

    def protein
        new_protein = @pool_class.new(name:@name,outside_closures:@outside_closures,pro_closure:@pro_closure,re_closure:@rel_closure)
    end
end

class TwinPoolSeq < BondSeq

    def initialize(name:"Twin",twinpools_class:nil,force:true,outside_closures:[],re_closure:nil,count:1,discontinue:false,pro_closure:nil)
        @pools_class = twinpools_class  ## parsepool array
        super(name:name,force:force,outside_closures:outside_closures,re_closure:re_closure,count:count,discontinue:discontinue,pro_closure:pro_closure)
    end

    def protein
        new_pools = @pools_class.map do |class_item|
            class_item.new(name:@name,outside_closures:@outside_closures,pro_closure:@pro_closure,re_closure:@re_closure)
        end
        twin_protein = TwinPool.new(name:@name,twinpools:new_pools,outside_closures:@outside_closures,pro_closure:@pro_closure,re_closure:@re_closure)
    end
end
