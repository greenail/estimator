require 'rubygems'
require 'dm-core'
require 'yaml'
module JS
class DailyModel
        include DataMapper::Resource
        property :id,Serial
        property :name, String, :nullable => false
        property :yaml, String, :nullable => false
 	attr_accessor :usage,:max_instances,:model_min,:day,:ami_type,:model_max,:ami_types,:instance_hours,:weekend_days,:weekend_usage,:ri_one_time
		

	# TODO: put timezone in monthly model, not sure if needed
	#  	do method that takes config as argument to run everything
	#  	May want to have fist month calculation

	def initialize(usage = 1)
		@usage = usage	
		@day = {}
		@max_instances = 0
		
	end
	def get_types
       		@ami_types = open('ami_types.yaml') { |f| YAML.load(f) }
	end
	def get_daily_model(ami_type,usage = 1,model_min = 0,model_max = 1)
		@ami_types = get_types
		@ami_type = @ami_types[ami_type.to_sym]
		@usage = usage
		@model_min = model_min
		@model_max = model_max
		@max_instances = 0
		@day = {}
		@instance_hours = 0.0
		# TODO: add calc_daily_matrix functions
		# need to set min and max first
		# loads @day hash of hours with data from sdb access with
		# dm.day[hour].usage
		hs = {}
		if (self.yaml != nil)
			puts "Loading SimpleDB Model"
			hs =  YAML::load(self.yaml)
		end
		if (@day.size == 0 && self.yaml == nil)
			puts "Loading Default Model"
			hs = open('default_daily_usage.yaml') { |f| YAML.load(f) }
			@yaml = hs.to_yaml
			self.save
		end
		hs.sort.each { |k,v|
			h = JS::Hour.new
			hour_usage = (v * @usage)
			hour_instances = (@model_max * hour_usage).to_f.round
			# use the greater of hour_usage or minimum
			if (hour_instances <= @model_min) 
				hour_instances = @model_min
			end
			# set the peak number of instances
			#puts "H #{hour_instances} MI #{@max_instances}"
			if (hour_instances > @max_instances)
				@max_instances = hour_instances
			end
			h.od_price = hour_instances * @ami_type[:OD_hourly].to_f
			h.usage = hour_usage
			h.instances = hour_instances
			@instance_hours += hour_instances
			@day[k] = h
			}
		#@yaml = @day.to_yaml
		#self.save
	end
	def calc_optimal_ris
		annual_unoptimized_price,first_month_price = calc_annual_unoptimiezed_price	
		optimal_ris = 0
		best_price = annual_unoptimized_price
		#iterate from min to max to find best RI number	
		for i in @model_min.to_i..@max_instances
			rio_price,first_month_price = calc_annual_price_with_ri(i)	
			if (rio_price < best_price)
				best_price = rio_price
				optimal_ris = i
			end
		end
		return optimal_ris
	end
	def calc_annual_unoptimiezed_price
		daily_price = @ami_type[:OD_hourly].to_f * @instance_hours	
		weekend_instances = (@model_max * @weekend_usage).to_f.round
		if (weekend_instances < @model_min)
			weekend_instances = @model_min	
		end
		weekend_price = @ami_type[:OD_hourly].to_f * @weekend_days * weekend_instances * 24
		weekly_price = (daily_price * (7 - @weekend_days)) + weekend_price	
		#puts "Weekday Price: #{daily_price}"
		#puts "Weekend Price: #{weekend_price}"
		#puts "Weekly Price: #{weekly_price}"
		annual_price = weekly_price * 52
	end
	def calc_annual_price_with_ri(ri)
		daily_rio_price = 0.0
		@day.each { |k,hour|
			if (hour.instances >= ri)
				#od_instances = ri - hour.instances
				od_instances =  hour.instances - ri
				ri_price = ri * @ami_type[:RI_hourly].to_f
				od_price = od_instances * @ami_type[:OD_hourly].to_f
				daily_rio_price += ri_price + od_price
			end
		}
		weekend_instances = (@model_max * @weekend_usage).to_f.round
                if (weekend_instances < @model_min)
                        weekend_instances = @model_min
                end
		weekend_rio_price = @ami_type[:RI_hourly].to_f * weekend_instances * 24 * @weekend_days
		weekly_price = (daily_rio_price * (7 - @weekend_days)) + weekend_rio_price
		#puts "Weekday Price: #{daily_rio_price}"
                #puts "Weekend Price: #{weekend_rio_price}"
                #puts "Weekly Price: #{weekly_price}"
		@ri_one_time = @ami_type[:RI_y1_install] * ri
		annual_price = weekly_price * 52 + @ri_one_time
		first_month_price = weekly_price * 4.3333333 + @ri_one_time
		return annual_price, first_month_price
	end
	def print_day
		for hour in @day.keys.sort
			i = @day[hour]
			puts "Hour: #{hour}"	
			puts "\tUsage:  #{i.usage}"
			puts "\tInstances:  #{i.instances}"
			puts "\tOn Demand Price: #{i.od_price}"
			puts "\tRI Optimized Cost: #{i.rio_price}"
		end
		puts "Max Instances: #{@max_instances}"
		puts "Optimal RIs: #{@optimal_ris}"
	end

end
class Hour
	attr_accessor :usage,:instances,:od_price,:rio_price,:optimal_ris
end


end # end JS module