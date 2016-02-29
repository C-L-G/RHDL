class BaseSeq

    def initialize (poolseq:BasePool.new,force:true,closure:nil,rel_closure:nil)
        @poolseq = poolseq
        @force = force
        @outside_closure = closure
        @rel_closure = rel_closure
    end

    def protein
        if @poolseq.is_a? ParsePool
            new_protein = @poolseq.new
            new_protein.force = @force
            new_protein.outside_closure = hash_item[:closure]
            return new_protein
        elsif @poolseq.is_a? Regexp
            new_protein = MiniPool.new(@poolseq,@force,@outside_closure)
        elsif @poolseq.is_a? Array
            new_proteins = @poolseq.map do |item|
                new_protein = item.new
                new_protein.force = @force
                new_protein.outside_closure = hash_item[:closure]
                new_protein
                return new_protein
            end
        end
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

            if (@parseresult[:result]==nil) && @force
                @parseresult[:error]  = lambda { raise "#{@name} dont expect >>>"+@parseresult[:origin][0..19]+'......'}
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

class TwinPool

    def initialize(twinpools,force,outside_closure)
        @pools = twinpools
        @force = force
        @outside_closure = outside_closure
        @parseresult = ParsseResult.new
    end

    def parse(parsepkt,record_error,report_error)
        @parseresult = parsepkt
        with_new_record_report record_error,report_error do
            @pools.each do |pool|
                @parseresult = pool.parse @parseresult,true,report_error
                if @parseresult[:result]
                    break
                end
            end
