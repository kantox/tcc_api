require 'faraday'
require 'json'
require 'hashie'
require'byebug'
require 'tcc_types'

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

      response = conn.post '/v2/authenticate/api', { :api_key => self.api_key, :login_id => login_id }
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
        raise Excption.new(json["error_messages"])
      else
        json
      end
    end

  end

  class TheCurrencyCloud < TheCurrencyCloudApi
    def available_currencies()
      get('/v2/reference/currencies')
    end
    
    def detailed_quote(options)
      r = get('/v2/rates/detailed', options)
      Price.new(r)
    end

    def create_conversion(options)
      r = post('/v2/conversions/create', options)
      Trade.new(Trade.to_v1(r))
    end
    alias_method :trade_execute, :create_conversion

    def conversion(trade_id)
     Trade.new(Trade.details_to_v1(get("/v2/conversions/#{trade_id}")))
    end

    def create_bank_account(bank_account)
      response = post("/v2/beneficiaries/create", BankAccount.to_v2(bank_account))
      BankAccount.new(BankAccount.to_v1(response))
    end

    def update_bank_account(id, bank_account)
      response = post("/v2/beneficiaries/update/#{id}", BankAccount.to_v2(bank_account))
      BankAccount.new(BankAccount.to_v1(response))
    end

    def get_beneficiary(id)
      r = get('/v2/beneficiaries/#{id}')
      BankAccount.new(BankAccount.to_v1(r))

      def add_payment(payment)
        r = post('/v2/payments/create',Payment.to_v2(payment))
        Payment.new(Payment.to_v1(r))
      end

      def update_payment(id,payment)
        r = post('/v2/payments/update/#{id}',Payment.to_v2(payment))
        Payment.new(Payment.to_v1(r))
      end

      def payments(options)
        get("/v2/payments/find") #TODO conversion
      end

      def payment(id)
        r = get("/v2/payments/#{id}")
        Payment.new(Payment.to_v1(r))
      end
    end

    ##NOT USED??
    def conversion_dates(pair)
      get('v2/reference/conversion_dates',{conversion_pair: pair})
    end

    def multiple_quotes(pairs)
      r = get('/v2/rates/find',{currency_pair: pairs})
      r
    end
    alias_method :prices_market, :multiple_quotes

    
  end
end
