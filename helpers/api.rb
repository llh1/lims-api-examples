require 'json'
require 'rest_client'
require 'facets'
require 'constant'

module Lims
  module Examples
    module API
      include Constant
      HEADERS = {'Content-Type' => 'application/json', 'Accept' => 'application/json'}

      def self.included(klass)
        extend ClassMethods
        extend ClassMethods::Request
        extend ClassMethods::Output
        extend ClassMethods::MockBarcode
        extend ClassMethods::MockPrinterService
      end

      module ClassMethods
        def set_root(root)
          @root = root
          init
        end

        def root
          @root
        end

        def set_verbose(verbose)
          @verbose = verbose
        end

        def set_output(path)
          @path = path
        end

        def init
          @api = RestClient
          @output = {}
          @barcode_counter = 0
        end
        private :init

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
            response = JSON.parse(@api.get(url, HEADERS))
            dump_request("get", url, nil, response)
            response
          end

          def get_root
            response = JSON.parse(@api.get(root, HEADERS))
            dump_request("get", root, nil, response)
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

          def new_step(description = "")
            @step_description = description
          end

          def dump_request(method, url, parameters, response)
            if @recording
              new_output(method, url, parameters, response) if @path
            end
            @display_stage = false
          end

          def generate_json
            File.open(@path, 'w') { |f| f.write(@output.to_json) }
          end

          private 

          def new_output(method, url, parameters, response)
            @counter ||= 0
            @output[:default] ||= {:calls => []} 
            if method == 'post' || method == 'put'
              if @counter == 0 
                call = new_call(method, url, parameters, response, 1)
                @output[:default][:calls] << call 
              else
                # if response is nil, no next_stage in the json
                next_stage = response ? @counter + 1 : nil
                call = new_call(method, url, parameters, response, next_stage)
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
              new_stage(url, response) 
            end
          end

          def new_stage(url,response)
            call = new_call('get', url, nil, response)
            if @counter == 0
              @output[:default][:calls] << call 
            else
              @output[@counter] ||= {:calls => []}          
              @output[@counter][:calls] << call
            end
          end

          def new_call(method, url, parameters, response, next_stage = nil)
            call = {:description => @step_description, :method => method, :url => "/#{url.sub(/^\//, "")}"}
            call[:request] = parameters if parameters
            call[:response] = response
            call[:next_stage] = next_stage if next_stage
            call
          end
        end
      end
    end
  end
end
