require "mongery/version"
require "mongery/schema"
require "arel"

module Mongery
  class Builder
    attr_reader :model, :table, :schema, :mapped_properties

    def initialize(model, engine = ActiveRecord::Base, schema = nil)
      @model = model
      @table = Arel::Table.new(model, engine)
      @schema = Schema.new(schema) if schema
      @mapped_properties = {}
    end

    def mapped_properties=(value)
      case value
      when Array
        @mapped_properties = Hash[ value.map { |v| [v.to_s, v] } ]
      else
        @mapped_properties = value
      end
    end

    def find(*args)
      Query.new(table, schema, mapped_properties).where(*args)
    end

    def insert(*args)
      Query.new(table, schema, mapped_properties).insert(*args)
    end
  end

  class Query
    attr_reader :table, :schema, :mapped_properties

    def initialize(table, schema, mapped_properties)
      @table = table
      @schema = schema
      @mapped_properties = mapped_properties
      @condition = nil
    end

    def where(args)
      @where = args
      self
    end

    def arel
      @arel ||= build_arel
    end

    def to_arel
      arel
    end

    def to_sql
      to_arel.to_sql
    end

    def limit(number)
      arel.take(number)
      self
    end

    def skip(number)
      arel.skip(number)
      self
    end

    def sort(params)
      params.each do |col, val|
        order = val > 0 ? :asc : :desc
        case col.to_s
        when "_id"
          arel.order(table[:id].send(order))
        else
          arel.order(sql_json_path(col).send(order))
        end
      end
      self
    end

    def mapped_values(args)
      pairs = []
      mapped_properties.each do |key, column|
        pairs.push([table[column], args[key]]) if args.key?(key)
      end
      pairs
    end
    private :mapped_values

    def insert(args)
      Arel::InsertManager.new(table.engine).tap do |manager|
        manager.into(table)
        manager.insert([[table[:id], args['_id']], [table[:data], args.to_json], *mapped_values(args)])
      end
    end

    def update(args)
      Arel::UpdateManager.new(table.engine).tap do |manager|
        manager.table(table)
        manager.set([[table[:data], args.to_json], *mapped_values(args)])
        manager.where(condition) if condition
      end
    end

    def delete
      Arel::DeleteManager.new(table.engine).tap do |manager|
        manager.from(table)
        manager.where(condition) if condition
      end
    end

    private

    def mapped_keys
      mapped_properties.keys
    end

    def condition
      @condition ||= translate(@where)
    end

    def build_arel
      table.project(table[:data]).tap do |t|
        t.where(condition) if condition
      end
    end

    def translate(query)
      chain(:and, query.map {|col, value| translate_cv(col, value) })
    end

    def translate_cv(col, value)
      case col.to_s
      when "$or"
        chain(:or, value.map {|q| translate(q) })
      when "$and"
        chain(:and, value.map {|q| translate(q) })
      when /^\$/
        raise UnsupportedQuery, "Unsupported operator #{col}"
      when "_id"
        translate_value(table[:id], value)
      when *mapped_keys
        translate_value(table[mapped_properties[col.to_s]], value)
      else
        if schema
          translate_value_schema(col, sql_json_path(col), value)
        else
          translate_value_dynamic(sql_json_path(col), value)
        end
      end
    end

    OPERATOR_MAP = {
      "$in" => :in, "$eq" => :eq, "$ne" => :not_eq,
      "$gt" => :gt, "$gte" => :gteq, "$lt" => :lt, "$lte" => :lteq,
    }

    def translate_value(col, value)
      case value
      when Hash
        if has_operator?(value)
          chain(:and, value.map {|op, val|
                  if OPERATOR_MAP.key?(op)
                    col.send(OPERATOR_MAP[op], val)
                  else
                    raise UnsupportedQuery, "Unknown operator #{op}"
                  end
                })
        else
          col.eq(value.to_json)
        end
      else
        col.eq(value)
      end
    end

    def translate_value_dynamic(col, value)
      case value
      when String, TrueClass, FalseClass
        compare(col, value.to_s, :eq)
      when Numeric, NilClass
        compare(col, value, :eq)
      when Hash
        if has_operator?(value)
          chain(:and, value.map {|op, val|
                  case op
                  when "$in"
                    if val.all? {|v| v.is_a? Numeric }
                      wrap(col, val.first).in(val)
                    else
                      col.in(val.map(&:to_s))
                    end
                  when "$eq", "$ne", "$gt", "$gte", "$lt", "$lte"
                    compare(col, val, OPERATOR_MAP[op])
                  else
                    raise UnsupportedQuery, "Unknown operator #{op}"
                  end
                })
        else
          col.eq(value.to_json)
        end
      else
        col.eq(value.to_json)
      end
    end

    def translate_value_schema(column, col, value)
      type = schema.column_type(column.to_s)
      case value
      when Hash
        if has_operator?(value)
          chain(:and, value.map {|op, val|
                  case op
                  when "$in"
                    case type
                    when "array"
                      chain(:or, val.map { |v| col.matches(%Q[%"#{v}"%]) })
                    else
                      compare_schema(col, val, type, :in)
                    end
                  when "$eq", "$ne", "$gt", "$gte", "$lt", "$lte"
                     compare_schema(col, val, type, OPERATOR_MAP[op])
                  else
                    raise UnsupportedQuery, "Unknown operator #{op}"
                  end
                })
        else
          col.eq(value.to_json)
        end
      when String, Numeric, NilClass
        compare_schema(col, value, type, :eq)
      else
        compare_schema(col, value.to_json, type, :eq)
      end
    end

    def translate_value_dynamic(col, value)
      case value
      when String, TrueClass, FalseClass
        col.eq(value.to_s)
      when Numeric, NilClass
        compare(col, value, :eq)
      when Hash
        if has_operator?(value)
          chain(:and, value.map {|op, val|
                  case op
                  when "$in"
                    if val.all? {|v| v.is_a? Numeric }
                      wrap(col, val.first).in(val)
                    else
                      col.in(val.map(&:to_s))
                    end
                  when "$eq", "$ne", "$gt", "$gte", "$lt", "$lte"
                    compare(col, val, OPERATOR_MAP[op])
                  else
                    raise UnsupportedQuery, "Unknown operator #{op}"
                  end
                })
        else
          col.eq(value.to_json)
        end
      else
        col.eq(value.to_json)
      end
    end

    def has_operator?(value)
      value.keys.any? {|key| key =~ /^\$/ }
    end

    def compare(col, val, op)
      wrap(col, val).send(op, val)
    end

    def wrap(col, val)
      case val
      when NilClass
        # data#>>'{foo}' IS NULL    is invalid
        # (data#>>'{foo}') IS NULL  is valid
        Arel.sql("(#{col})")
      when Numeric
        Arel.sql("(#{col})::numeric")
      else
        col
      end
    end

    def compare_schema(col, val, type, op)
      case type
      when "string"
        Arel.sql("(#{col})").send(op, val)
      when "number", "integer"
        Arel.sql("(#{col})::numeric").send(op, val)
      else
        case val
        when Numeric
          Arel.sql("(#{col})").send(op, val.to_s)
        else
          Arel.sql("(#{col})").send(op, val)
        end
      end
    end

    def sql_json_path(col)
      paths = col.to_s.split('.')
      Arel.sql("data#>>#{json_pathize(paths)}")
    end

    def json_pathize(paths)
      quote("{#{paths.join(',')}}")
    end

    def quote(str)
      # FIXME there should be a better way to do this
      table.engine.connection.quote(str)
    end

    def chain(op, conditions)
      result = nil
      conditions.each do |cond|
        result = result ? result.send(op, cond) : cond
      end
      result
    end
  end

  class UnsupportedQuery < StandardError
  end
end
