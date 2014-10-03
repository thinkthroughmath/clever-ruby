# rubocop:disable FileName
require 'rest_client'
require 'multi_json'
require 'active_support/inflector'
require 'open-uri'
require 'set'
require 'uri'
require 'cgi'

require 'clever-ruby/version'

# API operations
require 'clever-ruby/api_operations/list'
require 'clever-ruby/api_operations/nested_list'
require 'clever-ruby/api_operations/pagelist'
require 'clever-ruby/api_operations/results_list'
require 'clever-ruby/api_operations/page'

# Helpers
require 'clever-ruby/util'
require 'clever-ruby/json'
require 'clever-ruby/configuration'
require 'clever-ruby/options'

# Resources
require 'clever-ruby/clever_object'
require 'clever-ruby/api_resource'
require 'clever-ruby/nested_resource'
require 'clever-ruby/district'
require 'clever-ruby/school'
require 'clever-ruby/student'
require 'clever-ruby/section'
require 'clever-ruby/teacher'
require 'clever-ruby/event'

# Errors
require 'clever-ruby/errors/clever_error'

require 'clever-ruby/errors/api_connection_error'
require 'clever-ruby/errors/api_error'
require 'clever-ruby/errors/authentication_error'
require 'clever-ruby/errors/invalid_request_error'

# Clever Ruby library
module Clever
  class << self
    # Global configuration for using Clever
    # @api public
    # @example Configure your API key
    #   Clever.configure do |config|
    #     config.api_key = 'YOUR-API-KEY'
    #   end
    # @return [Object]
    def configure
      yield configuration
    end

    # Retrieve your stored API key
    # @api private
    # @return [String] API key
    def api_key
      configuration.api_key
    end

    # Retrieve the configured timeout
    # @api private
    # @return [Fixnum] Configuration timeout
    def timeout
      configuration.timeout
    end

    # Retrieve the configured open timeout
    # @api private
    # @return [Fixnum] Open timeout
    def open_timeout
      configuration.open_timeout
    end

    # Retrieve your stored API token
    # @api private
    # @return [String] API token
    def token
      configuration.token
    end

    # Retrieve the global Clever configuration object
    # @api private
    # @return [Hash] API configuration object
    def configuration
      @configuration ||= Clever::Configuration.new
    end

    # Retrieve the URL of the Clever API being used
    # @api private
    # @return [String] API url
    def api_url(url = '')
      configuration.api_base + url
    end
  end

  # Convert a hash of params to a query string. Does not prepend the leading '?'
  # @api private
  # @param params [Hash] Parameters to stringify
  # @return [String] Query string
  def self.convert_to_query_string(params = nil)
    if params && params.count
      params_arr = Util.flatten_params(params).map do |p|
        "#{URI.encode(p[0].to_s)}=#{URI.encode(p[1].to_s)}"
      end
      params_arr.join('&')
    else
      ''
    end
  end

  # Generate the URL and payload for a request based on data about the request
  # @api private
  # @param method [Symbol] HTTP method used
  # @param url [String] URL to send to
  # @param params [Hash] Parameters to send
  # @return [String, String] URL and payload to send via HTTP
  def self.create_payload(method, url, params)
    case method.to_s.downcase.to_sym
    when :get, :head, :delete
      url_obj = URI.parse(url)
      if url_obj.query
        params = CGI.parse(url_obj.query).map { |k, v| { k => v[0] } }.reduce(:merge).merge params
      end
      url_obj.query = convert_to_query_string params
      url = url_obj.to_s
      payload = nil
    else
      payload = params
    end
    [url, payload]
  end

  # Create options hash that specifies an HTTP request from request data
  # @api private
  # @return [Hash] parameters for executing a request
  def self.create_request_opts(method, url, params, headers)
    params = Util.objects_to_ids params
    url = api_url url
    url, payload = create_payload method, url, params

    headers[:Authorization] = 'Bearer ' + Clever.token if Clever.token

    opts = Options.new(method, url, headers, 30, payload, 120)
    opts
  end

  # Confirm API key or token are globally configured
  # @api private
  # @return [nil]
  # @raise [AuthenticationError] Error if no authentication present
  def self.check_authorization(headers)
    unless Clever.api_key || Clever.token || headers.key?(:Authorization)
      fail AuthenticationError, 'No API key provided. (HINT: set your API key using '\
        '"Clever.configure { |config| config.api_key = <API-KEY> }" or your token using '\
        '"Clever.configure { |config| config.token = <TOKEN> }" '\
        'or pass the district token as a second argument to retrieve)'
    end
  end

  # Send an HTTP request to the Clever API
  # @api private
  # @param method [Symbol] HTTP method used
  # @param url [String] URL to send to
  # @param params [Hash] parameters to send with the request
  # @param headers [Hash] headers to send with the request
  # @return [Hash] parsed JSON response
  # @raise [APIError] Error if API fails to return valid JSON
  def self.request(method, url, params = nil, headers = {})
    check_authorization(headers)
    opts = create_request_opts method, url, params, headers
    response = execute_request opts

    rbody = response.body
    rcode = response.code
    begin
      resp = Clever::JSON.load rbody
    rescue MultiJson::DecodeError
      raise APIError.new(
        "Invalid response object from API: #{rbody.inspect} (HTTP response code was #{rcode})",
        rcode, rbody, nil, opts)
    end

    resp
  end

  private

  # Execute an HTTP request safely
  # @api private
  # @param opts [Clever::Options] Definition of the request to make
  # @return [String] Request results
  # @raise [APIConnectionError] Request failure
  def self.execute_request(opts)
    begin
      request = RestClient::Request.execute opts.request_opts
    rescue SocketError => e
      handle_restclient_error e, opts
    rescue NoMethodError => e
      # TODO: investigate
      # Work around RestClient bug
      if e.message =~ /\WRequestFailed\W/
        handle_restclient_error APIConnectionError.new('Unexpected HTTP response code'), opts
      else raise
      end
    rescue RestClient::ExceptionWithResponse => e
      rcode = e.http_code
      rbody = e.http_body
      if rcode && rbody
        handle_api_error rcode, rbody, opts
      else handle_restclient_error e, opts
      end
    rescue RestClient::Exception, Errno::ECONNREFUSED => e
      handle_restclient_error e, opts
    end

    request
  end

  # Translate errors thrown by RestClient into standardized APIConnectionErrors
  # @api private
  # @param e [Error] Error to handle
  # @return [nil]
  # @raise [APIConnectionError] Standardized error for request failures
  def self.handle_restclient_error(e, opts = nil)
    case e
    when RestClient::ServerBrokeConnection, RestClient::RequestTimeout
      message = "Could not connect to Clever (#{configuration.api_base}). " \
      'Please check your internet connection and try again.'
    when SocketError
      message = 'Unexpected error communicating when trying to connect to Clever. HINT: ' \
        'You may be seeing this message because your DNS is not working. To check, try running ' \
        "'host api.clever.com' from the command line."
    else
      message = 'Unexpected error communicating with Clever.'
    end
    message += "\n\n(Network error: #{e.message}) (Opts: #{opts})"
    fail APIConnectionError, message
  end

  # Translate errors returned as JSON by the Clever API into CleverErrors
  # @api private
  # @param rcode [Integer] response code
  # @param rbody [String] response body
  # @return [nil]
  # @raise [CleverError] Clever error corresponding to the failure observed
  def self.handle_api_error(rcode, rbody, opts)
    begin
      error_obj = Clever::JSON.load rbody
      error = error_obj[:error]
      fail CleverError unless error # escape from parsing
    rescue MultiJson::DecodeError, CleverError
      raise APIError.new(
        "Invalid response object from API: #{rbody.inspect} (HTTP response code was #{rcode})",
        rcode, rbody, nil, opts)
    end

    case rcode
    when 400, 404 then
      fail invalid_request_error error, rcode, rbody, error_obj, opts
    when 401
      fail authentication_error error, rcode, rbody, error_obj, opts
    else
      fail api_error error, rcode, rbody, error_obj, opts
    end
  end

  # Generate an InvalidRequestError
  # @api private
  # @return [InvalidRequestError]
  def self.invalid_request_error(error, rcode, rbody, error_obj, opts)
    if error.is_a? Hash
      InvalidRequestError.new error[:message], error[:param], rcode, rbody, error_obj, opts
    else
      InvalidRequestError.new error, '', rcode, rbody, error_obj, opts
    end
  end

  # Generate an AuthenticationError
  # @api private
  # @return [AuthenticationError]
  def self.authentication_error(error, rcode, rbody, error_obj, opts)
    AuthenticationError.new error[:message], rcode, rbody, error_obj, opts
  end

  # Generate an APIError
  # @api private
  # @return [APIError]
  def self.api_error(error, rcode, rbody, error_obj, opts)
    APIError.new error[:message], rcode, rbody, error_obj, opts
  end
end
