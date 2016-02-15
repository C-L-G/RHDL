class LogicValue < Array
    ##attr_accessor :value
    X = :x
    Z = :z
    H = 1
    L = 0
    def initialize (length=0,def_value=:x)
        unless length == 0
            value = def_value.to_sym if def_value != 0 || def_value != 1
            chk_value = :x if value != :z
        else
            chk_value = :x
        end
        @logic_value = Array.new(length,chk_value)
    end

    def to_i
        str = "0"
        self.reverse.each do |item|
            case item
            when 0
                i = "0"
            when 1
                i = "1"
            when :x
                i = "1"
            when :z
                i = "0"
            else
                i = "0"
            end
            str += i
        end
        return Integer(str)
    end

    def + (arg)
        bad_len = bad_evaluator(self,arg)
        return LogicValue.new(bad_len+1) if bad_len
        (self.to_i + arg.to_i).to_l
    end

    def bad_evaluator(a,b)
        a_len = a.length
        b_len = b.length
        if a_len > b_len
            len = a_len
        else
            len=b_len
        end
        if a.include?(:x) || a.include?(:z) || b.include?(:x) || b.include?(:z)
            return len
        else
            return nil
        end
    end
end

class String
    def to_l
        a = LogicValue.new
        for i in 0...(self.length)
            case self[i]
            when "0"
                a << 0
            when "1"
                a << 1
            when "Z","z"
                a << :z
            when " ","_","-"
                next
            when "X","x",
                a << :x
            else
                a << :x
            end
        end
    end
end

class Fixnum
    def to_l
        a = LogicValue.new
        if self < 0
            num = self
        else
            num = 0-self-1
        end
        str = num.to_s(2)
        for i in 0...(str.length)
            case str[i]
            when "0"
                if self < 0
                    a << 1
                else
                    a << 0
                end
            when "1"
                if self < 0
                    a << 0
                else
                    a << 1
                end
            else
                next
            end
        end
    end
end
