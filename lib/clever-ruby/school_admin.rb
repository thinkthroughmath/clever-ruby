module Clever
  # School Admin resource
  class SchoolAdmin < APIResource
    include Clever::APIOperations::List
    @uri = 'school_admins'
    @plural = 'school_admins'
    @linked_resources = [:schools]

    # Optional attributes
    # @see Clever::CleverObject.optional_attributes
    # @api private
    # @return [Array]
    def optional_attributes
      [:email, :title, :staff_id]
    end
  end
end
