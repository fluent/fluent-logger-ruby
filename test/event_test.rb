require File.dirname(__FILE__)+'/test_helper'

class EventTest < Test::Unit::TestCase
  it 'keys' do
    g = Fluent::Logger::TestLogger.new

    assert_nothing_raised do
      e1 = g.create_event('e1', :k1)
      e1.k1('v1')
    end

    assert_raise(NoMethodError) do
      e2 = g.create_event('e2')
      e2.k1('v1')
    end

    assert_raise(NoMethodError) do
      e3 = g.create_event('e3', :k1)
      e3.k2('v2')
    end
  end

  it 'set_value' do
    g = Fluent::Logger::TestLogger.new

    e1 = g.create_event('e1', :k1)
    e1.k1('v1').post!
    assert_equal g.queue.last, {:k1=>'v1'}

    e2 = g.create_event('e2', :k1, :k2)
    e2.k1('v1').k2('v2').post!
    assert_equal g.queue.last, {:k1=>'v1', :k2=>'v2'}

    e3 = g.create_event('e3', :k1, :k2)
    e3.k1('v1').post!
    assert_equal g.queue.last, {:k1=>'v1'}
  end

  it 'default_value' do
    g = Fluent::Logger::TestLogger.new

    e1 = g.create_event('e1', :k1)
    e1.post!
    assert_equal g.queue.last, {}

    e2 = g.create_event('e2', :k1=>'v1')
    e2.post!
    assert_equal g.queue.last, {:k1=>'v1'}

    e3 = g.create_event('e3', :k1=>'v1', :k2=>'v2')
    e3.post!
    assert_equal g.queue.last, {:k1=>'v1', :k2=>'v2'}

    e4 = g.create_event('e4', :k1=>'v1', :k2=>'v2')
    e4.k2('v3').post!
    assert_equal g.queue.last, {:k1=>'v1', :k2=>'v3'}
  end

  it 'modify' do
    g = Fluent::Logger::TestLogger.new

    e1 = g.create_event('e1', :k1)
    e1.k1!('v1')
    e1.post!
    assert_equal g.queue.last, {:k1=>'v1'}

    e1.k1!('v2')
    e1.post!
    assert_equal g.queue.last, {:k1=>'v2'}

    e2 = g.create_event('e2', :k1=>'v1')
    e2.k1!('v2')
    e2.post!
    assert_equal g.queue.last, {:k1=>'v2'}
  end

  it 'no_modify' do
    g = Fluent::Logger::TestLogger.new

    e1 = g.create_event('e1', :k1)
    e1.k1('v1')
    e1.post!
    assert_equal g.queue.last, {}

    e1.k1('v2')
    e1.post!
    assert_equal g.queue.last, {}

    e2 = g.create_event('e1', :k1=>'v1')
    e2.k1('v2')
    e2.post!
    assert_equal g.queue.last, {:k1=>'v1'}
  end

  it 'with_map' do
    g = Fluent::Logger::TestLogger.new

    e1 = g.create_event('e1')
    e1.with(:k1=>'v1').post!
    assert_equal g.queue.last, {:k1=>'v1'}

    e2 = g.create_event('e2', :k1=>'v1')
    e2.with(:k1=>'v2').post!
    assert_equal g.queue.last, {:k1=>'v2'}

    e3 = g.create_event('e3', :k1=>'v1')
    e3.with(:k1=>'v2', :k2=>'v3').post!
    assert_equal g.queue.last, {:k1=>'v2', :k2=>'v3'}
  end

  it 'with_map_modify' do
    g = Fluent::Logger::TestLogger.new

    e1 = g.create_event('e2', :k1)
    e1.with!(:k1=>'v1')
    e1.post!
    assert_equal g.queue.last, {:k1=>'v1'}

    e1.with!(:k1=>'v2')
    e1.post!
    assert_equal g.queue.last, {:k1=>'v2'}

    e2 = g.create_event('e2')
    e2.with!(:k1=>'v1', :k2=>'v2')
    e2.post!
    assert_equal g.queue.last, {:k1=>'v1', :k2=>'v2'}

    e2.with!(:k1=>'v3')
    e2.post!
    assert_equal g.queue.last, {:k1=>'v3', :k2=>'v2'}
  end

  it 'with_event_keys' do
    g = Fluent::Logger::TestLogger.new

    assert_nothing_raised do
      e1 = g.create_event('e1', :k1)
      e2 = g.create_event('e2', :k2)
      e3 = e1.with(e2)
      e3.k1('v1').k2('v2')
    end

    assert_nothing_raised do
      e1 = g.create_event('e1', :k1)
      e2 = g.create_event('e2', :k1, :k2)
      e3 = e1.with(e2)
      e3.k1('v1').k2('v2')
    end

    assert_nothing_raised do
      e1 = g.create_event('e1', :k1)
      e2 = g.create_event('e2', :k2)
      e1.with!(e2)
      e1.k1('v1').k2('v2')
    end

    assert_raise(NoMethodError) do
      e1 = g.create_event('e1', :k1)
      e2 = g.create_event('e2', :k2)
      e3 = e1.with(e2)
      e1.k2('v1')
    end

    assert_raise(NoMethodError) do
      e1 = g.create_event('e1', :k1)
      e2 = g.create_event('e2', :k2)
      e1.with!(e2)
      e2.k1('v1')
    end
  end

  it 'tag' do
    g = Fluent::Logger::TestLogger.new

    e1 = g.create_event('e1')
    e1.post!
    assert_equal g.queue.last.tag, 'e1'

    e1.post!('e2')
    assert_equal g.queue.last.tag, 'e2'
  end
end

