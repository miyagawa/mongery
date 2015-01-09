describe "#mapped_properties" do
  let(:builder) {
    Mongery::Builder.new(:test).tap do |builder|
      builder.mapped_properties = {
        _user_id:    :user_id,
        _created_at: :created_at,
        _updated_at: :updated_at,
      }
    end
  }

  let(:args) {
    { _id: 1, _user_id: 2, _created_at: Time.now, foo: "bar" }
  }

  it 'generates INSERT' do
    expect(builder.insert(args).to_sql).to match /VALUES \(1, '{.*?}', 2, '\d{4}-\d{2}-\d{2} .*'\)$/
  end

  it 'generates UPDATE' do
    expect(builder.find(_id: 1).update(args).to_sql).to match /SET "data" = .*, "user_id" = 2, "created_at" = '\d{4}-.*' WHERE/;
  end

  it 'searches WHERE with symbol' do
    expect(builder.find(:_user_id => '2').to_sql).to match /WHERE "test"\."user_id" = '2'/;
  end

  it 'searches WHERE with string' do
    expect(builder.find("_user_id" => '2').to_sql).to match /WHERE "test"\."user_id" = '2'/;
  end

  it 'searches WHERE with operators' do
    expect(builder.find("_created_at" => {'$in' => ['2014-01-01', '2015-01-01']}, "foo" => "bar").to_sql)
      .to match /WHERE "test"\."created_at" IN \('2014-01-01', '2015-01-01'\) AND data#>>'{foo}' = 'bar'/;
  end
end
