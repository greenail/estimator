require 'lib/dailymodel.rb'
require 'test/unit'
require 'dm-core'
require '/root/creds.rb'

class TestMath < Test::Unit::TestCase
def setup
	key,skey = getCreds
	mysetup = {:adapter => 'simpledb',:access_key => key,:secret_key => skey,:domain => 'sdb_test'}
	DataMapper.setup(:default,mysetup)
end
def teardown
	#dm = JS::DailyModel.first(:name => "test_get_daily_model")
        #if (dm != nil)
        #        dm.destroy!
        #end

end

def test_get_default_daily_model
	dm = JS::DailyModel.first(:name => "test_get_daily_model")
        if (dm != nil)
                dm.destroy!
        end
	dm = JS::DailyModel.new
	dm.name = "test_get_daily_model"
	dm.get_daily_model('m1small',1,1,1)
	assert_not_nil(dm.day, "testing day is populated after get_daily_model")
	assert_equal( 0.1, dm.day[0].usage)
	assert_equal( 1, dm.day[0].instances, "Testing Instance count for hour 1 for default model")
	assert_equal( 0.8, dm.day[9].usage)
	dm.get_daily_model('m1small',1,0,5)
	assert_equal( 5, dm.day[10].instances)
	dm.get_daily_model('m1small',0.5,1,5)
	assert_equal( 3, dm.day[10].instances)
	assert_equal(3,dm.max_instances)
end
def test_get_existing_daily_model
	dm = JS::DailyModel.first(:name => "test_get_daily_model")
	assert_not_nil(dm,"testing if get pulled a valid daily model")
	# setup first run
        dm.get_daily_model('m1small',1,1,1)
        assert_equal( 0.1, dm.day[0].usage)
        assert_equal( 1, dm.day[0].instances, "Testing Instance count for hour 1 for SDB model")
        assert_equal( 0.8, dm.day[9].usage)
	# change params should result in changed output
        dm.model_max = 5
        dm.get_daily_model('m1small',1,0,5)
        assert_equal( 5, dm.day[10].instances)
end
def test_calc_annual_prices
	dm = JS::DailyModel.first(:name => "test_get_daily_model")
	dm.get_daily_model("m1small",1,1,1)
	dm.weekend_usage = 0.2
	dm.weekend_days = 2
	price = dm.calc_annual_unoptimiezed_price
	assert_equal( 742.56,price,"Testing Weekly Price = $742.56")
	rio_price,first_month_price = dm.calc_annual_price_with_ri(1)
	assert_equal (248.839999832,first_month_price,"testing first months price including RI")
	assert_equal( 489.08,rio_price.to_f,"Testing RIO Annual Price = $489.08")
	rio_price,first_month_price = dm.calc_annual_price_with_ri(3)
	assert_equal ( 681, dm.ri_one_time, "Testing one time payment calculation should be 681")
end
def test_optimal_ris
	dm = JS::DailyModel.first(:name => "test_get_daily_model")
	dm.weekend_usage = 0.2
        dm.weekend_days = 2
	dm.get_daily_model("m1small",1,1,1)
	optimal_ris = dm.calc_optimal_ris
	assert_equal(1,optimal_ris, "testing optimal RI calculation should =1 for min,max = 1")
	dm.get_daily_model("m1small",1,1,2)
	optimal_ris = dm.calc_optimal_ris
	assert_equal(2,optimal_ris, "testing optimal RI calculation should =1 for min = 1,max = 2")
	dm.get_daily_model("m1small",1,0,2)
	optimal_ris = dm.calc_optimal_ris
        assert_equal(1,optimal_ris, "testing optimal RI calculation should =1 for min = 0,max = 2")
end
def test_destroy_dm_object
	dm = JS::DailyModel.first(:name => "test_get_daily_model")
	assert_not_nil(dm,"Testing if get pulls an object")
	result = dm.destroy!
	assert(result,"Testing DailyModel destruction return val")
	sleep 2
	assert_nil(dm.day,"Ensuring DM object was destryed")
end

end