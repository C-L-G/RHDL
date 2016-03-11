class PoolSlot
    attr_accessor :discontinue,:force
    def initialize(pool:nil,force:nil,outside_closures:[],count:nil,discontinue:false)
        @force = force
        @outside_closures = outside_closures
        @count = count
        @discontinue = discontinue
        @pool = pool
    end

    def add_to_begin_of(pool)
        pool.begin_seq_pools << self
        return pool
    end

    def add_to_end_of(pool)
        pool.end_seq_pools << self
        return pool
    end

    def add_to_subseqs_of(pool)
        pool.subseqs << self
        return pool
    end

    def active
        @pool.new(force:@force,discontinue:@discontinue,count:@count,outside_closures:@outside_closures)
    end
end


end
