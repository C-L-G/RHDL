class Rhdl

    def parse_module(hdl_file)
        抛出文件异常 unless hdl_file.is_a? HdlFile
        find_head = lambda {|str| str == /module\s/}
        find_end  = lambda {|str| str == /\sendmodule/}
        find_couple=lambda {|str| str == /module\s+(\w+)(.*?)\sendmodule/ || str == /module\s+(\w+).+?endmodule/}
        find_parameter=lambda {|str| str == /module\s+\S+\s*\#\s*\(\s*(parameter.+?)\)\s*\(/m}
        find_interface=lambda {|str| str == /module\s+\S+\s*\#\s*\(\s*parameter.+?\)\s*\((.*?)\)\s*;\s*(.*?)endmodule/m ||
                                     str == /module\s+\S+\s*\((.*?)\)\s*;\s*(.*?)endmodule/m}
        unless find_head.call(hdl_file.compact__rest_code)
            抛出无模块头警告
            退出文件解析
        end
        抛出无模块尾错误 unless find_end.call(hdl_file.compact__rest_code)
        抛出模块定义错误 unless find_couple.call(hdl_file.compact__rest_code)
        create_hld_module $2
        parse_parameter($2,$1) if find_parameter.call(hdl_file.compact__rest_code)
        parse_interface($1) if find_interface.call(hdl_file.compact__rest_code)
        parse_code($2)
    end

    def del_comment(str)
        str.gsub(Regexp.new('/\*.*?\*/',Regexp::MULTILINE),'').gsub(/\/\/.*/,'')
    end

    def create_hld_module(name)
        抛出模块重定义错误 if hld_module_hash.[name.to_sym]
        抛出无模块名错误 if name == nil
        hld_module_hash.[name.to_sym] = HdlModule.new(name)
    end

    def parse_parameter (module_name,str)
        str == /parameter\s*(\[.+?\])?\s*\w+\s*=\s*\w+/
        curr_module = hld_module_hash[module_name.to_sym]
        str.split(',').each do |item|
            抛出参数解析错误 unless item == /^\s*parameter\s*(\[.+?\])?\s*(\w+)\s*=\s*(\w+)\s*$/m
            抛出参数重定义异常 if curr_module.parameter.instance_variables.include? $2
            curr_module.parameter.send($2+'=',width:$1,value:$3)
        end
    end



end
