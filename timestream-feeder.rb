#
#  A simple timestreams data uploader
#
require 'net/http'
require 'uri'
require 'json'

class TimestreamFeeder
  attr_reader :container

  def initialize(params)
    @host = params[:host] || exit
    @port = params[:port] || 80
    @base = '/wp-content/plugins/timestreams/2/'

    @container = params[:container] || find_or_create(params[:container_name]) || exit
  end

  def find_or_create(name)
    find(name) || create(name)
  end

  def find(name)
    result = api_call(:get, 'measurement_containers', nil )
    container = result["measurementContainers"].find {|m| m["friendlyname"] == name}
    container && container["name"]
  end

  def create(name)
    resp = sendcreate(name)
    resp["measurementcontainer"]
  end

  def sendcreate(name)
    args = "name=#{name}&measuretype=current&min=0&max=12000&unit=text%2fx-data-Watt&symbol=W&device=#{name}&datatype=DECIMAL(10,3)&siteid=1&blogid=1&userid=1"
    api_call(:post, 'measurement_container', args )
  end


  #accept measurments with timestamps and upload them to the timesstream
  #measure is a hash with :ts and :value
  def feed(measure)
    args = "value=#{measure[:value]}&ts=#{measure[:ts]}"
    api_call(:post, 'measurement/'+@container, args )
  end

  def api_call(verb, endpoint, data)
    #URI.encode_www_form should work but freaks out SLIM
    #resp = h.post(@base+'measurement/'+@container, 
    #              URI.encode_www_form(data))
    resp = html_request(verb, @base+endpoint, data ) 
    case resp
    when Net::HTTPSuccess
      #puts resp.body
    else
      unexpected(resp)
    end
    JSON::parse(resp.body)
  end

  def html_request(verb, *args)
    #puts "#{verb} #{args.join('?')}"
    html do |h|
      (verb == :post) ? h.post(*args):h.get(args[0]) 
    end
  end

  private
  def unexpected(resp)
    puts resp.body
    raise "Got unexpected response #{resp.class}."
  end

  def html_proxy
    return [nil,nil,nil,nil] unless ENV['http_proxy']
    puts "Parsing proxy"
    uri = URI.parse(ENV['http_proxy'])
    proxy_user = proxy_pass = nil
    proxy_user, proxy_pass = uri.userinfo.split(/:/) if uri.userinfo
    proxy_host = uri.host
    proxy_host = nil if (proxy_host.empty?)
    #no proxy if the server name is a local name (not domain.tld)
    proxy_host = nil if (@host.split('.').length < 2)
    proxy_port = uri.port || 8080
    #puts "Delivering to server #{proxy_host}:#{proxy_port.to_s}->#{@host}:#{@port.to_s}"
    [proxy_host, proxy_port, proxy_user, proxy_pass]
  end

  def html
    phost,pt,pu,pp = html_proxy
    prox = Net::HTTP::Proxy(phost,pt,pu,pp)
    #puts "Opened Proxy: #{prox.inspect}" unless phost.nil?
    prox.start(@host, @port) do |h|
      yield(h)
    end
  end

end

