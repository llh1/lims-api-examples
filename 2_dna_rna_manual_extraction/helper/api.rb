require 'json'
require 'rest_client'

module Lims::Api::Examples
  module API

    HEADERS = {'Content-Type' => 'application/json', 'Accept' => 'application/json'}

    def self.set_root(root)
      @api_root = root
      @api = RestClient::Resource.new(root)
    end

    def self.set_verbose(verbose)
      @verbose = verbose
    end

    def self.post(url, parameters)
      response = @api[url].post(parameters.to_json, HEADERS)
      dump_request("post", url, parameters, response)
      JSON.parse(response)
    end

    def self.put(url, parameters)
      response = @api[url].put(parameters.to_json, HEADERS)
      dump_request("put", url, parameters, response)
      JSON.parse(response)
    end

    def self.get(url)
      url = url.sub(@api_root, '')
      response = @api[url].get(HEADERS)
      dump_request("get", url, nil, response)
      JSON.parse(response)
    end

    def self.dump_request(method, url, parameters, response)
      if @verbose
        puts "#{method.upcase} /#{url.sub(/^\//, '')}"
        puts "< #{parameters.to_json}" if parameters
        puts "> #{response}" if response
        puts
      end
    end
  end
end
