require 'cgi'
require 'uri'
require 'mechanize'
require 'hashie'
Hash.send :include, Hashie::Extensions

libdir = File.dirname(__FILE__)
$LOAD_PATH.unshift(libdir) unless $LOAD_PATH.include?(libdir)

require 'klout/version'
require 'klout/identity'
require 'klout/user'
require 'klout/twuser'

module Klout
  class << self
    # Allow Klout.api_key = "..."
    def api_key=(api_key)
      Klout.api_key = api_key
    end

    def base_uri=(uri)
      Klout.base_uri uri
    end

    # Allows the initializer to turn off actually communicating to the REST service for certain environments
    # Requires fakeweb gem to be installed
    def disable
      FakeWeb.register_uri(:any, %r|#{Regexp.escape(Klout.base_uri)}|, body: '{"Disabled":true}', content_type: 'application/json; charset=utf-8')
    end
  end

  # Represents a Klout API error and contains specific data about the error.
  class KloutError < StandardError
    attr_reader :data
    def initialize(data)
      @data = Hashie::Mash.new(data)
      super "The Klout API responded with the following error - #{data}"
    end
  end

  class ClientError < StandardError; end
  class ServerError < StandardError; end
  class BadRequest < KloutError; end
  class Unauthorized < StandardError; end
  class NotFound < ClientError; end
  class Unavailable < StandardError; end

  class Klout

    @base_uri = "http://api.klout.com/v2/"
    @api_key = ""
    @headers = {
      'User-Agent' => "klout-rest-#{VERSION}",
      'Content-Type' => 'application/json; charset=utf-8',
      'Accept-Encoding' => 'gzip, deflate',
      'Accept' => 'application/json'
    }

    @agent = Mechanize.new
    @agent.verify_mode = OpenSSL::SSL::VERIFY_NONE

    class << self
      # Get the API key
      def api_key
        @api_key
      end

      # Set the API key
      def api_key=(api_key)
        return @api_key unless api_key
        @api_key = api_key
      end

      # Get the Base URI.
      def base_uri
        @base_uri
      end

      def get(*args)
        path, options, = args
        url = get_absolute_url @base_uri, path
        handle_response @agent.get(url, options[:query], nil, @headers)
      end

      def post(*args)
        path, options, = args
        url = get_absolute_url @base_uri, path
        handle_response @agent.post(url, options[:query], nil, @headers)
      end

      def put(*args)
        path, options, = args
        url = get_absolute_url @base_uri, path
        handle_response @agent.put(url, options[:query], nil, @headers)
      end

      def delete(*args)
        path, options, = args
        url = get_absolute_url @base_uri, path
        handle_response @agent.delete(url, options[:query], nil, @headers)
      end

      def handle_response(response) # :nodoc:
        case response.code
        when 400
          raise BadRequest.new response.parsed_response
        when 401
          raise Unauthorized.new
        when 404
          raise NotFound.new
        when 400...500
          raise ClientError.new response.parsed_response
        when 500...600
          raise ServerError.new
        else
          JSON.parse response.body
        end
      end

      def get_absolute_url(parent_url, link_url)
        return nil if link_url.nil?
        begin
          return URI.join(parent_url, link_url).to_s
        rescue URI::InvalidURIError => e
          raise e if url_encoded? link_url
          return URI.join(parent_url, URI.encode(link_url)).to_s
        end
      end
    end
  end
end

