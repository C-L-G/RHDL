require "LogicValue"
class Logic
    attr_reader :width, :init_value
    attr_accessor :value

    def initialize(width=1,value=LogicValue.new)
        if width.integer?
            @width  = width
        elsif width =~ /\[(.+?)(?!+|-):(.+?)]/

        if value.is_a? LogicValue
            @value = value
        else
            response_warnning "ERROR VALUE FOR WIRE DEFINE"
            @value = LogicValue.new :x
        end
        @init_value = @value
    end

end

def parse_evaluator(module_id,str)
    cstr  = str.compact
    if cstr =~ /^(\w+)\s*=\s*(\w+)\s*(+|-|\*|\/|\*\*)\s*(.+)/
        if module_id.respond_to? $1
            width = module_id.logic_width($1)
            case $2
            when '+','-'
                rel_width =
            "#{module_id.send($1)} #{$2} #{parse_evaluator(module_id,$3)}"
        else
            "#{$1} #{$2} #{parse_evaluator(module_id,$3)}"
        end
    end
end

def parse_simple_evaluator(module_id,str)
    cstr  = str.compact
    rep_last = /^\w+$/
    rep0 = /^(\w+)\s*(+|-|\*|\/|\*\*)\s*(.+)/
    rep1 = /^\(\s*(\w+)\s*\)\s*(+|-|\*|\/|\*\*)\s*(.+)/
    mch_last = rep_last.match(cstr)
    mch0 = rep0.match(cstr)
    mch1 = rep1.match(cstr)

    if mch_last
        unless mch_last[1] =~ /[0-9]+/
            if module_id.respond_to? mch_last[1]
                "#{module_id.parameters.send(mch_last[1])}"
            else
                抛出没有定义参数异常
            end
        else
            "#{mch_last[1].to_i}"
        end
    elsif mch0
        unless mch0[1] =~ /[0-9]+/
            if module_id.respond_to? mch0[1]
                "#{module_id.parameters.send(mch0[1])} #{mch0[2]} #{parse_simple_evaluator(module_id,mch0[3])}"
            else
                抛出没有定义参数异常
            end
        else
            "#{mch0[1].to_i} #{mch0[2]} #{parse_simple_evaluator(module_id,mch0[3])}"
        end
    elsif mch1
        "#{parse_simple_evaluator(module_id,mch1[1])} #{mch1[2]} #{parse_simple_evaluator(module_id,mch1[3])}"
    else
        ""
    end
end

class LogicArray
    attr_reader :sizes

    def initialize (wire_item = Logic.new,size = [])
        if wire_item.is_a? Logic
            @logic_array []
            size.each do |item|
                抛出非数字异常 unless item.integer?

            end
        end
    end

    def gen_array (def_value = Logic.new,array_size = [])
        抛出警告  非wire型 unless wire_item.is_a? Logic
        if array_size.size == 1
            Array.new(array_size.shift,def_value)
        else
            Array.new(array_size.first,gen_array(def_value,array_size))
        end
    end
end
