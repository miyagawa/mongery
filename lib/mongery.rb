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
      when "$or"
        chain(:or, value.map {|q| translate(q) })
      when "$and"
        chain(:and, value.map {|q| translate(q) })
      when /^\$/
        raise UnsupportedQuery, "Unsupported operator #{col}"
      when "_id"
        translate_value(table[:id], value)
      else
        translate_value_json(sql_json_path(col), value)
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

    def translate_value_json(col, value)
      case value
      when String, TrueClass, FalseClass
        compare(col, value.to_s, :eq)
      when Numeric, NilClass
        compare(col, value, :eq)
      when Hash
        if has_operator?(value)
          chain(:and, value.map {|op, val|
                  case op
                  when "$contains"
                    chain(:or, val.map {|val| col.matches(%Q[%"#{val}"%]) })
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
