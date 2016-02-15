require "parameter"
require "ModuleIO"

class HdlModule
    attr_reader :name,:parameters,:interface

    def initialize (name)
        @name = name
        @parameters = Parameters.new
        @interface = ModuleIO.new
    end
end
