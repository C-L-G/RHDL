class SingleBondSeq

    def initialize (re:nil,force:true,closure:nil,rel_closure:nil)
        @re = re
        @force = force
        @outside_closure = closure
        @rel_closure = rel_closure
    end

    def protein
        new_protein = MiniPool.new(@re,@force,@outside_closure)
    end
end

class PoolBondSeq

    def initialize (pool_class:nil,force:true,closure:nil,rel_closure:nil)
        @pool_class = pool_class
        @force = force
        @outside_closure = closure
        @rel_closure = rel_closure
    end

    def protein
        new_protein = @pool_class.new
        new_protein.force = @force
        new_protein.outside_closure = @outside_closure
        return new_protein
    end
end

class TwinPoolSeq

    def initialize(twinpools,outside_closure)
        @pools = twinpools  ## parsepool array
        @force = force
        @outside_closure = outside_closure
        @parseresult = ParsseResult.new
        @pools.each do |pool_item|
            pool_item.outside_closure = outside_closure
        end
    end

    def protein
        twin_protein = TwinPool.new(@pools,@force,@outside_closure)
    end
end

class MiniPool < BasePool
    def initialize(re,force,outside_closure)
        super "MiniPool"
        @re = re
        @force = force
        @outside_closure = outside_closure
        @parseresult = ParsseResult.new
    end

    def with_new_record_report (record,report,&block)
        stack_record = @@record_error
        stack_report = @@report_error
        @@record_error  = record
        @@report_error  = report
        yield
        @@record_error  = stack_record
        @@report_error  = stack_report
    end

    def parse(parsepkt,record_error,report_error)
        @parseresult = parsepkt
        with_new_record_report record_error,report_error do
            @parseresult.match! @re,@rel_closure do |args_array|
                if @closure
                    curr_closure << lambda { @closure.call(*args_array)}
                end
            end
            if @force
                if (@parseresult[:result]==nil)
                    @parseresult[:error]  = lambda { raise "#{@name} dont expect >>>"+@parseresult[:origin][0..19]+'......'}
                end
            else
                @parseresult[:result]== :force
            end
            
            if record_error
                @@pe = @parseresult[:error]
            end

            if report_error
                @@pe.call
            end
        end
        return @parseresult
    end

end

class TwinPool < BasePool

    def initialize(twinpools,force,outside_closure)
        @pools = twinpools  ## parsepool array
        @force = force
        @outside_closure = outside_closure
        @parseresult = ParsseResult.new
        @pools.each do |pool_item|
            pool_item.outside_closure = outside_closure
            pool_item.force = nil
        end
    end

    def parse(parsepkt,record_error,report_error)
        @parseresult = parsepkt
        pool_execute = nil
        with_new_record_report record_error,report_error do
            @pools.each do |pool|
                @parseresult = pool.parse @parseresult,true,report_error
                if @parseresult[:result]
                    pool_execute = true
                    break
                end
            end
        end
        return @parseresult
    end
end
