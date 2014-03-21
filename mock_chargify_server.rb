require 'rack'

module MockChargifyServer
  class Server

    def initialize(capybara_host, capybara_port)
      @app = Rack::Builder.new do
        use Rack::CommonLogger
        use Rack::ShowExceptions
        map '/signups' do
          run SignupResponse.new(capybara_host, capybara_port)
        end

        map '/calls' do
          run CallResponse.new(capybara_host, capybara_port)
        end

      end
    end

    def call(env)
      @app.call(env)
    end
  end

  class SignupResponse
    def initialize(capybara_host, capybara_port)
      @capybara_host = capybara_host
      @capybara_port = capybara_port
    end

    def call(env)
      response = Rack::Response.new
      parameters = ParameterBuilder.new.create

      response.redirect("http://#{@capybara_host}:#{@capybara_port.to_s}/subscription/verify?#{parameters}")
      response.finish
    end
  end

  class CallResponse
    def initialize(capybara_host, capybara_port)
      @capybara_host = capybara_host
      @capybara_port = capybara_port
    end

    def call(env)
      json = File.open(File.dirname(__FILE__) + '/../fixtures/chargify_v2_subscription_call_response.json').read
      response = Rack::Response.new json, 200, {"Content-Type"=>"application/json"}
      response.finish
    end
  end

  class ParameterBuilder
    def initialize
      @parameter_list = {
        api_id: ENV['CHARGIFY_DIRECT_API_ID'],
        timestamp: Time.zone.now,
        nonce: SecureRandom.hex(20),
        status_code: 200,
        result_code: 2000,
        call_id: 'chargify_id'
      }

      @parameters = []
    end

    def create
      @parameter_list.each do |k,v|
        @parameters << Parameter.new(k,v)
      end

      @parameters << Parameter.new('signature', sign_parameters)
      @parameters.map(&:to_s).join("&")
    end

    private
    def sign_parameters
      key = ENV['CHARGIFY_DIRECT_API_SECRET']
      data = @parameters.map(&:value).join('')
      OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), key, data)
    end
  end

  class Parameter
    attr_reader :value

    def initialize(name, value)
      @name = name
      @value = value
    end

    def to_s
      "#{@name}=#{@value}"
    end
  end
end
