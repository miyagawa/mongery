require "mongery/version"
require "arel"

module Mongery
  class Builder
    attr_reader :model, :table

    def initialize(model, engine = ActiveRecord::Base)
      @model = model
      @table = Arel::Table.new(model, engine)
    end

    def find(*args)
      Query.new(table).where(*args)
    end

    def insert(*args)
      Query.new(table).insert(*args)
    end
  end

  class Query
    attr_reader :table

    def initialize(table)
      @table = table
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

    def insert(args)
      Arel::InsertManager.new(table.engine).tap do |manager|
        manager.into(table)
        manager.insert([[table[:id], args[:_id]], [table[:data], args.to_json]])
      end
    end

    def update(args)
      Arel::UpdateManager.new(table.engine).tap do |manager|
        manager.table(table)
        manager.set([[table[:data], args.to_json]])
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
      when "_id"
        translate_value(table[:id], value)
      when "$or"
        chain(:or, value.map {|q| translate(q) })
      when "$and"
        chain(:and, value.map {|q| translate(q) })
      when /^\$/
        raise UnsupportedQuery, "Unsupported operator #{col}"
      else
        translate_value_json(sql_json_path(col), value)
      end
    end

    def translate_value(col, value)
      case value
      when Hash
        ops = value.keys
        if ops.size > 1
          raise UnsupportedQuery, "Multiple operator supported: #{ops.join(", ")}"
        end

        val = value[ops.first]
        case ops.first
        when "$in"
          col.in(val)
        when "$gt", "$gte", "$lt", "$lte"
          col.send(COMPARE_MAPS[ops.first], val)
        when "$eq"
          col.eq(val)
        when "$ne"
          col.not_eq(val)
        when /^\$/
          raise UnsupportedQuery, "Unknown operator #{ops.first}"
        end
      else
        col.eq(value)
      end
    end

    COMPARE_MAPS = { "$gt" => :gt, "$gte" => :gteq, "$lt" => :lt, "$lte" => :lteq }

    def translate_value_json(col, value)
      case value
      when String, Numeric, TrueClass, FalseClass
        # in Postgres 9.3, you can't compare numeric
        col.eq(value.to_s)
      when NilClass
        # You can't use IS NULL
        col.eq('')
      when Hash
        ops = value.keys
        if ops.size > 1
          raise UnsupportedQuery, "Multiple operator supported: #{ops.join(", ")}"
        end

        val = value[ops.first]
        case ops.first
        when "$in"
          chain(:or, val.map {|val| col.matches(%Q[%"#{val}"%]) })
        when "$gt", "$gte", "$lt", "$lte"
          wrap_numeric(col, val).send(COMPARE_MAPS[ops.first], val)
        when "$eq"
          wrap_numeric(col, val).eq(val)
        when "$ne"
          wrap_numeric(col, val).not_eq(val)
        when /^\$/
          raise UnsupportedQuery, "Unknown operator #{ops.first}"
        end
      end
    end

    def wrap_numeric(col, val)
      case val
      when Float
        Arel.sql("(#{col})::float")
      when Integer
        Arel.sql("(#{col})::integer")
      else
        col
      end
    end

    def sql_json_path(col)
      paths = col.to_s.split('.')
      if paths.size > 1
        Arel.sql("data#>>#{json_pathize(paths)}")
      else
        Arel.sql("data->>#{quote(paths.first)}")
      end
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
