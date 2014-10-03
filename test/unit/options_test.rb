require 'test_helper'

# test api options
describe Clever::Options do
  describe :with_authorization_token do
    before do
      @headers = { Authorization: 'Bearer CLEVER_TOKEN', AnotherHeader: 'Something not sensitive' }
      @opts = Clever::Options.new('method', 'https://api.clever.com', @headers, 'payload')
    end

    it 'provides a string with a masked Authorization token' do
      assert_equal @opts.to_s, '{:method=>"method", :url=>"https://api.clever.com", '\
                               ':headers=>["Authorization: ***************OKEN",'\
                               ' "AnotherHeader: Something not sensitive"], '\
                               ':open_timeout=>30, :payload=>"payload", :timeout=>120}'
    end
  end

  describe :with_api_key do
    before do
      Clever.configure do |config|
        config.api_key = 'DEMO_KEY'
      end
      @headers = { AnotherHeader: 'Something not sensitive' }
      @opts = Clever::Options.new('method', 'https://api.clever.com', @headers, 'payload')
    end

    it 'provides a string with a masked Authorization token' do
      assert_equal @opts.to_s, '{:method=>"method", :url=>"https://api.clever.com", '\
                               ':headers=>["AnotherHeader: Something not sensitive"], '\
                               ':open_timeout=>30, :payload=>"payload", :timeout=>120, '\
                               ':user=>"****_KEY", :password=>""}'
    end

    after do
      Clever.configure do |config|
        config.api_key = nil
      end
    end
  end

end
