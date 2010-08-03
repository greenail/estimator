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
	@dm = JS::DailyModel.create(:name => "#{estimate_name}-DailyModel")
	@dm.name = "#{estimate_name}-DailyModel"
	@dm.save
	puts "DM ID: #{@dm.id}"
	puts "DM name: #{@dm.name}"
	dm_error = ""
	if (@dm.errors)
	   	@dm.errors.each do |e|
      		dm_error << e.to_s
      		dm_error << "<br>"
      	end
      render "ERROR: saving daily model: #{dm_error}. "
    end
    
	@estimate = EstimateModel.create(:name => estimate_name,:months => months,:month_growth_percentage => month_growth_percentage,:month_start_percentage => month_start_percentage,:dm => @dm.id)
	puts "Estimate Name: #{@estimate.name}"
	puts "Estimate DM: #{@estimate.dm}"
	if (@estimate.errors.size > 0)
		@estimate.errors.each do |e|
      		dm_error << e.to_s
      		dm_error << "<br>"
      	end
      render "ERROR: saving new estimate: #{dm_error}. "
    else
		cookies[:estimate_id] = @estimate.id
		redirect ("/configs/show_estimate/#{@estimate.id}")
	end
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
	raise NotFound  unless @estimate
	@configs = @estimate.iconfs
	#@configs = @estimate.get_children()
	
	if (@configs.length == 0)
		redirect("/configs")
	end
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
	#@configs = Iconf.all(:name.like => "#{@estimate.name}%")
	
	@e_total_onetime = 0.0
	@e_total_monthly = 0.0
	@e_month_1 = 0.0
	@e_month_n = 0.0
	@dm = JS::DailyModel.get(@estimate.dm)
	
	# ugly hack
	if (@dm == nil)
		sleep 1
		puts "sleeping waiting for daily model to persist"
		@dm = JS::DailyModel.get(@estimate.dm)
	end
	raise NotFound  unless @dm != nil
        render
  end
  def index
 	   	render :new_config
  end
  #def error
  	#render :error
  #end
  def add_config
  	@estimate = EstimateModel.get(cookies[:estimate_id])
  	@dm = JS::DailyModel.get(@estimate.dm)
	name = params['name']
	ic = Iconf.create(:name => name,:type => params['type'],:min_q => params['min_q'],:max_q => params['max_q'],:days => params['days'],:weekend_usage => params['weekend_usage'])
	raise NotFound unless ic
	ary = @estimate.iconfs
	ary.push(ic.id)
	puts "ARY #{ary}"
	@estimate.iconfs = ary
	ename = @estimate.name
	@estimate.name = "crap"
	@estimate.save
	@estimate.name = ename
	result = @estimate.save
	puts "Result: #{result}"
	dm_error = ""
	if (result == false|| @estimate.errors.size > 0)
		
      	@estimate.errors.each do |e|
      		dm_error << e.to_s
      	end
      render "ERROR: saving iconf: #{dm_error}.  <BR>Result was: #{result}"
    else
    	redirect("/configs/show_estimate/#{@estimate.id}")
    end
	
	
  end
  def update_config
	@estimate = EstimateModel.get(cookies[:estimate_id])
	id = params['iconf_id']
	ic = Iconf.get(id)
        ic.update(:name => params['name'],:type => params['type'],:min_q => params['min_q'],:max_q => params['max_q'],:days => params['days'],:weekend_usage => params['weekend_usage'])
        redirect ("/configs/show_estimate/#{params['eid']}")
  end
  def delete_config
	@estimate = EstimateModel.get(cookies[:estimate_id])
	ic = Iconf.get(params['id'])
	raise NotFound unless ic
	@estimate.iconfs.delete(ic.id)
	@estimate.save
	ic.destroy!
	redirect ("/configs/show_estimate")
  end
  def edit_config
	@id = params['id']
	@ic = Iconf.get(@id)
	raise NotFound unless @ic
	@config = @ic.to_hash
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
	property :name, String, :required=>true
	property :months, Integer, :required=>true
	property :month_growth_percentage, String, :required=>true
	property :month_start_percentage, String, :required=>true
	property :dm, String, :required=>true
	property :iconfs, SdbArray, :lazy => false
	# configs is a hash of config names
	property :configs, Object
	attr_accessor :configs
	
	def fratricide  
		#es = Iconf.all(:name.like => "#{@name}%")
		es = self.get_children
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
	property :name, String, :required=>true	
	property :type, String, :required=>true
    property :min_q, String, :required=>true
    property :max_q, String, :required=>true
    property :days, String, :required=>true
    property :weekend_usage, String, :required=>true
	attr_accessor :week_hours,:rio_total,:rio_total_hourly,:rio_count,:od_total,:instance_hours,:od_peak_month,:rio_total_1y,:rio_total_3y,:rio_install_1y,:rio_install_3y
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
