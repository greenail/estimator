#require 'lib/priz.rb'
require 'lib/dailymodel.rb'
require '/root/creds.rb'
require 'right_aws'
require 'google_chart'

class Priz < Merb::Controller

  def _template_location(action, type = nil, controller = controller_name)
    controller == "layout" ? "layout.#{action}.#{type}" : "#{action}.#{type}"
  end

  def index
	@user_name = cookies[:user_name]
	if (params['user_name'] != nil)
		@user_name = params['user_name'] 
		puts "LOGIN: #{@user_name}"
		cookies[:user_name] = @user_name
	end
	if (@user_name == nil)
		redirect("/priz/login")
	end	
	@estimate_name = cookies[:estimate_name]
	#@dy = DyModel.new
	#key,skey = getCreds()
        #@sdb = RightAws::SdbInterface.new(key,skey)
	@estimates = EstimateModel.all(:name.like => "#{@user_name}%")
    	render
  end
  def login
	render
  end
  def logout
	#cookies.delete[:user_name]
	cookies.delete(:user_name)
	redirect("/priz/login")
  end

  
end
class Estimate  < Merb::Controller

  def _template_location(action, type = nil, controller = controller_name)
    controller == "layout" ? "layout.#{action}.#{type}" : "#{action}.#{type}"
  end

  def index
	@user_name = cookies[:user_name]
    render :estimate
  end
  def create
	user_name = params['user_name']
        customer_name = params['customer_name']
        quote_name =  params['quote_name']
        estimate_name = "#{user_name}-#{customer_name}-#{quote_name}"
	months = params['months']
	month_start_percentage = params['month_start_percentage']
	month_growth_percentage = params['month_growth_percentage']
	cookies[:user_name] = user_name
	cookies[:estimate_name] = estimate_name
	@estimate = EstimateModel.create(:name => estimate_name,:months => months,:month_growth_percentage => month_growth_percentage,:month_start_percentage => month_start_percentage)
	@dm = JS::DailyModel.new
	@dm.name = "#{estimate_name}-DailyModel"
	# warm sdb and load default model 
	@dm.get_daily_model('m1small',1,1,1)
	redirect ("/configs/show_estimate")
    #render
  end
end

class Configs < Merb::Controller

  def _template_location(action, type = nil, controller = controller_name)
    controller == "layout" ? "layout.#{action}.#{type}" : "#{action}.#{type}"
  end
  def show_estimate
        @estimate_name = cookies[:estimate_name]
        if (params['estimate'])
                @estimate_name = params['estimate']
                cookies[:estimate_name] = params['estimate']
        end
	@estimate = EstimateModel.first(:name => @estimate_name)
	if (params['months'])
		@estimate.update(:months => params['months'],:month_growth_percentage => params['months_growth_percentage'],:month_start_percentage => params['month_start_percentage'])
                @months = params['months']
		@month_growth_percentage = params['month_growth_percentage']
		@month_start_percentage = params['month_start_percentage']
        else
                @months = @estimate.months
		@month_growth_percentage = @estimate.month_growth_percentage
		@month_start_percentage = @estimate.month_start_percentage
        end
	@configs = Iconf.all(:name.like => "#{@estimate_name}%")
	@e_total_onetime = 0.0
	@e_total_monthly = 0.0
	@e_month_1 = 0.0
	@e_month_n = 0.0
        render
  end
  def index
 	#@dy = DyModel.new
    	render :new_config
  end
  def add_config
	@estimate_name = cookies[:estimate_name]
	name = params['name']
	ic = Iconf.create(:name => "#{@estimate_name}-#{name}",:type => params['type'],:min_q => params['min_q'],:max_q => params['max_q'],:days => params['days'],:weekend_usage => params['weekend_usage'])
	redirect ("/configs/show_estimate")
  end
  def update_config
	@estimate_name = cookies[:estimate_name]
        name = params['name']
	ic = Iconf.first(:name => name)
        ic.update(:name => name,:type => params['type'],:min_q => params['min_q'],:max_q => params['max_q'],:days => params['days'],:weekend_usage => params['weekend_usage'])
	#puts "DAYS: #{params['days']} Result: #{result}"
        redirect ("/configs/show_estimate")
  end
  def delete_config
	ic = Iconf.first(:name => params['config_key'])
	ic.destroy
	redirect ("/configs/show_estimate")
  end
  def edit_config
	#@dy = DyModel.new
	@estimate_name = cookies[:estimate_name]
	@config_name = params['config_key']
	@c = Iconf.first(:name =>@config_name)
	@config = @c.to_hash
	render :edit_config
  end
  def edit_daily
	@estimate_name = cookies[:estimate_name]
	@usage = 1
	puts "#{@estimate_name}-DailyModel"
	@dm = JS::DailyModel.first(:name => "#{@estimate_name}-DailyModel")
	render :edit_daily_model
  end
  def update_daily_model
	@estimate_name = cookies[:estimate_name]
	@dm = JS::DailyModel.first(:name => "#{@estimate_name}-DailyModel")
	for name in params.keys.sort
		if (name =~ /^usage/)
			nada, hour = name.split("-")
			print " #{hour}-#{params[name]} "
			@dm.put_hour(hour,params[name])
		end
	end
	@dm.save_yaml
	@dm.save
	redirect ("/configs/show_estimate")
	
  end

end
class DailyModel < Merb::Controller

  def _template_location(action, type = nil, controller = controller_name)
    controller == "layout" ? "layout.#{action}.#{type}" : "#{action}.#{type}"
  end
  def index
         @dy = DyModel.new
	@usage = params['usage']
	@daily_model,min,max = @dy.get_daily_usage(@usage)
    render :view_daily_model
  end
end
class EstimateModel
	include DataMapper::Resource
	property :id,Serial
	property :name, String, :nullable => false
	property :months, Integer, :nullable => false
	property :month_growth_percentage, String, :nullable => false
	property :month_start_percentage, String, :nullable => false
	# configs is a hash of config names
	property :configs, Object
end
class Iconf
	# this is the instance configuration
	include DataMapper::Resource
        property :id,Serial
	property :name, String, :nullable => false	
	property :type, String, :nullable => false
        property :min_q, String, :nullable => false
        property :max_q, String, :nullable => false
        property :days, String, :nullable => false
        property :weekend_usage, String, :nullable => false
	#property :config, Object
	def to_hash
		t = {}
		t[:type] = @type
		t[:name] = @name
		t[:min_q] = @min_q
		t[:max_q] = @max_q
		t[:days_of_week] = @days
		t[:weekend_usage] = @weekend_usage
		return t
	end
end
#class DailyModel
	#include DataMapper::Resource
	#property :id,Serial
	#property :name, String, :nullable => false
	#property :yaml, String, :nullable => false
	#def config
		#config = {}
		#config = YAML::load(self.yaml)
	#end
	#def get_daily_usage(usage)
		#model = self.config
		#for hour in model.keys
               	 	#hourly_usage = model[hour]
                	#model[hour] = hourly_usage.to_f * usage.to_f
        	#end
        	#return model
	#end
#end
