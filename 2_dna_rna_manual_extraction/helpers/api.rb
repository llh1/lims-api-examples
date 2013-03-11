require 'json'
require 'rest_client'
require 'facets'

module Lims::Api::Examples
  module API

    HEADERS = {'Content-Type' => 'application/json', 'Accept' => 'application/json'}

    def self.included(klass)
      extend ClassMethods
      extend ClassMethods::Request
      extend ClassMethods::Output
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

      def init
        @api = RestClient::Resource.new(@api_root)
        @stage = 0
        @output = {}
        @barcode_counter = 0
        @order = "common"
      end
      private :init

      def barcode
        @barcode_counter += 1
        "123456789#{@barcode_counter}".tap do |b|
          b << "0" * (13 - b.size)
        end
      end


      module Request
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
      end


      module Output
        def start_recording
          @recording = true
        end

        def stop_recording
          @recording = false
        end

        def new_order(description = "")
          @order = description
        end

        def new_stage(description = "")
          @stage += 1
          @display_stage = true
          @stage_description = description
        end

        def new_step(description = "")
          @step_description = description
        end

        # As the output variable contains first all the json
        # for the first order and then all the json for the
        # second order, we mix the stage below to have
        # Json order 1 stage 1, Json order 2 stage 1 etc...
        def generate_json
          if @path
            common = @output.delete("common")
            formated = [].tap do |arr|
              @output.each do |k,v|
                arr << v
              end
            end.map { |a| a.to_a }.transpose.flatten
            formated = Hash[*formated]
            i = 0
            output = common.merge(formated).rekey! { |k| i += 1; i}
            File.open(@path, 'w') { |f| f.write(output.to_json) }
          end
        end

        def dump_request(method, url, parameters, response)
          if @recording
            add_print_screen(method, url, parameters, response) if @verbose
            add_output(method, url, parameters, response) if @path
          end
          @display_stage = false
        end

        private 

        def add_output(method, url, request, response)
          @output[@order] ||= {} unless @output.has_key?(@order)
          stage_description = @order.is_a?(Fixnum) ? "[Order #{@order}] #{@stage_description}" : @stage_description
          @output[@order][@stage] = {:stage => stage_description, :steps => []} unless @output[@order].has_key?(@stage)
          @output[@order][@stage][:steps] << {:description => @step_description, :method => method, :url => "/#{url.sub(/^\//, "")}", :request => request, :response => response}
          reset_step
        end

        def reset_step
          @step_description = ""
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
      end
    end
  end
end
