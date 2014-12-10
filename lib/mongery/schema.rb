module Mongery
  class Schema
    VALID_TYPES = ["array", "boolean", "integer", "number", "null", "object", "string"]

    def initialize(schema)
      @schema = schema
    end

    def property(col)
      @schema.properties[col]
    end

    def column_type(col)
      value = type_value(col)
      if VALID_TYPES.include?(value)
        value
      else
        nil
      end
    end

    def type_value(col)
      type = property(col).try(:type)
      case type
      when Array
        (type - ["null"]).first
      else
        type
      end
    end
  end
end
