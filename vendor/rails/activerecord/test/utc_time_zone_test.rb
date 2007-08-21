require 'abstract_unit'
require 'fixtures/topic'
require 'fixtures/developer'

class UtcTimeZoneTest < Test::Unit::TestCase

  def setup
    super
    Topic.default_timezone = :utc

    # force timezone to be other than UTC just in case localtime is utc
    @orig_tz = ENV['TZ']
    ENV['TZ'] = 'MST'
  end

  def teardown
    ENV['TZ'] = @orig_tz
    Topic.default_timezone = :local
    super
  end

    # Oracle, SQLServer, and Sybase do not have a TIME datatype.
  unless current_adapter?(:SQLServerAdapter, :OracleAdapter, :SybaseAdapter)
    def test_read_time
      attributes = { "bonus_time" => "5:42:00AM" }
      topic = Topic.find(1)
      topic.attributes = attributes
      assert_equal Time.utc(2000, 1, 1, 5, 42, 0), topic.bonus_time
    end

    def test_read_time_and_new
      attributes = { "bonus_time(1i)"=>"2000",
                     "bonus_time(2i)"=>"1",
                     "bonus_time(3i)"=>"1",
                     "bonus_time(4i)"=>"10",
                     "bonus_time(5i)"=>"35",
                     "bonus_time(6i)"=>"50" }
      topic = Topic.new(attributes)
      assert_equal Time.utc(2000, 1, 1, 10, 35, 50), topic.bonus_time
    end

    def test_write_time_local
      topic = Topic.find(1)
      topic.bonus_time = t = Time.local(2000, 1, 1, 10, 35, 50)
      topic.save!
      topic.reload
      assert_equal t, topic.bonus_time.localtime
    end
    
  end

  def test_write_datetime_local
    topic = Topic.find(1)
    topic.written_on = t = Time.local(2007, 5, 3, 17, 9, 35)
    topic.save!
    topic.reload
    assert_equal t, topic.written_on.localtime
  end

  def test_updated_at_with_utc
    dev = Developer.find(1)
    dev.save!
    now = Time.now
    dev.reload
    assert_in_delta now.utc.to_i, dev.updated_at.to_i, 10
  end
  
  def test_created_at_with_utc
    tim = Developer.new(:name => 'tim')
    tim.save!
    now = Time.now
    tim.reload
    assert_in_delta now.utc.to_i, tim.created_at.to_i, 10
  end
  

end
