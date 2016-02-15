require "logic"
class Parameters
    include LogicValue

    def initialize
        @para_hash = Hash.new
    end

    def method_missing(method_id,*args)
        if method_id.to_s =~ /^(\w+)=$/
            @para_hash[$1] = Parameter.new(args[0],args[1])
            define_method method_id do |arg|
                @para_hash[$1] = arg.to_l  <<<<<<<<
            end
            define_method $1 { @para_hash[$1] }
        elsif method_id.to_s =~ /^\w+$/
            @para_hash[$1] = Parameter.new(32,nil)
            define_method method_id { @para_hash[$1] }
        else
            抛出参数名字错误
        end
    end
end

class Parameter < Logic

    def initialize(width=32,value)
        if valus.is_a? LogicValue
            super width,value
        else
            @width  = width
            @value = value
            @init_value = @value
        end
    end
end
