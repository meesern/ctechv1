#!/usr/bin/env ruby

require 'yaml'
require 'date'
require 'debugger'
require 'time'

require_relative 'timestream-feeder'

class Monitor
  attr_accessor :device
  attr_accessor :responseType
  attr_accessor :transId
  attr_accessor :fineGrain
  attr_accessor :adapting
  attr_accessor :serialnum
  attr_accessor :instantRMScurrent
  attr_accessor :samples
  attr_accessor :accumLo
  attr_accessor :accumHi
  attr_accessor :timer1
  attr_accessor :timer2
  attr_accessor :ticks
  attr_accessor :suspDis
  @@monitors = {}
  @@config = {}

  #return the current full list of instances.  Create any necessary to fulfill
  #the list of devices in /dev/ttyACM..
  #Saved data is defined by serial number, but monitors must be created according to /dev device.
  #Each monitor should consider the serial number to be immutable once set.  The main control loop 
  #should detect and close any monitor who's /dev to serial number mapping has changed 
  def self.list_or_create(dev_list )
    #Add into the current list any new devices
    dev_list.each do |dev|
      @@monitors[dev] = Monitor.new :device=>dev if @@monitors[dev].nil?
    end
    #return the full list
    @@monitors.values
  end

  #keep the config in the class 
  def self.config=(config)
    @@config = config
  end

  #init by mass assignment from hash
  def initialize(args)
    assign_from_hash(args)
  end

  #mass assignement
  def assign_from_hash(args)
    args.keys.each { |name| instance_variable_set "@" + name.to_s, args[name] }
  end

  #Consider a reading for update.  The reading may be invalid, for the wrong device, 
  #a re-read of the current sample, or good (in which case the monitor is updated)
  #return :new, :same, :unconfigured :device_mismatch, :read_fail
  def propose(reading)
    #accept the first non null serial number read
    @serialnum = reading["serialnum"] if @serialnum.nil?

    case 
      when circuit.nil?
        return :unconfigured
      when reading["serialnum"].nil? || reading["samples"].nil? || reading["instantRMScurrent"].nil?
        return :read_fail
      when reading["serialnum"] != @serialnum
        return :device_mismatch
      when reading["samples"] == @samples
        return :same
    end
    #it's a good reading.  Update
    assign_from_hash(reading)
    :new
  end

  #Save the current reading
  def save!
    #write to file
    File.open("readings/readings_for_#{name}.csv",'a') do |f|
      f.write("#{@serialnum}, #{Time.now}, #{watts}\n")
    end
    post_to_timestream
  end

  #Tidy up and remove this instance
  def close!
    @@monitors.delete(@device)
  end

  #get or create the timestream feeder 
  #timestream feeder will reuse the existing timestream container based on name if it exists
  #or will create a new container (on the server)
  def timestream
    #reset if the timestream container name changes.
    (@ts_container = container && reset_timestream) unless @ts_container == container
    #Set up the timestream feeder
    @timestream || @timestream = TimestreamFeeder.new(:host => @@config[:host],
			  :container_name => @ts_container)
  end

  #reset the timestream
  def reset_timestream
    @timestream = nil
  end

  #post the measurement to the timestream
  def post_to_timestream
    watts && timestream.feed(:ts => Time.now, :value => watts)
  end

  #convert current to watts - since we use only a nominal RMS voltage 
  #the absolute value may be in error by perhaps 25% however it is expected that 
  #relative values are more significant 
  def watts
    #RMScurrent is in microamps and depends on the clamp rating
    @instantRMScurrent*@@config[:voltage]*@@config[:rating][@serialnum]/20000000.0
  end

  def circuit
    @@config[:circuits][@serialnum] if @serialnum
  end

  #name the contanier after the measurement name
  def container
    name
  end

  #name the measurement after the circuit and deployment
  #in this way if we rework the sensors (because of a failure for example
  #new data can be properly assigned by remapping circuits in the config file
  def name
    "#{@@config[:deployment]}_#{circuit}"
  end
end

########################

#daily log rotation
def rotatelogs
  #execute the shell logrotate in the background
  `logrotate logrotate.conf &`
  true
end

#update the source from the server
def callhome
return  #disable for now until I sort out accounts and permissions
  #execute the shell rsync in the forground so that a new
  #config file that asks for a restart can not trigger before
  #the new source has loaded
  puts "syncing source with #{$config[:srcsource]} at #{Time.now}"
  puts `rsync -e ssh #{$config[:srcsource]} #{$src}`
end

#read the yaml config
def loadconfig
  config = YAML::load(File.open($conffile))
  (config.length > 2) ? $config = config : puts("Warning: Invalid config file")
  $config[:loadtime] = Time.now
  puts "read config #{$conffile} at #{$config[:loadtime]}"
  Monitor.config = $config
end

#Fix Time class's strangely missing #before? and #after? methods.
class Time
  LEFT_SIDE_LATER  = 1
  RIGHT_SIDE_LATER = -1
  
  def before?(time)
    (self <=> Time.like(time)) == RIGHT_SIDE_LATER
  end
  
  def after?(time)
    (self <=> Time.like(time)) == LEFT_SIDE_LATER
  end

  def self.like(time)
    (self.parse(time) if time.is_a?(String)) || time
  end
end

##########################################################

puts "C-Tech Energy Monitoring 201301" 
puts "Edit c-tech.yml to configure" 

$src = File.dirname(__FILE__)
$conffile = $src+'/c-tech.yml'

loadconfig

File.open($src+'/c-tech.pid','w') {|f| f.write Process.pid }

#Timing on all channels is plesiochronous
runstart = Time.now
secondstart = Time.now
today = Date.today
calltime = 0
loop do
  #rotate logfiles at midnight
  (today = Date.today) && rotatelogs if today != Date.today
  
  #reload config if changed
  loadconfig if $config[:loadtime].before?(File.mtime($conffile))

  (calltime = Time.now.hour) && callhome if calltime != Time.now.hour

  #quit if instructed
  exit if $config[:run_after] && runstart.before?($config[:run_after])
  
  #get the available devices
  device_names = `ls /dev/ttyACM*`.split("\n")

  monitors = Monitor.list_or_create(device_names)

  monitors.each do |monitor|

    begin
      reading = YAML::load(`#{$src}/ccread #{monitor.device}`)
      #puts reading
      #{"using device"=>"/dev/ttyACM1", "responseType"=>254, "transId"=>60, "fineGrain"=>1, 
      # "adapting"=>1, "serialnum"=>"0501", "instantRMScurrent"=>47968, "samples"=>428045, 
      # "accumLo"=>219003232, "accumHi"=>1, "timer1"=>198, "timer2"=>76, "ticks"=>2729, "suspDis"=>0}
    rescue Exception => e 
      reading = nil
    end

    case reading && monitor.propose(reading)
    when :unconfigured
      puts "unconf #{monitor.device}"
    when :new
      puts "read #{monitor.device}"
      monitor.save!
    when nil 
      puts "read error #{e} for #{monitor.device}"
      monitor.close!
    when :device_mismatch
      puts "device mismatch for #{monitor.device}"
      monitor.close!
    when :read_fail
      puts "read failed for #{monitor.device}"
      monitor.close!
    when :same
    end

  end
  
  duration = Time.now - secondstart 
  sleep ([0,1.0 - duration.to_f].max)
  secondstart = Time.now
  puts "All told in #{duration}"
end

