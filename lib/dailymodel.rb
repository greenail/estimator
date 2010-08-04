require 'rubygems'
require 'dm-core'
require 'yaml'
module JS
class DailyModel
    include DataMapper::Resource
    property :id,Serial
    property :name, String, :required=>true	
    property :yaml, Text, :required=>true, :lazy=>false
 	attr_accessor :usage,:max_instances,:model_min,:day,:ami_type,:model_max,:ami_types,:instance_hours,:weekend_days,:weekend_usage,:ri_one_time,:temp_hash,:debug
		

	# TODO: put timezone in monthly model, not sure if needed
	#  	do method that takes config as argument to run everything
	#  	May want to have fist month calculation

	def initialize(usage = 1)
		@usage = usage	
		@day = {}
		@max_instances = 0
		hs = open('default_daily_usage.yaml') { |f| YAML.load(f) }
                @yaml = hs.to_yaml
	end
	def get_types
		# Pulls types from disk or memory depenging on initialization.
		if (@ami_types == nil)
			puts "Loading AMI Types from disk" if @debug
       			@ami_types = open('ami_types.yaml') { |f| YAML.load(f) }
		elsif (@ami_types.length == 0)
			puts "Loading AMI Types from disk, #{@ami_types.length}" if @debug
                        @ami_types = open('ami_types.yaml') { |f| YAML.load(f) }
		else
			puts "Loading AMI Types from memory, #{@ami_types.length}" if @debug
			@ami_types
		end
	end
	def put_hour(hour,usage)
		# Upadates hash of  hour objects
		
		if (@temp_hash == nil)
			@temp_hash = YAML::load(@yaml)
		end
		@temp_hash[hour] = usage
		@yaml = @temp_hash.to_yaml
	end
	
	def get_daily_model(ami_type,usage = 1,model_min = 0,model_max = 1)
		# This is the main setup of the model for a given usage
		# returns nothing 
		
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
		if (@yaml != nil)
			puts "Loading SimpleDB Model" if @debug 
			hs =  YAML::load(@yaml)
		end
		puts "DM: sorting thorugh hours" if @debug
		raise "could not find hs in DM" unless hs.size > 0
		hs.sort.each { |k,v|
			puts "DM: hour k: #{k} v: #{v}" if @debug
			h = JS::Hour.new
			hour_usage = (v * @usage)
			hour_instances = (@model_max * hour_usage).to_f.round
			# use the greater of hour_usage or minimum
			if (hour_instances <= @model_min) 
				hour_instances = @model_min
			end
			# set the peak number of instances
			puts "H #{hour_instances} MI #{@max_instances}" if @debug
			if (hour_instances > @max_instances)
				@max_instances = hour_instances
			end
			h.od_price = hour_instances * @ami_type[:OD_hourly].to_f
			h.usage = hour_usage
			h.instances = hour_instances
			@instance_hours += hour_instances
			@day[k] = h
			}
	end
	def calc_optimal_ris
		# Calculates the optimal RI count for a given configuration by bruit force running through each and every possible RI count.
		# May want to do some logic to predict which way to move the counter based on previous results.
		# returns optimal RI count as an int
		
		annual_unoptimized_price = calc_annual_unoptimiezed_price	
		optimal_ris = 0
		best_price = annual_unoptimized_price
		#iterate from min to max to find best RI number	
		for i in @model_min.to_i..@max_instances
			rio_price,first_month_price,ri_one_time = calc_annual_price_with_ri(i)	
			#puts "OPTIMAL RIs: comparing #{best_price} with #{rio_price} for ##{i} RIs"  if @debug
			if (rio_price < best_price)
				best_price = rio_price
				optimal_ris = i
			end
		end
		@day.sort.each { |k,hour|
                        rio_price = optimized_ri_price(hour.instances,optimal_ris)
			hour.rio_price = rio_price
			}
		return optimal_ris
	end
	def calc_annual_unoptimiezed_price
		# Calculates annual price to run on demand instances for model growth curves
		
		daily_price = @ami_type[:OD_hourly].to_f * @instance_hours	
		weekend_instances = (@model_max * @weekend_usage).to_f.round
		if (weekend_instances < @model_min)
			weekend_instances = @model_min	
		end
		weekend_price = @ami_type[:OD_hourly].to_f * @weekend_days * weekend_instances * 24
		weekly_price = (daily_price * (7 - @weekend_days)) + weekend_price	
		annual_price = weekly_price * 52
	end
	def optimized_ri_price(instances,ri)
		# Calculates hourly price based on number of instance for that hour 
		# and available reserved instances
		
		rio_price = 0.0
		if (instances >= ri)
            od_instances =  instances - ri
            ri_price = ri * @ami_type[:RI_hourly].to_f
            od_price = od_instances * @ami_type[:OD_hourly].to_f
            rio_price = ri_price + od_price
        else
            rio_price =  instances * @ami_type[:RI_hourly].to_f
        end
		return rio_price
	end
	def calc_annual_price_with_ri(ri)
		# Calculates annual price given RI count as input
		# Returns:
		# 		annual_price: total project cost including RI purchase
		# 		first_month_price: this is the one time purchase price + the monthly recurring cost with a given model
		# 		ri_one_time: upfront RI purchase cost
		
		daily_rio_price = 0.0
		print "\n"
		@day.sort.each { |k,hour|
			rio_price = optimized_ri_price(hour.instances,ri)
			#print "Hour #{k} price: #{rio_price}"
			daily_rio_price += rio_price
			# TODO: figure out how to set this for optimal ri instead of for each iteration of optimal ri test
			#@day[k].rio_price = daily_rio_price
		}
		weekend_instances = (@model_max * @weekend_usage).to_f.round
                if (weekend_instances < @model_min)
                        weekend_instances = @model_min
                end
		weekend_rio_price = @ami_type[:RI_hourly].to_f * weekend_instances * 24 * @weekend_days
		weekly_price = (daily_rio_price * (7 - @weekend_days)) + weekend_rio_price
		ri_one_time = @ami_type[:RI_y1_install] * ri
		annual_price = weekly_price * 52 + ri_one_time
		first_month_price = weekly_price * 4.3333333 + ri_one_time
		#puts "Daily RIO: #{daily_rio_price} weekly: #{weekly_price} RI onetime: #{@ri_one_time} #ri #{ri} annual_price: #{annual_price}"  if @debug
		return annual_price, first_month_price, ri_one_time
	end
	def print_daily_model
		# debug print method
		thash = YAML::load(@yaml)
		thash.sort.each { |k,v|
			puts "hour: #{k} usage: #{v}"
			}
	end
	def print_day
		# debug print method
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
