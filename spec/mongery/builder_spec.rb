require 'spec_helper'

describe Mongery::Builder do
  tests = [
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
      /WHERE "test"\."id" = 'foo'  ORDER BY data->>'name' DESC, data->>'email' ASC$/ ],
    [ { "_id" => "foo" }, { },
      /WHERE "test"\."id" = 'foo'$/ ],
    [ { name: "foo" }, { },
      /WHERE data->>'name' = 'foo'$/ ],
    [ { name: nil }, { },
      /WHERE data->>'name' = ''$/ ],
    [ { name: "foo", other: "bar" }, { },
      /WHERE data->>'name' = 'foo' AND data->>'other' = 'bar'/ ],
    [ { "x'y" => "foo" }, { },
      /WHERE data->>'x''y' = 'foo'/ ],
    [ { weight: 66 }, { },
      /WHERE data->>'weight' = '66'$/ ],
    [ { weight: { "$gt" => 66 } }, { },
      /WHERE \(data->>'weight'\)::integer > 66$/ ],
    [ { weight: { "$gt" => 66.0 } }, { },
      /WHERE \(data->>'weight'\)::float > 66\.0$/ ],
    [ { weight: { "$lte" => 66 } }, { },
      /WHERE \(data->>'weight'\)::integer <= 66$/ ],
    [ { age: { '$eq' => 10 }}, { },
      /WHERE \(data->>'age'\)::integer = 10/ ],
    [ { age: { '$ne' => 10 }}, { },
      /WHERE \(data->>'age'\)::integer != 10/ ],
    [ { bool: true }, { },
      /WHERE data->>'bool' = 'true'$/ ],
    [ { 'email.address' => 'john@example.com' }, { },
      /WHERE data->'email'->>'address' = 'john@example.com'$/ ],
    [ { type: "food", "$or" => [{name: "miso"}, {name: "tofu"}]}, { },
      /WHERE data->>'type' = 'food' AND \(data->>'name' = 'miso' OR data->>'name' = 'tofu'\)$/ ],
    [ { "$or" => [{ _id: "foo" }, { _id: "bar" }] }, { },
      /WHERE \("test"\."id" = 'foo' OR "test"\."id" = 'bar'\)$/ ],
    [ { "$or" => [{ name: "John" }, { weight: 120 }] }, { },
      /WHERE \(data->>'name' = 'John' OR data->>'weight' = '120'\)$/ ],
    [ { "$and" => [{ _id: "foo" }, { name: "bar" }] }, { },
      /WHERE "test"\."id" = 'foo' AND data->>'name' = 'bar'$/ ],
    [ { "$and" => [{ name: "John" }, { weight: 120 }] }, { },
      /WHERE data->>'name' = 'John' AND data->>'weight' = '120'$/ ],
    [ { "$and" => [{ "$or" => [{name: "John"}, {email: "john"}] }, {_id: "Bob"}] }, { },
      /WHERE \(data->>'name' = 'John' OR data->>'email' = 'john'\) AND "test"\."id" = 'Bob'$/ ],
    [ { ids: {"$in" => [ "foo" ]} }, { },
      /WHERE data->>'ids' ILIKE '%"foo"%'$/ ],
    [ { ids: {"$in" => [ "foo", "bar" ]} }, { },
      /WHERE \(data->>'ids' ILIKE '%"foo"%' OR data->>'ids' ILIKE '%"bar"%'\)$/ ],
  ]

  builder = Mongery::Builder.new(:test)

  tests.each do |query, condition, sql|
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
end
