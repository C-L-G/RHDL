require "logic"
class ModuleIO < Logic

    def initialize(dire=:INPUT,width=32,value)
        if valus.is_a? LogicValue
            @dire = dire
            super width,value
        else
            @dire = dire
            @width  = width
            @value = value
            @init_value = @value
        end
    end

end
