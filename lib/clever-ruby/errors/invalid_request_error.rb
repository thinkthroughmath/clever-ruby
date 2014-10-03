module Clever
  # An invalid request to the Clever API
  class InvalidRequestError < CleverError
    # Access param
    # @api private
    # @return [Object]
    attr_accessor :param

    # Create new InvalidRequestError
    # @api private
    # @return [Clever::InvalidRequestError]
    def initialize(message, param, http_status = nil,            # rubocop: disable ParameterLists
                   http_body = nil, json_body = nil, opts = nil)
      super message, http_status, http_body, json_body, opts
      @param = param
    end
  end
end
