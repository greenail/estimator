require 'lib/priz.rb'
require '/root/creds.rb'
require 'right_aws'

class Priz < Merb::Controller

  def _template_location(action, type = nil, controller = controller_name)
    controller == "layout" ? "layout.#{action}.#{type}" : "#{action}.#{type}"
  end

  def index
	@user_name = cookies[:user_name]
	@index_name = cookies[:index_name]
    render
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
	cookies[:user_name] = user_name
	cookies[:index_name] = index_name
	key,skey = getCreds()
	@sdb = RightAws::SdbInterface.new(key,skey)
	@sdb.put_attributes('dynamic_usage',index_name,"empty")
    render
  end
end

class NewConfig < Merb::Controller

  def _template_location(action, type = nil, controller = controller_name)
    controller == "layout" ? "layout.#{action}.#{type}" : "#{action}.#{type}"
  end
  def show_daily_price
         @dy = DyModel.new
	@index_name = cookies[:index_name]
	 key,skey = getCreds()
        @sdb = RightAws::SdbInterface.new(key,skey)
        render
  end
  def index
	 @dy = DyModel.new
    render :new_config
  end
  def add_config
	@index_name = cookies[:index_name]
	key,skey = getCreds()
	@sdb = RightAws::SdbInterface.new(key,skey)
	name = params['name']
	@sdb.put_attributes("dynamic_usage_configs","#{@index_name}-#{name}",params,true)
	render :index
  end
  def edit_config
	@dy = DyModel.new
	@index_name = cookies[:index_name]
	key,skey = getCreds()
        @sdb = RightAws::SdbInterface.new(key,skey)
	@config_name = params['config_key']
	@name,@config = @dy.get_instance_config(@sdb,@config_name)
	render :edit_config
  end

end
class DailyModel < Merb::Controller

  def _template_location(action, type = nil, controller = controller_name)
    controller == "layout" ? "layout.#{action}.#{type}" : "#{action}.#{type}"
  end
  def index
         @dy = DyModel.new
	@daily_model,min,max = @dy.get_daily_usage
    render :edit_daily_model
  end
end
