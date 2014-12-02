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
        raise Excption.new(json["error_messages"])
      else
        json
      end
    end

  end
  class Utils
    def self.format_date_and_time(datetime)
      datetime_parsed = DateTime.parse(datetime)
      [datetime_parsed.strftime('%d %B %Y'), datetime_parsed.strftime('@ %H:%M (%z)')]
    end

    def self.invert_rate(rate_str,precision=4)
      rate   = rate_str.to_f
      result = if rate == 0
        0
      else
        (1/rate).round(precision)
      end
      result
    end
    def self.client_currency_pair(client_side, buy_currency, sell_currency)
      if client_side=='buy'
        "#{buy_currency}#{sell_currency}"
      else
        "#{sell_currency}#{buy_currency}"
      end
    end
  end

  class Trade < Hashie::Mash
    def self.to_v1(result_v2)
      result = { "trade_id" => result_v2["id"]}
    end

    def self.details_to_v1(result_v2)
      #Example of V1
      # {"trade_id"=>"20141125-ZTNHDY",
      #  "ccy_pair"=>"GBPUSD",
      #  "client_ccy_pair"=>"USDGBP",
      #  "client_buy_ccy"=>"USD",
      #  "client_sell_ccy"=>"GBP",
      #  "client_buy_amt"=>"1000000.00",
      #  "client_sell_amt"=>"638365.78",
      #  "side"=>"2",
      #  "client_side"=>"1",
      #  "client_rate"=>"0.6384",
      #  "client_invr"=>"1.5665",
      #  "fxc_market_rate"=>"1.5675",
      #  "fxc_market_invr"=>"0.6380",
      #  "traded_at_date"=>"2014/11/25",
      #  "traded_at_time"=>"09:29:42",
      #  "settlement_date"=>"2014/11/25",
      #  "settlement_time"=>"16:30:00",
      #  "delivery_date"=>"2014/11/25",
      #  "dealer_id"=>"48d8b4a1-e565-012f-ffea-002219427375",
      #  "trading_contact_name"=>"john.carbajal",
      #  "status"=>"awaiting_funds",
      #  "display_inverse"=>false,
      #  "deposit_required"=>false,
      #  "mid_market_rate"=>"1.5675",
      #  "mid_market_invr"=>"0.638",
      #  "tcc_core_rate"=>"1.5673",
      #  "tcc_core_invr"=>"0.638",
      #  "partner_rate"=>nil,
      #  "partner_invr"=>nil,
      #  "real_market"=>"GBPUSD"}
      #Example of V2
      # { "id": "c9b6b851-10f9-4bbf-881e-1d8a49adf7d8",
      #   "account_id":"0386e472-8d2b-45a8-9c14-a393dce5bf3a",
      #   "creator_contact_id":"ac743762-5860-4b78-9c6a-82c5bca68867",
      #   "short_reference": "20140507-VRTNFC",
      #   "settlement_date":"2014-05-21T14:00:00Z",
      #   "conversion_date": "2014-05-21T14:00:00Z",
      #   "status":"awaiting_funds",
      #   "partner_status":"awaiting_funds",
      #   "currency_pair":"GBPUSD",
      #   "buy_currency":"GBP",
      #   "sell_currency":"USD",
      #   "fixed_side":"buy",
      #   "partner_buy_amount":"1000.00",
      #   "partner_sell_amount":"1587.80",
      #   "client_buy_amount":"1000.00",
      #   "client_sell_amount":"1594.90",
      #   "mid_market_rate":"1.5868",
      #   "core_rate":"1.5871",
      #   "partner_rate":"1.5878",
      #   "client_rate":"1.5949",
      #   "deposit_required": true,
      #   "deposit_amount": "47.85",
      #   "deposit_currency": "GBP",
      #   "deposit_status": "awaiting_deposit",
      #   "deposit_required_at": "2013-05-09T14:00:00Z",
      #   "payment_ids": ["b934794f-d810-4b4a-b360-5a0f47b7126e"],
      #   "created_at": "2014-01-12T00:00:00+00:00",
      #   "updated_at": "2014-01-12T00:00:00+00:00"}
      traded_date, traded_time         = Utils.format_date_and_time(result_v2["conversion_date"])
      settlement_date, settlement_time = Utils.format_date_and_time(result_v2["settlement_date"])
      { "trade_id"             => result_v2["id"],
        "short_reference"      => result_v2["short_reference"],
        "ccy_pair"             => result_v2["currency_pair"],
        "client_ccy_pair"      => Utils.client_currency_pair(result_v2["fix_side"],result_v2["buy_currency"],result_v2["sell_currency"]), #REVIEW
        "client_buy_ccy"       => result_v2["buy_currency"],
        "client_sell_ccy"      => result_v2["sell_currency"],
        "client_buy_amt"       => result_v2["client_buy_amount"],
        "client_sell_amt"      => result_v2["client_sell_amount"],
        "side"                 => "????",                         
        "client_side"          => result_v2["fixed_side"], #fix_side is what the client has chosen when trade
        "client_rate"          => result_v2["client_rate"].to_f,
        "client_invr"          => Utils.invert_rate(result_v2["client_rate"]),
        "fxc_market_rate"      => result_v2["partner_rate"].to_f,               #REVIEW
        "fxc_market_invr"      => Utils.invert_rate(result_v2["partner_rate"]), #REVIEW
        "traded_at_date"       => traded_date,
        "traded_at_time"       => traded_time,
        "settlement_date"      => settlement_date,
        "settlement_time"      => settlement_time,
        "delivery_date"        => "????",                                       #TODO 
        "dealer_id"            => result_v2["creator_contact_id"],              #REVIEW
        "trading_contact_name" => "????",                                       #TODO
        "status"               => result_v2["status"],
        "display_inverse"      => "????",                                       #TODO
        "deposit_required"     => result_v2["deposit_required"],
        "mid_market_rate"      => result_v2["mid_market_rate"],
        "mid_market_invr"      => Utils.invert_rate(result_v2["mid_market_rate"]),
        "tcc_core_rate"        => result_v2["core_rate"],
        "tcc_core_rate_invr"   => Utils.invert_rate(result_v2["core_rate"]),
        "partner_rate"         => result_v2["partner_rate"],
        "partner_invr"         => Utils.invert_rate(result_v2["partner_rate"]),
        "deposit_currency"   => result_v2["deposit_currency"],
        "deposit_amount"     => result_v2["deposit_amount"]
      }
    end

  end

  class Price < Hashie::Mash
    
    #Given a quote from v2 of the API it converts to expected quote fields in V1 (which app works)
    def self.to_v1(result_v2)
      #Example of V1
        # {"settlement_time"=>"@ 16:30 (+0000)",
        #  "settlement_date"=>"02 December 2014",
        #  "delivery_date"=>"02 December 2014",
        #  "deposit_amount"=>"0",
        #  "fxc_market_rate"=>"0.8040",
        #  "fxc_market_inverse"=>"1.2439",
        #  "quote_ref"=>"cfb86cb2-8663-4be3-b8e9-4210639b5cbb",
        #  "side"=>"buy",
        #  "ccy_pair"=>"USDEUR",
        #  "ccy_pair_inverse"=>"EURUSD",
        #  "your_rate"=>"0.8045",
        #  "your_rate_inverse"=>"1.2430",
        #  "real_market"=>"EURUSD",
        #  "real_market_inverse"=>"USDEUR",
        #  "display_inverse"=>false,
        #  "sell_currency"=>"EUR",
        #  "buy_currency"=>"USD",
        #  "sell_amount"=>"56315.37",
        #  "buy_amount"=>"70000.00",
        #  "quote_time"=>"16:33:04",
        #  "quote_date"=>"28 Nov 2014"}

      #Example of V2
      # {"settlement_cut_off_time"=>"2014-12-02T16:30:00Z",
      #  "currency_pair"=>"EURUSD",
      #  "client_buy_currency"=>"USD",
      #  "client_sell_currency"=>"EUR",
      #  "client_buy_amount"=>"70000.00",
      #  "client_sell_amount"=>"56351.63",
      #  "fixed_side"=>"buy",
      #  "mid_market_rate"=>"1.2430",
      #  "client_rate"=>"1.2422",
      #  "partner_rate"=>"",
      #  "core_rate"=>"1.2428",
      #  "deposit_required"=>nil,
      #  "deposit_amount"=>"0.0",
      #  "deposit_currency"=>"EUR"}

      settlement_date, settlement_time = Utils.format_date_and_time(DateTime.parse(result_v2["settlement_cut_off_time"]))
      result ={ "settlement_time"     => settlement_time,
                "settlement_date"     => settlement_date,
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
    
    def detailed_quote(options)
      r = get('/v2/rates/detailed', options)
      Price.new(Price.to_v1(r))
    end

    def create_conversion(options)
      r = post('/v2/conversions/create', options)
      Trade.new(Trade.to_v1(r))
    end
    alias_method :trade_execute, :create_conversion

    def conversion(trade_id)
     Trade.new(Trade.details_to_v1(get("/v2/conversions/#{trade_id}")))
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
