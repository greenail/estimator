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
		#puts "LOGIN: #{@user_name}"
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
	if (params['all'] != nil)
               @estimates = EstimateModel.all
        end
	if (params['delete'])
                @estimate = EstimateModel.get(params['delete'])
                raise NotFound unless @estimate
                if (@estimate.fratricide)
                        redirect ("/")
                else
                        raise InternalServerError
                end
        end
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
class Ctest < Merb::Controller
  def _template_location(action, type = nil, controller = controller_name)
    controller == "layout" ? "layout.#{action}.#{type}" : "#{action}.#{type}"
  end
  def index
	@estimate_name = "jesse-Patni-insurance"
	@configs = Iconf.all(:name.like => "#{@estimate_name}%")
	render :chart_test
  end
end
class Exceptions
  def _template_location(action, type = nil, controller = controller_name)
    controller == "layout" ? "layout.#{action}.#{type}" : "#{action}.#{type}"
  end

  #def not_found
#	#return standard_error 
#	render
#  end
end
class Estimate  < Merb::Controller

  def _template_location(action, type = nil, controller = controller_name)
    controller == "layout" ? "layout.#{action}.#{type}" : "#{action}.#{type}"
  end

  def index
	@user_name = cookies[:user_name]
	if (params['delete'])
		@estimate = EstimateModel.get(params['delete'])
		raise NotFound unless @estimate
		if (@estimate.fratricide)
			redirect ("/")
		else
			raise InternalServerError
		end
	end
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
	@dm.save
	cookies[:estimate_id] = @estimate.id
	redirect ("/configs/show_estimate/#{@estimate.id}")
    #render
  end
end

class Configs < Merb::Controller

  def _template_location(action, type = nil, controller = controller_name)
    controller == "layout" ? "layout.#{action}.#{type}" : "#{action}.#{type}"
  end
  def show_estimate
	id = params['id']
	id = params['eid'] if params['eid']
	@estimate = EstimateModel.get(id)
	if (params['months'])
		@estimate = EstimateModel.get(params['eid'])
		@estimate.update(:months => params['months'],:month_growth_percentage => params['months_growth_percentage'],:month_start_percentage => params['month_start_percentage'])
                @estimate.months = params['months']
		@estimate.month_growth_percentage = params['month_growth_percentage']
		@estimate.month_start_percentage = params['month_start_percentage']
		tmp_name = @estimate.name
		@estimate.name = "ldsjfls"
		@estimate.save
		@estimate.name = tmp_name
		@estimate.save
        end
	if (@estimate == nil)
		@estimate = EstimateModel.get(cookies[:estimate_id])
	else
		cookies[:estimate_id] = @estimate.id
	end
	raise NotFound  unless @estimate != nil
        @estimate.configs = {}
        cookies[:estimate_name] = @estimate.name
        cookies[:estimate_id] = @estimate.id
        @months = @estimate.months
	@month_growth_percentage = @estimate.month_growth_percentage
	@month_start_percentage = @estimate.month_start_percentage
	@configs = Iconf.all(:name.like => "#{@estimate.name}%")
	if (@configs.count == 0)
		#redirect("/configs")
	end
	@e_total_onetime = 0.0
	@e_total_monthly = 0.0
	@e_month_1 = 0.0
	@e_month_n = 0.0
	#puts "#{@months} #{@month_growth_percentage} #{@month_start_percentage}"
	dmname = "#{@estimate.name}-DailyModel"
	@dm = JS::DailyModel.first(:name => dmname)
	puts "DM Name: #{dmname}"
	# ugly hack
	if (@dm == nil)
		@dm = JS::DailyModel.first(:name => dmname)
	end
	raise NotFound  unless @dm != nil
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
	redirect ("/configs/show_estimate/#{cookies[:estimate_id]}")
  end
  def update_config
        name = params['name']
	ic = Iconf.first(:name => name)
        ic.update(:name => name,:type => params['type'],:min_q => params['min_q'],:max_q => params['max_q'],:days => params['days'],:weekend_usage => params['weekend_usage'])
        redirect ("/configs/show_estimate/#{params['eid']}")
  end
  def delete_config
	ic = Iconf.first(:name => params['config_key'])
	ic.destroy
	redirect ("/configs/show_estimate")
  end
  def edit_config
	@estimate_name = cookies[:estimate_name]
	@config_name = params['config_key']
	@c = Iconf.first(:name =>@config_name)
	@config = @c.to_hash
	render :edit_config
  end
  def edit_daily
	@estimate = EstimateModel.get(cookies[:estimate_id])
	@usage = 1
	#puts "#{@estimate.name}-DailyModel"
	@dm = JS::DailyModel.first(:name => "#{@estimate.name}-DailyModel")
	render :edit_daily_model
  end
  def update_daily_model
	@estimate = EstimateModel.get(cookies[:estimate_id])
	@dm = JS::DailyModel.first(:name => "#{@estimate.name}-DailyModel")
	for name in params.keys.sort
		if (name =~ /^usage/)
			nada, hour = name.split("-")
			print " #{hour.to_i}-#{params[name].to_f} "
			@dm.put_hour(hour.to_i,params[name].to_f)
		end
	end
	tmp_name = @dm.name
	@dm.name = "flrorme"
	@dm.save
	@dm.name = tmp_name
	@dm.save
	redirect ("/configs/show_estimate/#{@estimate.id}")
	
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
	attr_accessor :configs
	def fratricide  
		es = Iconf.all(:name.like => "#{@name}%")
		for e in es
			puts "deleting instance configs #{e.name}"
			e.destroy!
		end
		es = JS::DailyModel.all(:name.like => "#{@name}%")
		for e in es
                        puts "deleting daily model #{e.name}"
                        e.destroy!
                end
		puts "good bye cruel world!"
		self.destroy!
	end
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
	attr_accessor :week_hours,:rio_total,:rio_hourly,:rio_onetime,:od_total,:od_hourly
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
