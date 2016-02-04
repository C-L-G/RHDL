class Wire
    attr_reader :width, :init_value
    attr_accessor :value

    def initialize(width=1,value=LogicValue.new)
        @width  = width
        if value.is_a? LogicValue
            @value = value
        else
            response_warnning "ERROR VALUE FOR WIRE DEFINE"
            @value = LogicValue.new :x
        end
        @init_value = @value
    end

end

class WireArray
    attr_reader :sizes

    def initialize (wire_item = Wire.new,size = [])
        if wire_item.is_a? Wire
            @wire_array []
            size.each do |item|
                抛出非数字异常 unless item.is_a? Number

            end
        end
    end

    def gen_array (def_value = Wire.new,array_size = [])
        抛出警告  非wire型 unless wire_item.is_a? Wire
        if array_size.size == 1
            rel_array = []
            array_size.shift.times do
