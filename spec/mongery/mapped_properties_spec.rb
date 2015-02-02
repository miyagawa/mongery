require 'active_support/core_ext/hash/indifferent_access'

describe "#mapped_properties" do
  let(:builder) {
    Mongery::Builder.new(:test).tap do |builder|
      builder.mapped_properties = [:user_id, :created_at, :updated_at]
      builder.custom_operators  = {
        "$as" => :eq,
        "$land" => ->(col, val) {
          Arel::Nodes::InfixOperation.new("&&", col, val)
        }
      }
    end
  }

  let(:args) {
    { '_id' => 1, 'user_id' => 2, 'created_at' => Time.now, 'foo' => "bar" }.with_indifferent_access
  }

  it 'generates INSERT' do
    expect(builder.insert(args).to_sql).to match /VALUES \(1, '{.*?}', 2, '\d{4}-\d{2}-\d{2} .*'\)$/
  end

  it 'generates UPDATE' do
    expect(builder.find(_id: 1).update(args).to_sql).to match /SET "data" = .*, "user_id" = 2, "created_at" = '\d{4}-.*' WHERE/;
  end

  it 'searches WHERE with symbol' do
    expect(builder.find(:user_id => '2').to_sql).to match /WHERE "test"\."user_id" = '2'/;
  end

  it 'searches WHERE with string' do
    expect(builder.find("user_id" => '2').to_sql).to match /WHERE "test"\."user_id" = '2'/;
  end

  it 'searches WHERE with operators' do
    expect(builder.find("created_at" => {'$in' => ['2014-01-01', '2015-01-01']}, "foo" => "bar").to_sql)
      .to match /WHERE "test"\."created_at" IN \('2014-01-01', '2015-01-01'\) AND data#>>'{foo}' = 'bar'/;
  end

  it 'selects WHERE with custom fields' do
    expect(builder.find(user_id: '2').select(builder.table['user_id']).to_sql).to match /SELECT "test"\."user_id".*WHERE "test"."user_id" = '2'/
  end

  it 'counts WHERE' do
    expect(builder.find(user_id: '2').select(Arel.sql('*').count).to_sql).to match /SELECT COUNT\(\*\).*WHERE "test"."user_id" = '2'/
  end

  it 'does custom operators' do
    expect(builder.find(user_id: { "$as" => 2 }).to_sql)
      .to match /WHERE "test"\."user_id" = 2/;
  end

  it 'does custom operators with proc' do
    expect(builder.find(user_id: { "$land" => 'foo' }).to_sql)
      .to match /WHERE "test"\."user_id" && 'foo'/;
  end
end
