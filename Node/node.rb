class Node
    @@node_hash = Hash.new
    attr_accessor :expression,:value,:clause_array
    def initialize
        @expression = nil
        @value = nil
        @clause_array = []
        @expression_flag = []
    end

    def self.create(id)
        抛出重定义错误 if @@node_hash[id.to_sym]
        @@node_hash[id.to_sym] = Node.new
    end

    def self.invoke(id)
        unless @@node_hash[id.to_sym]
            @@node_hash[id.to_sym] = Node.new
        else
            @@node_hash[id.to_sym]
        end
    end

    def refresh_parameter(sym)
        s = sym.to_sym
        @expression_flag.assoc[s] = true
        cf = @expression_flag.map { |item| item[1]}
        unless cf.include? nil
            begin
                @value = Proc.new { eval @expression}.call
            rescue
                抛出解析语法错误
            end
            @clause_array.each do |item|
                item.call
            end
        end
    end

    def self.parse_nodes(str)
        cstr = str.gsub(/\s*\.\.\.\s*/m,'')
        lines = cstr.split(/[\r\n]/)
        lines.each do |item|
            next if item =~ /^\s*&/
            Node.parse_node item
        end
    end

    def self.parse_node(str)
        cstr  = str.compact
        抛出语法异常 if cstr !~ /^(\w+)\s*=\s*(.+?)/
        ## 创建 新节点
        curr_node_id = $1.to_sym
        curr_node = Node.create curr_node_id
        curr_node.expression = curr_node.parse_node_exp($2)
    end

    def parse_number(type=:dec,width,value_str)
        ## set count
        if type == :hex
            count = 16
            re = /^[0-9a-f]+$/i
        elsif type == :dec
            count = 10
            re = /^\d+$/
        elsif type == :oct
            count = 8
            re = /^[0-7]+$/
        elsif type == :bin
            count = 2
            re = /^[0-1]+$/
        else
            count = 10
            re = /^[0-9]+$/
        end
        compact_str = value_str.gsub('_','')
        抛出数值错误 if compact_str !~ re
        bin_length = compact_str.to_i(count).to_s(2).length
        case width
        when nil
            dec_width = bin_length
        when /^\d+$/
            dec_width = width.to_i
            抛出位宽定义太小错误 if dec_width < bin_length
        else
            up_node = @@node_hash[width.to_sym]
            if up_node.value.integer?
                dec_width = up_node.value.integer
            else
                clause = lambda do
                    if @@node_hash[width.to_sym].value < bin_length
                        抛出位宽定义太小错误
                    end
                end
                up_node.clause_array << clause
                dec_width = "\#{#{width}}"
            end
        end
        compact_str.to_i(count)
    end

    def parse_node_exp(one_formula)
        num_dec_re = Regexp.union(  /\b(?<dec_1_width>\w+)(?i:'d)(?<dec_1_value>[\d_]+)\b/,
                                    /(?i:'d)(?<dec_2_value>[\d_]+)\b/,
                                    /\b(?<dec_3_value>[\d_]+)(?!')\b/)
        num_hex_re = Regexp.union(  /\b(?<hex_1_width>\w+)(?i:'h)(?i:(?<hex_1_value>[0-9a-f_]+))\b/,
                                    /(?i:'h)(?i:(?<hex_2_value>[0-9a-f_]+))\b/)
        num_oct_re = Regexp.union(  /\b(?<oct_1_width>\w+)(?i:'o)(?i:(?<oct_1_value>[0-7_]+))\b/,
                                    /(?i:'o)(?i:(?<oct_2_value>[0-7_]+))\b/)
        num_bin_re = Regexp.union(  /\b(?<bin_1_width>\w+)(?i:'b)(?i:(?<bin_1_value>[0-1_]+))\b/,
                                    /(?i:'b)(?i:(?<bin_2_value>[0-1_]+))\b/)
        node_id_re = /\b(?!')(?<node_id>\w+)(?!')\b/
        all_re = Regexp.union(num_dec_re,num_hex_re,num_oct_re,num_bin_re,node_id_re)
        st_formula = one_formula.gsub(all_re) do |item|
            curr_mch = $~
            num_width = curr_mch[:dec_1_width] || curr_mch[:hex_1_width] || curr_mch[:oct_1_width] || curr_mch[:bin_1_width]
            dec_value = curr_mch[:dec_1_value] || curr_mch[:dec_2_value] || curr_mch[:dec_3_value] ;
            hex_value = curr_mch[:hex_1_value] || curr_mch[:hex_2_value] ;
            oct_value = curr_mch[:oct_1_value] || curr_mch[:oct_2_value] ;
            bin_value = curr_mch[:bin_1_value] || curr_mch[:bin_2_value] ;
            num_value = dec_value || hex_value || oct_value || bin_value
            num_type = :dec if dec_value
            num_type = :hex if hex_value
            num_type = :oct if oct_value
            num_type = :bin if bin_value

            if num_value
                parse_number(num_type,num_width,num_value)
            else
                up_node  = Node.invoke item
                @expression_flag << [item.to_sym,nil]
                up_node.clause_array << lambda { refresh_parameter(item)}
                item
            end
        end
        return st_formula
    end

    ## define math
    def self.define_math_method(sym,&block)
        define_method sym do |next_node|
            抛出没有值错误 unless value
            抛出没有值错误 unless next_node.value
            block.call(next_node)
        end
    end

    math_array = ['+','-','*','/','%','**','|','&']
    begin
        math_array.each do |item|
            define_math_method item do |next_node|
                value.send(item,next_node.value)
            end
        end
    end

end
