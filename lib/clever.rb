require 'rest_client'
require 'multi_json'

require 'clever/util'
require 'clever/json'

module Clever
  @@api_key = nil
  @@api_base = 'https://api.getclever.com/v1.1/'

  def self.api_url(url='')
    @@api_base + url
  end

  def self.api_key=(api_key)
    @@api_key = api_key
  end

  def self.api_key
    @@api_key
  end

  def self.request(method, url, api_key, params=nil, headers={})
    api_key ||= @@api_key
    raise AuthenticationError.new('No API key provided. (HINT: set your API key using "Clever.api_key = <API-KEY>")') unless api_key

    params = Util.objects_to_ids(params)
    url = self.api_url(url)
    case method.to_s.downcase.to_sym
    when :get, :head, :delete
      # Make params into GET parameters
      if params && params.count
        query_string = Util.flatten_params(params).collect{|p| "#{p[0]}=#{p[1]}"}.join('&')
        url += "?#{query_string}"
      end
      payload = nil
    else
      payload = params
    end

    headers = {
      :authorization => "Basic #{api_key}"
    }.merge(headers)

    opts = {
      :method => method,
      :url => url,
      :headers => headers,
      :open_timeout => 30,
      :payload => payload,
      :timeout => 80
    }

    begin
      response = execute_request(opts)
    rescue SocketError => e
      self.handle_restclient_error(e)
    rescue NoMethodError => e
      # Work around RestClient bug
      if e.message =~ /\WRequestFailed\W/
        e = APIConnectionError.new('Unexpected HTTP response code')
        self.handle_restclient_error(e)
      else
        raise
      end
    rescue RestClient::ExceptionWithResponse => e
      if rcode = e.http_code and rbody = e.http_body
        self.handle_api_error(rcode, rbody)
      else
        self.handle_restclient_error(e)
      end
    rescue RestClient::Exception, Errno::ECONNREFUSED => e
      self.handle_restclient_error(e)
    end

    rbody = response.body
    rcode = response.code
    begin
      # Would use :symbolize_names => true, but apparently there is
      # some library out there that makes symbolize_names not work.
      resp = Clever::JSON.load(rbody)
    rescue MultiJson::DecodeError
      raise APIError.new("Invalid response object from API: #{rbody.inspect} (HTTP response code was #{rcode})", rcode, rbody)
    end

    resp = Util.symbolize_names(resp)
    [resp, api_key]
  end

  def self.execute_request(opts)
    RestClient::Request.execute(opts)
  end

  def self.handle_restclient_error(e)
    case e
    when RestClient::ServerBrokeConnection, RestClient::RequestTimeout
      message = "Could not connect to Clever (#{@@api_base}). Please check your internet connection and try again."
    when SocketError
      message = "Unexpected error communicating when trying to connect to Clever. HINT: You may be seeing this message because your DNS is not working. To check, try running 'host getclever.com' from the command line."
    else
      message = "Unexpected error communicating with Clever."
    end
    message += "\n\n(Network error: #{e.message})"
    raise APIConnectionError.new(message)
  end
end