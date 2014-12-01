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
        json["error_messages"]
      else
        json
      end
    end

  end

  class Trade < Hashie::Mash

  end

  class Price < Hashie::Mash
    def self.to_v1(result_v2)
      settlement = DateTime.parse(result_v2["settlement_cut_off_time"])
      result ={ "settlement_time"     => settlement.strftime('%d %B %Y'),
                "settlement_date"     => settlement.strftime('@ %H:%M (%z)'),
                 "delivery_date"      => settlement.strftime('%d %B %Y'),  
                 "deposit_amount"     => result_v2["deposit_amount"],
                 "fxc_market_rate"    => result_v2["mid_market_rate"],
                 "fxc_market_inverse" => (1/result_v2["mid_market_rate"]).round(4), #review: seems v2 returns oposite market and inverse semantically speaking
                 "quote_ref"          => "", #???
                 "side"               => result_v2["fixed_side"],
                 "ccy_pair"           => result_v2["currency_pair"],
                 "ccy_pair_inverse"   => "#{result_v2["currency_pair"][3..5]}#{result_v2["currency_pair"][0..2]}",#review
                 "your_rate"          => result_v2["core_rate"], #review: quore_rate or client_rate?
                 "your_rate_inverse"  => (1/result_v2["core_rate"]).round(4),#review: quore_rate or client_rate?
                 "real_market"        => "",
                 "real_market_inverse"=> "",
                 "display_inverse"    => false,
                 "sell_currency"      => result_v2["client_sell_currency"],
                 "buy_currency"       => result_v2["client_buy_currency"],
                 "sell_amount"        => result_v2["client_buy_amount"],
                 "buy_amount"         => result_v2["client_sell_amount"],
                 "quote_time"         => "",
                 "quote_date"         => ""
               }
        result
    end

  end

  class TheCurrencyCloud < TheCurrencyCloudApi
    def available_currencies()
      get('/v2/reference/currencies')
    end

    def conversion_dates(pair)
      get('v2/reference/conversion_dates',{conversion_pair: pair})
    end

    def multiple_quotes(pairs)
      r = get('/v2/rates/find',{currency_pair: pairs})
      r
    end
     alias_method :prices_market, :multiple_quotes

    def detailed_quote(options)
      r = get('/v2/rates/detailed', options)
      Price.new(Price.to_v1(r)
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
