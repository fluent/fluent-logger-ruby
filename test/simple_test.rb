require File.dirname(__FILE__)+'/test_helper'

class SimpleTest < Test::Unit::TestCase
  it 'singleton' do
    Fluent.open(:console, STDOUT)

    AccessEvent = Fluent.create_event(:agent, :action=>'access')
    LoginEvent = Fluent.create_event(:user, :action=>'login')

    #=> action="access" agent="foo"
    AccessEvent.agent('foo').post!

    #=> action="login" user="bar"
    LoginEvent.user('bar').post!
  end

  it 'local' do
    E2_LOG = Fluent.new(:console, STDOUT)

    E2_AccessEvent = E2_LOG.create_event(:agent, :action=>'access')
    E2_LoginEvent = E2_LOG.create_event(:user, :action=>'login')

    #=> action="access" agent="foo"
    E2_AccessEvent.agent('foo').post!

    #=> action="login" user="bar"
    E2_LoginEvent.user('bar').post!
  end

  it 'combine' do
    E3_LOG = Fluent.new(:console, STDOUT)

    E3_User = E3_LOG.create_event(:name, :age)
    E3_LoginEvent = E3_LOG.create_event(:action=>'login')
    E3_BuyEvent = E3_LOG.create_event(:item, :action=>'login')

    e_user = E3_User.name('me').age(24)

    #=> action="login" name="me" age=24
    E3_LoginEvent.with(e_user).post!

    #=> action="login" name="me" age=24 item="item01"
    E3_BuyEvent.with(e_user).item("item01").post!
  end

  it 'update' do
    E4_LOG = Fluent.new(:console, STDOUT)

    E4_User = E4_LOG.create_event(:name, :age)
    E4_AgeChangeEvent = E4_LOG.create_event(:changed_age, :action=>'age_change')
    E4_BuyEvent = E4_LOG.create_event(:item, :action=>'buy')

    e_user = E4_User.name('me').age(24)

    #=> action="age_change" name="me" age=24 changed_age=25
    E4_AgeChangeEvent.with(e_user).changed_age(25).post!
    e_user.age!(25)

    #=> action="buy" name="me" age=25 item="item01"
    E4_BuyEvent.with(e_user).item("item01").post!
  end

  it 'combine_update' do
    E5_LOG = Fluent.new(:console, STDOUT)

    E5_User = E5_LOG.create_event(:name, :age)
    E5_Browser = E5_LOG.create_event(:host, :agent)
    E5_LoginEvent = E5_LOG.create_event(:action=>'login')

    e_user = E5_User.name('me').age(24)
    e_browser = E5_Browser.host('remoteip').agent('firefox')
    e_user.with!(e_browser)

    #=> action="login" name="me" age=24 host="remoteip" agent="firefox"
    E5_LoginEvent.with(e_user).post!
  end
end

