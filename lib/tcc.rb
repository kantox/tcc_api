require 'faraday'
require 'json'
require 'hashie'
require'byebug'

module TCC
  def self.api_key k
    @@api_key = k
  end

  def self.api_key?
    @@api_key
  end

  def self.environment environment
    @@environment = environment
    puts "#{@@environment}"
  end

  def self.environment?
    @@environment
  end

  def self.production?
    not (environment? == "demo")
  end

  class TheCurrencyCloudApi
    # support only V2

    attr_accessor :token, :login_id, :api_key, :conn, :domain

    def initialize(environment=:demo)
      #TODO: change prod url
      self.domain = environment == :demo ? 'https://devapi.thecurrencycloud.com' : 'https://devapi.thecurrencycloud.com'
      self.conn = Faraday.new(:url => domain) do |faraday|
        faraday.request  :url_encoded             # form-encode POST params
        faraday.response :logger                  # log requests to STDOUT
        faraday.adapter  Faraday.default_adapter  # make requests with Net::HTTP
      end
      self
    end

    # Instance methods

    def authenticate(login_id, api_key=nil)
      self.api_key = api_key || TCC.api_key?
      puts "===============API_KEY===============: #{self.api_key}"
      self.login_id = login_id

      response = conn.post '/v2/authenticate/api', { :api_key => api_key, :login_id => login_id }
      json = JSON.parse(response.body)
      if json.has_key?("auth_token")
        self.token = json["auth_token"]
        {result: :ok}
      else
        {result: :ko, message: json["message"]}
      end
    end


    private

    def get(api_path,  options={})
      response = conn.get do |req|
        req.url api_path
        req.headers['X-Auth-Token'] = token
        req.headers['Content-Type'] = 'application/json'
        req.params = options
      end
      _process_response(response)
    end

    def post(api_path, options)
      response =  conn.post do |req|
        req.url api_path, options
        req.headers['X-Auth-Token'] = token
        req.headers['Content-Type'] = 'application/json'
      end
      _process_response(response)
    end

    def _process_response(response)
      json = JSON.parse(response.body)
      if json.has_key?("error_code") && json["error_messages"]
        json["error_messages"]
      else
        json
      end
    end

  end

  class Trade < Hashie::Mash

  end

  class Price < Hashie::Mash

  end

  class TheCurrencyCloud < TheCurrencyCloudApi

    def conversion_dates(pair)
      get('v2/reference/conversion_dates',{conversion_pair: pair})
    end

    def multiple_quotes(pairs)
      Price.new(get('/v2/rates/find',{currency_pair: pairs}))
    end
    alias_method :prices_market, :multiple_quotes

    def detailed_quote(options)
      r = get('/v2/rates/detailed', options)
      r
    end

    def create_conversion(options)
      post('/v2/conversions/create', options)
    end

    alias_method :trade_execute, :create_conversion

    def conversion(trade_id)
     Trade.new(get("/v2/conversions/#{trade_id}"))
    end
  end
end
