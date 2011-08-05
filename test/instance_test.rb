require File.dirname(__FILE__)+'/test_helper'

class InstanceTest < Test::Unit::TestCase
  it 'default' do
    g1 = Fluent.open(:test)
    assert_equal g1.object_id, Fluent::Logger.default.object_id

    assert_equal false, g1.closed?

    g2 = Fluent.open(:test)
    assert_equal g2.object_id, Fluent::Logger.default.object_id

    assert_equal true, g1.closed?

    g3 = Fluent.new(:test)
    assert_equal g2.object_id, Fluent::Logger.default.object_id

    assert_equal false, g2.closed?
    Fluent.close
    assert_equal true, g2.closed?
  end

  it 'post' do
    g1 = Fluent.new(:test)

    g1.post :k1=>'v1'
    assert_equal g1.queue.last, {:k1=>'v1'}

    g2 = Fluent.open(:test)

    Fluent.post :k2=>'v2'
    assert_equal g2.queue.last, {:k2=>'v2'}
  end
end
