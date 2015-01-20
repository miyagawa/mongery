require 'spec_helper'

describe Mongery::Builder do
  queries = [
    [ { }, { },
      /^SELECT "test"\."data" FROM "test"$/ ],
    [ { _id: "foo" }, { },
      /WHERE "test"\."id" = 'foo'$/ ],
    [ { _id: { "$in" => ["foo", "bar"] } }, { },
      /WHERE "test"\."id" IN \('foo', 'bar'\)$/ ],
    [ { _id: "foo" }, { limit: 1 },
      /WHERE "test"\."id" = 'foo' LIMIT 1$/ ],
    [ { _id: "foo" }, { limit: 1, skip: 10 },
      /WHERE "test"\."id" = 'foo' LIMIT 1 OFFSET 10$/ ],
    [ { _id: "foo" }, { skip: 10, sort: { _id: 1 } },
      /WHERE "test"\."id" = 'foo'  ORDER BY "test"\."id" ASC OFFSET 10$/ ],
    [ { _id: "foo" }, { sort: { name: -1, email: 1 } },
      /WHERE "test"\."id" = 'foo'  ORDER BY data#>>'{name}' DESC, data#>>'{email}' ASC$/ ],
    [ { "_id" => "foo" }, { },
      /WHERE "test"\."id" = 'foo'$/ ],
    [ { name: "foo" }, { },
      /WHERE data#>>'{name}' = 'foo'$/ ],
    [ { name: "" }, { },
      /WHERE data#>>'{name}' = ''$/ ],
    [ { name: nil }, { },
      /WHERE \(data#>>'{name}'\) IS NULL$/ ],
    [ { name: "foo", other: "bar" }, { },
      /WHERE data#>>'{name}' = 'foo' AND data#>>'{other}' = 'bar'/ ],
    [ { "x'y" => "foo" }, { },
      /WHERE data#>>'{x''y}' = 'foo'/ ],
    [ { weight: 66 }, { },
      /WHERE \(data#>>'{weight}'\)::numeric = 66$/ ],
    [ { weight: { "$gt" => 66 } }, { },
      /WHERE \(data#>>'{weight}'\)::numeric > 66$/ ],
    [ { weight: { "$gt" => 66.0 } }, { },
      /WHERE \(data#>>'{weight}'\)::numeric > 66\.0$/ ],
    [ { weight: { "$lte" => 66 } }, { },
      /WHERE \(data#>>'{weight}'\)::numeric <= 66$/ ],
    [ { age: { '$eq' => 10 }}, { },
      /WHERE \(data#>>'{age}'\)::numeric = 10/ ],
    [ { age: { '$ne' => 10 }}, { },
      /WHERE \(data#>>'{age}'\)::numeric != 10/ ],
    [ { bool: true }, { },
      /WHERE data#>>'{bool}' = 'true'$/ ],
    [ { 'email.address' => 'john@example.com' }, { },
      /WHERE data#>>'{email,address}' = 'john@example.com'$/ ],
    [ { "x'y.z" => 'john' }, { },
      /WHERE data#>>'{x''y,z}' = 'john'$/ ],
    [ { type: "food", "$or" => [{name: "miso"}, {name: "tofu"}]}, { },
      /WHERE data#>>'{type}' = 'food' AND \(data#>>'{name}' = 'miso' OR data#>>'{name}' = 'tofu'\)$/ ],
    [ { "$or" => [{ _id: "foo" }, { _id: "bar" }] }, { },
      /WHERE \("test"\."id" = 'foo' OR "test"\."id" = 'bar'\)$/ ],
    [ { "$or" => [{ name: "John" }, { weight: 120 }] }, { },
      /WHERE \(data#>>'{name}' = 'John' OR \(data#>>'{weight}'\)::numeric = 120\)$/ ],
    [ { "$and" => [{ _id: "foo" }, { name: "bar" }] }, { },
      /WHERE "test"\."id" = 'foo' AND data#>>'{name}' = 'bar'$/ ],
    [ { "$and" => [{ name: "John" }, { weight: 120 }] }, { },
      /WHERE data#>>'{name}' = 'John' AND \(data#>>'{weight}'\)::numeric = 120$/ ],
    [ { "$and" => [{ "$or" => [{name: "John"}, {email: "john"}] }, {_id: "Bob"}] }, { },
      /WHERE \(data#>>'{name}' = 'John' OR data#>>'{email}' = 'john'\) AND "test"\."id" = 'Bob'$/ ],
    [ { bar: {"$in" => [ "foo" ]} }, { },
      /WHERE data#>>'{bar}' IN \('foo'\)$/ ],
    [ { tag: {"$in" => [ 1, 2 ]} }, { },
      /WHERE \(data#>>'{tag}'\)::numeric IN \(1, 2\)$/ ],
    [ { bar: {"$in" => [ "foo", "bar" ]} }, { },
      /WHERE data#>>'{bar}' IN \('foo', 'bar'\)$/ ],
    [ { bar: {"$in" => [ "foo", 1.2 ]} }, { },
      /WHERE data#>>'{bar}' IN \('foo', '1\.2'\)$/ ],
    [ { bar: { foo: "bar", baz: [1,2,3]} }, { },
      /WHERE data#>>'{bar}' = '{"foo":"bar","baz":\[1,2,3\]}'$/ ],
    [ { "foo.bar" => true }, { },
      /WHERE data#>>'{foo,bar}' = 'true'$/ ],
    [ { bar: {"$as" => 1} }, { },
      /WHERE \(data#>>'{bar}'\)::numeric = 1$/ ],
    [ { bar: {"$land" => 'foo'} }, { },
      /WHERE data#>>'{bar}' && 'foo'$/ ],
  ]

  bad_queries = [
    { "$bar" => "foo" },
    { "_id" => { "$bar" => 1 } },
    { "foo" => { "$bar" => 1 } },
    { "foo" => { "$lt" => 1, "gt" => 2 } },
  ]

  builder = Mongery::Builder.new(:test)
  builder.custom_operators  = {
    "$as" => :eq,
    "$land" => ->(col, val) {
      Arel::Nodes::InfixOperation.new("&&", col, val)
    }
  }

  queries.each do |query, condition, sql|
    context "with query #{query}" do
      subject do
        builder.find(query).tap { |q|
          condition.each do |method, value|
            q.send(method, value)
          end
        }.to_sql
      end
      it { should match sql }
    end
  end

  bad_queries.each do |query|
    context "with query #{query}" do
      it "should throw UnsupportedQuery exception" do
        expect { builder.find(query).to_sql }
          .to raise_error(Mongery::UnsupportedQuery)
      end
    end
  end
end

