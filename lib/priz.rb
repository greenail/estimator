
require 'yaml'
class DyModel
#load 'priz.rb';dy = DyModel.new
attr_accessor :model,:ami_types,:configs
def initialize
	@configs = {}
	@ami_types = get_types
end
def get_default_daily_usage
       model = open('default_daily_usage.yaml') { |f| YAML.load(f) }
end
def get_estimates(sdb,user_name)
	list = sdb.select("select ItemName() from dynamic_usage where ItemName() like '%#{user_name}%'")
	estimates = list[:items]
end
def get_default_monthly_usage
	model = open('default_monthly_usage.yaml') { |f| YAML.load(f) }
end
def get_monthly_usage
	fname = 'default_monthly_usage.yaml'
	if (File.exist?(fname))
                model = open(fname) { |f| YAML.load(f) }
        else
                model = get_default_daily_usage
        end
end
def get_daily_usage(usage)
	fname = 'daily_usage.yaml'
	if (File.exist?(fname))
		model = open(fname) { |f| YAML.load(f) }	
	else
		model = get_default_daily_usage
	end
	for hour in model.keys
		hourly_usage = model[hour]
		model[hour] = hourly_usage.to_f * usage.to_f
	end
	return model
end
def save_daily_usage
	open('daily_usage.yaml', 'w') { |f| YAML.dump(model, f) }	
end
def get_types
	@ami_types = open('ami_types.yaml') { |f| YAML.load(f) }
end
# moved to datamapper
#def new_config(name)
	#@configs[name] = {:type => :m1small, :min_q => 2,:max_q => 50,:metric => 50,:days_of_week => 5,:weekend_usage => 0.1,:peak_metric => 50}	
#end
def calc_monthly_optimized_cost(config)
	daily_matrix = calc_daily_matrix(config)
	total_instance_hours_per_week = calc_total_weekly_hours(daily_matrix,config)
	optimal_RIs = calc_optimal_ri(daily_matrix,total_instance_hours_per_week)
	puts "Optimal RIs: #{optimal_RIs} "
	weekly_optimized_price = calc_ri_optimized_price(optimal_RIs,daily_matrix,config)
	weekly_unoptimized_price = calc_unoptimized_weekly_cost(daily_matrix,config)
	savings = weekly_unoptimized_price.to_f - weekly_optimized_price.to_f
	puts "Optimized Weekly Price: #{weekly_optimized_price} Unoptimized Weekly Price #{weekly_unoptimized_price} Savings: #{savings}"
end
def calc_daily_matrix(config, usage)
	ami_type = config[:type]
	daily_model = get_daily_usage(usage)
	daily_matrix = {}
	# TODO fix below
	minimum = config[:min_q]
	max_q = config[:max_q]
	for hour in daily_model.keys
		next if hour == "timezone"
		usage = daily_model[hour]
		# TODO fix hardcode
		metric_calculation = (max_q.to_f * usage.to_f).to_f
		#puts "#{peak_metric} / #{metric} * #{usage.to_f} METRIC_CALCULATION: #{metric_calculation} $"
		# set number of instances to the config minimum unless the calulation is smaller then the minimum
		metric_calculation <= minimum.to_i ? number_of_instances = minimum : number_of_instances = metric_calculation
		max = number_of_instances if number_of_instances.to_i > max.to_i
		ami_type = config[:type]
		daily_matrix[hour] = {:usage => usage, :number_of_instances => number_of_instances}
	end
	return daily_matrix,minimum,max
end
def calc_unoptimized_weekly_cost(daily_matrix,config)
	od_cost = 0.0
	ami_type = @ami_types[config[:type].to_sym]
	# normal usage
	for hour in daily_matrix.keys	
		number_of_instances = daily_matrix[hour][:number_of_instances].to_i	
		od_hourly = ami_type[:OD_hourly]
                hourly_cost = od_hourly * number_of_instances
                od_cost += hourly_cost.to_f
	end	
	days_of_week = config[:days_of_week]
	od_cost = od_cost * days_of_week.to_i
	# weekend usage
        weekend_days = 7 - days_of_week.to_i
        puts "#{weekend_days.to_i} * #{config[:min_q].to_i} * 24 * #{ami_type[:OD_hourly].to_f}"
        weekend_cost = weekend_days.to_i * config[:min_q].to_i * 24 * ami_type[:OD_hourly].to_f
        puts "Weekend Cost: #{weekend_cost}"		
	od_cost += weekend_cost
end
def calc_optimal_ri(config, usage)
	# TODO: need to validate math and setup tests 
	daily_matrix,min,max = calc_daily_matrix(config,usage)
	ami_type = @ami_types[config[:type].to_sym]	
	# run weekly price for range min:max
	weekly_unoptimized_price = calc_unoptimized_weekly_cost(daily_matrix,config)
	best_optimized_price = weekly_unoptimized_price * 52
	best_ri = min
	# iterate from min to max to find best RI number
	for i in min.to_i..max.to_i
		weekly_optimized_price,odm = calc_ri_optimized_price(i,daily_matrix,config)
		this_optimized_price = weekly_optimized_price * 52 + (ami_type[:RI_y1_install] * i)
		puts "#{i} RIs--- Comparing #{best_optimized_price} with #{this_optimized_price}"
		if (this_optimized_price.to_f < best_optimized_price.to_f)
			best_optimized_price = this_optimized_price
			best_ri = i
		end
	end
	return best_ri
end
def calc_ri_optimized_price(optimal_RIs,daily_matrix,config)
	daily_instance_hours = 0
	cost = 0.0

	#
	# calculate normal days
	#
	ri_optimized_daily_matrix = {}
	ami_type = @ami_types[config[:type].to_sym]
        for hour in daily_matrix.keys
                instances = daily_matrix[hour][:number_of_instances].to_i
		if (instances.to_i > optimal_RIs.to_i)
			od_instances = instances.to_i - optimal_RIs.to_i
			hour_price = optimal_RIs * ami_type[:RI_hourly].to_f
			#hour_price += od_instances * @ami_types[config[:type]][:OD_hourly]
			hour_price += od_instances * ami_type[:OD_hourly].to_f
			print "-#{optimal_RIs}-#{od_instances} $#{hour_price}- "
			cost += hour_price
			ri_optimized_daily_matrix[hour] = hour_price
		else
			hour_price = instances *  ami_type[:RI_hourly].to_f
			print " *#{instances} $#{hour_price}* "
			cost += hour_price
			ri_optimized_daily_matrix[hour] = hour_price
		end
        end	
	weekend_usage = config[:weekend_usage]
	days_of_week = config[:days_of_week].to_i
	cost = cost * days_of_week

	#
        # calculate weekend type days, assume all RIs
        #

	weekend_usage = config[:weekend_usage]
        puts "Weekly Cost: #{cost}"
	weekend_days = 7 - days_of_week
	puts "#{weekend_days.to_i} * 24 * #{config[:min_q]} * #{ami_type[:RI_hourly]}"
	weekend_cost = weekend_days.to_i * 24 * config[:min_q].to_i * ami_type[:RI_hourly].to_f
	puts "Weekend Cost: #{weekend_cost}"
	cost += weekend_cost
	return cost,ri_optimized_daily_matrix
end
def calc_total_weekly_hours(daily_matrix,config)
	daily_instance_hours = 0
	puts "daily matrix count: #{daily_matrix.size}"
	for hour in daily_matrix.keys	
		daily_instance_hours += daily_matrix[hour][:number_of_instances].to_i
	end
	puts "daily matrix count: #{daily_matrix.size} daily hours: #{daily_instance_hours}"
	# TODO: fix hardcode
	days_of_week = config[:days_of_week].to_i
	weekend_usage = config[:weekend_usage].to_f
	weekend_days = 7 - days_of_week
	minimum = config[:min_q].to_i
	metric_calculation = weekend_usage.to_f * (config[:peak_metric].to_i/config[:metric].to_i)
	metric_calculation < minimum ? weekend_instances = minimum : weekend_instances = metric_calculation
	total_weekend_hours = weekend_days	* 24 * weekend_instances
	puts "Normal Hours: #{days_of_week} #{daily_instance_hours * days_of_week} Weekend Hours: #{weekend_days} #{total_weekend_hours}"
	total_instance_hours_per_week = total_weekend_hours + daily_instance_hours * days_of_week
	puts "total hours: #{total_instance_hours_per_week}"
	puts "weekend instances per hour: #{weekend_instances}"
	return total_instance_hours_per_week
end
def get_instance_configs(sdb,estimate_name)
	configs = {}
	list = @sdb.select("select * from dynamic_usage_configs where ItemName() like '#{@estimate_name}%'")	
	items = list[:items]
	for item in items
		
	end
end
def get_instance_config(sdb,config_name)
	puts "select * from dynamic_usage_configs where ItemName() = '#{name}'"
	list = sdb.select("select * from dynamic_usage_configs where ItemName() = '#{name}'")
	list[:items].inspect
	items = list[:items]
	h = items[0]
	name = h.keys[0]
	bad_config = h.values[0]	
	config = {}
	for key in bad_config.keys
		config[key.to_sym] = bad_config[key].to_s
	end
	return name, config
end
def delete_instance_config(sdb,name)
    result = sdb.delete_attributes("dynamic_usage_configs",name) 
end
end
