module Clever
  # Options used for making requests.
  class Options
    # Read request method
    # @api private
    # @return [String]
    attr_reader :method

    # Read request url
    # @api private
    # @return [String]
    attr_reader :url

    # Read configured open timeout
    # @api private
    # @return [Fixnum]
    attr_reader :open_timeout

    # Read request open timeout
    # @api private
    # @return [String]
    attr_reader :payload

    # Read configured timeout
    # @api private
    # @return [Fixnum]
    attr_reader :timeout

    # Read request headers
    # @api private
    # @return [Hash]
    attr_reader :headers

    # Read configured api key
    # @api private
    # @return [String]
    attr_reader :api_key

    # Initialize options
    # @api private
    # @param method [String]
    # @param url [String]
    # @param headers [Hash]
    # @param payload [String]
    # @return [Clever::Options]
    def initialize(method, url, headers, payload)
      @method = method
      @url = url
      @headers = headers
      @open_timeout = Clever.open_timeout
      @payload = payload
      @timeout = Clever.timeout
      @api_key = Clever.api_key
    end

    # Returns a string version suitable for logs
    # @api private
    # @return [String]
    def to_s
      clean_opts(request_opts).to_s
    end

    # Returns a hash of the request options, suitable for RestClient
    # @api private
    # @return [Hash]
    def request_opts
      opts = {
        method: method,
        url: url,
        headers: headers,
        open_timeout: open_timeout,
        payload: payload,
        timeout: timeout
      }
      if api_key
        opts[:user] = api_key
        opts[:password] = ''
      end
      opts
    end

    private

    # Masks sensitive information in the option hash
    # @api private
    # @param opts [Hash] Original request options
    # @return [Hash] Request options with sensitive info masked
    def clean_opts(opts)
      opts[:headers] = headers_without_sensitive_info
      opts[:user] = user_api_key_without_sensitive_info if api_key
      opts
    end

    # Returns the headers with sensitive tags stripped, for logs
    # @api private
    # @return [Hash]
    def headers_without_sensitive_info
      headers.map { |k, v| format_header(k, v) }
    end

    # Returns the api key, formatted for logs
    # @api private
    # @return [String]
    def user_api_key_without_sensitive_info
      format_sensitive_string(api_key)
    end

    # Formats a string that contains sensitive info
    # @api private
    # @param s [String] Sensitive information to mask
    # @return [String] String with all but trailing characters masked
    def format_sensitive_string(s)
      padding_length = s.length - NUMBER_OF_CHARS_OF_SENSITIVE_INFO_TO_SHOW
      "#{'*' * padding_length}#{s[-NUMBER_OF_CHARS_OF_SENSITIVE_INFO_TO_SHOW..-1] || s}"
    end

    # Formats a key value pair from the header hash, masking sensitive information
    # @api private
    # @param key [Symbol] Key for a header value
    # @param value [String] Header value, potentially containing sensitive info
    # @return [String] A string showing the key and value, with the value masked if needed
    def format_header(key, value)
      display_value = SENSITIVE_HEADERS.include?(key) ? format_sensitive_string(value) : value
      "#{key}: #{display_value}"
    end

    # How many characters to reveal at the end of a string of sensitive information
    NUMBER_OF_CHARS_OF_SENSITIVE_INFO_TO_SHOW = 4

    # Array of symbols used in the header hash that contain sensitive information to mask
    SENSITIVE_HEADERS = [:Authorization]
  end
end
