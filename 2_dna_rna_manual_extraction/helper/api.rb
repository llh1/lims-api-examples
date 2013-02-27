require 'json'
require 'rest_client'

module Lims::Api::Examples
  module API

    HEADERS = {'Content-Type' => 'application/json', 'Accept' => 'application/json'}

    def self.included(klass)
      extend ClassMethods
    end

    module ClassMethods
      def set_root(root)
        @api_root = root
        init
      end

      def set_verbose(verbose)
        @verbose = verbose
      end

      def set_output(path)
        @path = path
      end

      def post(url, parameters)
        response = JSON.parse(@api[url].post(parameters.to_json, HEADERS))
        dump_request("post", url, parameters, response)
        response
      end

      def put(url, parameters)
        response = JSON.parse(@api[url].put(parameters.to_json, HEADERS))
        dump_request("put", url, parameters, response)
        response
      end

      def get(url)
        url = url.sub(@api_root, '')
        response = JSON.parse(@api[url].get(HEADERS))
        dump_request("get", url, nil, response)
        response
      end

      def new_stage(description = "")
        @stage += 1
        @display_stage = true
        @stage_description = description
      end

      def reset_stage
        @stage = 0
      end

      def generate_json
        File.open(@path, 'w') { |f| f.write(@output.to_json) } if @path
      end

      def barcode
        @barcode_counter += 1
        "XX123#{@barcode_counter}K"
      end

      private 

      def init
        @api = RestClient::Resource.new(@api_root)
        @stage = 0
        @output = {}
        @barcode_counter = 0
      end

      def add_output(method, url, parameters, response)
        @output[@stage] = {:description => "Stage #{@stage}: #{@stage_description}", :steps => []} unless @output.has_key?(@stage)
        @output[@stage][:steps] << {:method => method, :url => "/#{url}", :parameters => parameters, :response => response}
      end

      def add_print_screen(method, url, parameters, response)
        if @display_stage
          puts "Stage #{@stage}"
          puts @stage_description
          puts
        end
        puts "#{method.upcase} /#{url.sub(/^\//, '')}"
        puts "< #{parameters.to_json}" if parameters
        puts "> #{response.to_json}" if response
        puts
      end

      def dump_request(method, url, parameters, response)
        add_print_screen(method, url, parameters, response) if @verbose
        add_output(method, url, parameters, response) if @path
        @display_stage = false
      end
    end
  end
end
