require_relative 'response'
require 'net/http'
require 'json'
require 'jpush/utils/exceptions'

module JPush
  module Http
    class Client

      class << self

        def get(jpush, url, params: nil, headers: {})
          request(jpush, :get, url, params: params, headers: headers)
        end

        def post(jpush, url, body: , headers: {})
          request(jpush, :post, url, body: body, headers: headers)
        end

        def put(jpush, url, body: , headers: {})
          request(jpush, :put, url, body: body, headers: headers)
        end

        def delete(jpush, url, params: nil, headers: {})
          request(jpush, :delete, url, params: params, headers: headers)
        end

        def request(jpush, method, url, params: nil, body: nil, headers: {}, opts: {})
          raw_response = self.new(
            jpush,
            method,
            url,
            params: params,
            body: body,
            headers: headers,
            opts: opts
          ).send_request

          Response.new(raw_response)
        end

      end

      DEFAULT_USER_AGENT = 'jpush-api-ruby-client/' + JPush::VERSION
      DEFAULT_OPEN_TIMEOUT = 20
      DEFAULT_READ_TIMEOUT = 120
      DEFAULT_RETRY_TIMES = 3
      RETRY_SLEEP_TIME = 3

      HTTP_VERB_MAP = {
        get:    Net::HTTP::Get,
        post:   Net::HTTP::Post,
        put:    Net::HTTP::Put,
        delete: Net::HTTP::Delete
      }

      DEFAULT_HEADERS = {
        'user-agent' => DEFAULT_USER_AGENT,
        'accept' => 'application/json',
        'content-type' => 'application/json',
        'connection' => 'close'
      }

      def initialize(jpush, method, url, params: nil, body: nil, headers: {}, opts: {})
        method = method.downcase.to_sym
        @uri = URI(url)
        @uri.query = URI.encode_www_form(params) unless params.nil?
        @request = prepare_request(method, body, headers)
        @request.basic_auth(jpush.app_key, jpush.master_secret)
        @opts = opts
      end

      def send_request
        tries ||= DEFAULT_RETRY_TIMES
        opts ||=  {
          use_ssl: 'https' == @uri.scheme,
          open_timeout: DEFAULT_OPEN_TIMEOUT,
          read_timeout: DEFAULT_READ_TIMEOUT
        }.merge @opts
        Net::HTTP.start(@uri.host, @uri.port, opts) do |http|
          http.request(@request)
        end
      # if raise Timeout::Error retry it for 3 times
      rescue Net::OpenTimeout, Net::ReadTimeout => e
        (tries -= 1).zero? ? (raise Utils::Exceptions::TimeOutError.new(e)) : retry
      rescue EOFError
        (tries -= 1) <= 1 ? (raise Utils::Exceptions::TimeOutError.new(e)) : retry
      end

      private

        def prepare_request(method, body, headers)
          headers = DEFAULT_HEADERS.merge(headers)
          request = HTTP_VERB_MAP[method].new @uri
          request.initialize_http_header(headers)
          request.body = body.to_json unless body.nil?
          request
        end

    end
  end
end
