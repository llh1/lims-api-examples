require 'json'
require 'rest_client'
require 'facets'
require 'helpers/constant'

module Lims::Api::Examples
  module API

    HEADERS = {'Content-Type' => 'application/json', 'Accept' => 'application/json'}
    include Constant

    def self.included(klass)
      extend ClassMethods
      extend ClassMethods::Request
      extend ClassMethods::Output
      extend ClassMethods::MockBarcode
      extend ClassMethods::MockPrinterService
    end

    module ClassMethods
      def set_root(root)
        @api_root = root
        init
      end

      def root
        @api_root
      end

      def set_verbose(verbose)
        @verbose = verbose
      end

      def set_output(path)
        @path = path
      end

      def set_rspec_json_output(path)
        @rspec_json_path = path
      end

      def set_rspec_setup_context(shared_context_name)
        @rspec_shared_context_name = shared_context_name
      end

      def init
        @api = RestClient
        @stage = 0
        @output = {}
        @rspec_output = {}
        @barcode_counter = 0
        @order = "common"
      end
      private :init

      module MockBarcode
        def barcode
          @barcode_counter += 1
          "123456789#{@barcode_counter}".tap do |b|
            b << "0" * (13 - b.size)
          end
        end

        def mock_barcode_generation(type)
          method = "post"
          url = "/actions/create_barcode"
          ean13barcode = barcode
          parameters = {:create_barcode => {:labware => type, :role => "stock", :contents => "DNA"}}
          response = {:create_barcode => {:actions => {}, :user => "user", :application => "application", :result => {:barcode => { :actions => { :read => "http://example.org/11111111-2222-3333-4444-555555555555", :update => "http://example.org/11111111-2222-3333-4444-555555555555", :delete => "http://example.org/11111111-2222-3333-4444-555555555555", :create => "http://example.org/11111111-2222-3333-4444-555555555555"}, :uuid => "11111111-2222-3333-4444-555555555555", :ean13 => ean13barcode, :sanger => { :prefix => "ND", :number => "1233334", :suffix => "K"}}, :uuid => "11111111-2222-3333-4444-555555555555"}, :labware => type, :role => "stock", :contents => "DNA"}}
          dump_request(method, url, parameters, response)
          ean13barcode
        end
      end

      
      module MockBarcode
        def mock_barcode_generation(labware, contents)
          method = "post"
          url = "/barcodes"
          parameters = {:barcode => {:user => "username", :labware => labware, :role => "stock", :contents => contents}}
          @barcode_counter += 1
          barcode_value = @barcode_counter.to_s
          response = { "barcode"=> { "actions"=> { "read"=> "http://example.org/11111111-2222-3333-4444-555555555555", "update"=> "http://example.org/11111111-2222-3333-4444-555555555555",        "delete"=> "http://example.org/11111111-2222-3333-4444-555555555555",        "create"=> "http://example.org/11111111-2222-3333-4444-555555555555"    },    "uuid"=> "11111111-2222-3333-4444-555555555555",    "ean13"=> barcode_value,    "sanger"=> {      "prefix"=> "JD",      "number"=> barcode_value,      "suffix"=> "U"    }}} 
          dump_request(method, url, parameters, response)
          barcode_value
        end
      end

      module MockPrinterService
        def mock_printer_service
          method = "post"
          url = '/services/print<?xml version = "1.0" encoding="UTF-8"?><env:Envelope xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:n1="urn:Barcode/Service" xmlns:env="http://schemas.xmlsoap.org/soap/envelope/"><env:Body><n1:printLabels><printer>Tube printer</printer><type>2</type><headerLabel>1</headerLabel><footerLabel>1</footerLabel><labels n2:arrayType="n1:BarcodeLabelDTO[4]" xmlns:n2="http://schemas.xmlsoap.org/soap/encoding/" xsi:type="n2:Array"><item><barcode>1</barcode><desc>X</desc><name>X</name><prefix>JD</prefix><project>X</project><suffix>U</suffix></item><item><barcode>2</barcode><desc>X</desc><name>X</name><prefix>JD</prefix><project>X</project><suffix>U</suffix></item><item><barcode>3</barcode><desc>X</desc><name>X</name><prefix>JD</prefix><project>X</project><suffix>U</suffix></item><item><barcode>4</barcode><desc>X</desc><name>X</name><prefix>JD</prefix><project>X</project><suffix>U</suffix></item></labels></n1:printLabels></env:Body></env:Envelope>'
          parameters = ''
          response = nil
          dump_request(method, url, parameters, response)
        end
      end


      module Request
        def post(url, parameters)
          parameters[parameters.keys.first] = {:user => Constant::USER}.merge(parameters[parameters.keys.first])
          json_parameters = parameters.to_json
          response = JSON.parse(@api.post(url, json_parameters, HEADERS))
          dump_request("post", url, parameters, response)
          response
        end

        def put(url, parameters)
          parameters = {:user => Constant::USER}.merge(parameters)
          json_parameters = parameters.to_json
          response = JSON.parse(@api.put(url, json_parameters, HEADERS))
          dump_request("put", url, parameters, response)
          response
        end

        def get(url)
          #url = url.sub(@api_root, '')
          response = JSON.parse(@api.get(url, HEADERS))
          dump_request("get", url, nil, response)
          response
        end

        def get_root
          response = JSON.parse(@api.get(@api_root, HEADERS))
          dump_request("get", @api_root, nil, response)
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

        def rspec_dump_new_uuids(h)
          [].tap do |uuids|
            h.each do |k,v|
              v[:steps].each do |step|
                if step[:method].downcase == "post"
                  step[:response].each do |rk, rv|
                    uuids << rv["uuid"] if rv["uuid"]
                  end
                end
              end
            end
          end
        end

        def generate_rspec_json
          if @rspec_json_path
            setup = "include_context '#{@rspec_shared_context_name}'"
            header = ["Accept: application/json"]
            response_header = ["Content-Type: application/json"]
            output = formatted_output
            uuids = rspec_dump_new_uuids(output)
            uuids_setup = "push_uuids(#{uuids.inspect})"
            rspec_output = {:global_setup => setup, :header => header, :response_header => response_header, :setup => uuids_setup}.merge(output)
            File.open(@rspec_json_path, 'w') { |f| f.write(rspec_output.to_json)}
          end
        end

        # As the output variable contains first all the json
        # for the first order and then all the json for the
        # second order, we mix the stage below to have
        # Json order 1 stage 1, Json order 2 stage 1 etc...
        def generate_json
          if @path
            output = formatted_output
            File.open(@path, 'w') { |f| f.write(output.to_json) }
          end
        end

        def dump_request(method, url, parameters, response)
          if @recording
            x_new_output(method, url, parameters, response)
            add_print_screen(method, url, parameters, response) if @verbose
            add_output(method, url, parameters, response) if @path || @rspec_json_path
          end
          @display_stage = false
        end

        def x_generate_json
          File.open("example.json", 'w') { |f| f.write(@output.to_json) }
        end

        private 

        def x_new_output(method, url, parameters, response)
          @counter ||= 0
          @output[:default] ||= {:calls => []} 
          if method == 'post' || method == 'put'
            if @counter == 0 
              call = x_new_call(method, url, parameters, response, 1)
              @output[:default][:calls] << call 
            else
              # if response is nil, no next_stage in the json
              next_stage = response ? @counter + 1 : nil
              call = x_new_call(method, url, parameters, response, next_stage)
              @output[@counter] ||= {:calls => []} 
              @output[@counter][:calls] << call
            end
            if response
              uuid = response.values.first["uuid"]
              @counter += 1
              begin
                get(uuid)
              rescue
                response = {}
                dump_request("get", uuid, nil, response) if uuid
              end
            end
          elsif method == 'get'
            x_new_stage(url, response) 
          end
        end

        def x_new_stage(url,response)
          call = x_new_call('get', url, nil, response)
          if @counter == 0
            @output[:default][:calls] << call 
          else
            @output[@counter] ||= {:calls => []}          
            @output[@counter][:calls] << call
          end
        end

        def x_new_call(method, url, parameters, response, next_stage = nil)
          call = {:description => @step_description, :method => method, :url => "/#{url.sub(/^\//, "")}"}
          call[:request] = parameters if parameters
          call[:response] = response
          call[:next_stage] = next_stage if next_stage
          call
        end



        def formatted_output
          output = @output.clone
          common = output.delete("common")
          formated = [].tap do |arr|
            output.each do |k,v|
              arr << v
            end
          end.map { |a| a.to_a }.transpose.flatten
          formated = Hash[*formated]
          i = 0
          common.merge(formated).rekey! { |k| i += 1; i}
        end

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
