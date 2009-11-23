require 'lib/priz.rb'
require '/root/creds.rb'
require 'right_aws'

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
	@index_name = cookies[:index_name]
	#@dy = DyModel.new
	#key,skey = getCreds()
        #@sdb = RightAws::SdbInterface.new(key,skey)
	@estimates = EstimateModel.all
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
        index_name = "#{user_name}-#{customer_name}-#{quote_name}"
	months = params['months']
	cookies[:user_name] = user_name
	cookies[:index_name] = index_name
	@estimate = EstimateModel.create(:name => index_name,:months => months)
	redirect ("/configs/show_estimate")
    #render
  end
end

class Configs < Merb::Controller

  def _template_location(action, type = nil, controller = controller_name)
    controller == "layout" ? "layout.#{action}.#{type}" : "#{action}.#{type}"
  end
  def show_estimate
        @dy = DyModel.new
        @index_name = cookies[:index_name]
        if (params['estimate'])
                @index_name = params['estimate']
                cookies[:index_name] = params['estimate']
        end
        @month_start_percentage = 0.5
        @month_start_percentage = params['month_start_percentage'] if params['month_start_percentage']
        @month_growth_percentage = 0.16
        @month_growth_percentage = params['month_growth_percentage'] if params['month_growth_percentage']
	@estimate = EstimateModel.first(:name => @index_name)
	if (params['months'])
                @months = params['months']
                @estimate.months = @months
                @estimate.save
        else
                @months = @estimate.months
        end
	@configs = Iconf.all(:name.like => "#{@index_name}%")
        render
  end
  def index
 	@dy = DyModel.new
    	render :new_config
  end
  def add_config
	@index_name = cookies[:index_name]
	name = params['name']
	ic = Iconf.create(:name => "#{@index_name}-#{name}",:type => params['type'],:min_q => params['min_q'],:max_q => params['max_q'],:days => params['days'],:weekend_usage => params['weekend_usage'])
	redirect ("/configs/show_estimate")
  end
  def update_config
	@index_name = cookies[:index_name]
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
	@dy = DyModel.new
	@index_name = cookies[:index_name]
	key,skey = getCreds()
        #@sdb = RightAws::SdbInterface.new(key,skey)
	@config_name = params['config_key']
	#@name,@config = @dy.get_instance_config(@sdb,@config_name)
	@c = Iconf.first(:name =>@config_name)
	@config = @c.to_hash
	render :edit_config
  end
  def edit_daily
	@dy = DyModel.new
	@usage = params['usage']
        @daily_model,min,max = @dy.get_daily_usage(@usage)
	render :edit_daily_model
  end
  def update_daily_model
	@dy = DyModel.new
	@daily_model = {}
	for name in params.keys
		if (name =~ /^usage/)
			nada, hour = name.split("-")
			print " #{hour}-#{params[name]} "
			@daily_model[hour] = params[name]	
		end
	end
	#@dy.put_daily_model(@daily_model)
        #@daily_model,min,max = @dy.get_daily_usage	
	render :edit_daily_model
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
