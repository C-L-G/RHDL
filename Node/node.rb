class Node
    @@node_hash = Hash.new
    attr_accessor :expression,:value
    def initialize
        @expression = nil
        @value = nil
        @clause_array = []
        @expression_flag = []
    end

    def refresh_parameter(sym)
        s = sym.to_sym
        @expression_flag.assoc[s] = true
        cf = @expression_flag.map { |item| item[1]}
        unless cf.include? nil
            @value = @expression.call
            @clause_array.each do |item|
                item.call
            end
        end
    end

    def self.parse_node_name(str)
        cstr  = str.compact
        return if cstr !~ /^(\w+)\s*=\s*(.+?)(,|;)/m
        ## 创建 新节点
        curr_node_name = $1.to_sym
        unless @@node_hash[curr_node_name]
            @@node_hash[curr_node_name] = Node.new
        else
            if @@node_hash[curr_node_name].expression
                抛出重定义节点错误
            end
        end

    end

    def self.parse_node_exp(curr_node,str)
        cstr  = str.compact
        rep_last = /^(\w+)$/
        rep0 = /^(\w+)\s*(+|-|\*|\/|\*\*)\s*(.+)/
        rep1 = /^\(\s*(\w+)\s*\)\s*(+|-|\*|\/|\*\*)\s*(.+)/
        mch_last = rep_last.match(cstr)
        mch0 = rep0.match(cstr)
        mch1 = rep1.match(cstr)

        if mch_last
            if @@node_hash[mch_last[1].to_sym] && @@node_hash[mch_last[1].to_sym].value
                curr_node.value = @@node_hash[mch_last[1].to_sym].value
            else
                


end
