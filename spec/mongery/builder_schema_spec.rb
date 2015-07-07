require 'spec_helper'
require 'json_schema'

describe Mongery::Builder do
  queries = [
    [ { name: "foo" },
      /WHERE \(data#>>'\{name\}'\) = 'foo'$/ ],
    [ { weight: { "$gt" => 66 } },
      /WHERE \(data#>>'\{weight\}'\)::numeric > 66$/ ],
    [ { weight: { "$gt" => 66.0 } },
      /WHERE \(data#>>'\{weight\}'\)::numeric > 66\.0$/ ],
    [ { name: { "$in" => ["John", "Bob"] } },
      /WHERE \(data#>>'\{name\}'\) IN \('John', 'Bob'\)$/ ],
    [ { age: { '$ne' => 10 }},
      /WHERE \(data#>>'\{age\}'\)::numeric != 10/ ],
    [ { tag: {"$in" => [ "food", "recipe" ]} },
      /WHERE \(data#>>'\{tag\}' ILIKE '%"food"%' OR data#>>'\{tag\}' ILIKE '%"recipe"%'\)$/ ],
    [ { active: true },
      /WHERE \(data#>>'\{active\}'\) = 'true'$/ ],
    [ { height: 2.1 },
      /WHERE \(data#>>'\{height\}'\) = '2\.1'$/ ],
    [ { height: { '$in' => ['6.1', '6.2'] } },
      /WHERE \(data#>>'\{height\}'\) IN \('6\.1', '6\.2'\)$/ ],
    [ { height: nil },
      /WHERE \(data#>>'\{height\}'\) IS NULL$/ ],
    [ { name: { "$as" => "miyagawa" } },
      /WHERE \(data#>>'\{name\}'\) = 'miyagawa'$/ ],
    [ { name: { "$land" => "foo" } },
      /WHERE \(data#>>'\{name\}'\) && 'foo'$/ ],
  ]

  schema = JsonSchema.parse!(JSON.parse(<<-EOF))
  {
   "type": "object",
   "properties": {
    "name": {
     "type": ["string", "null"]
    },
    "weight":{
     "type": "number"
    },
    "age":{
     "type": ["integer", "null"]
    },
    "tag":{
     "type": "array"
    },
    "active":{
     "type": "boolean"
    }
   }
  }
  EOF

  builder = Mongery::Builder.new(:test, ActiveRecord::Base, schema)
  builder.custom_operators  = {
    "$as" => :eq,
    "$land" => ->(col, val) {
      Arel::Nodes::InfixOperation.new("&&", col, val)
    }
  }

  queries.each do |query, sql|
    context "with query #{query}" do
      subject do
        builder.find(query).to_sql
      end
      it { should match sql }
    end
  end
end
