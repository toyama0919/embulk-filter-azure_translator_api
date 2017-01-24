require 'crack/xml'
require 'rest-client'

module Embulk
  module Filter

    class AzureTranslatorApi < FilterPlugin
      Plugin.register_filter("azure_translator_api", self)

      AUTH_ENDPOINT_PREFIX = "https://api.cognitive.microsoft.com/sts/v1.0/issueToken"
      ENDPOINT_PREFIX = "https://api.microsofttranslator.com/v2/http.svc"

      def self.transaction(config, in_schema, &control)
        task = {
          "api_type" => config.param("api_type", :string),
          "language" => config.param("language", :string, default: nil),
          "out_key_name_suffix" => config.param("out_key_name_suffix", :string),
          "key_names" => config.param("key_names", :array),
          "body_params" => config.param("body_params", :hash, default: {}),
          "params" => config.param("params", :hash, default: {}),
          "delay" => config.param("delay", :integer, default: 0),
          "per_request" => config.param("per_request", :integer, default: 1),
          "subscription_key" => config.param("subscription_key", :string),
          "content_type" => config.param("content_type", :string, default: nil),
          "category" => config.param("category", :string, default: nil),
          "to" => config.param("to", :string),
          "from" => config.param("from", :string, default: nil)
        }

        add_columns = task['key_names'].map do |key_name|
          Column.new(nil, key_name + task["out_key_name_suffix"], :string)
        end

        out_columns = in_schema + add_columns
        task['authorization_token'] = get_authorization_token(task["subscription_key"])

        yield(task, out_columns)
      end

      def self.get_authorization_token(subscription_key)
        RestClient.post AUTH_ENDPOINT_PREFIX, "", {
          params: { 'Subscription-Key' => subscription_key }
        }
      end

      def init
        uri_string = "#{ENDPOINT_PREFIX}/#{task['api_type']}"

        @body_params = task['body_params']
        @per_request = task['per_request']
        @delay = task['delay']
        @key_names = task['key_names']
        @out_key_name_suffix = task['out_key_name_suffix']
        @language = task['language']
        @content_type = task['content_type']
        @records = []
        @params = {
          'to' => task['to'],
        }
        @params['from'] = task['from'] if task['from']
        @params['content_type'] = task['content_type'] if task['content_type']
        @params['category'] = task['category'] if task['category']
        @authorization_token = task['authorization_token']
        @resource = RestClient::Resource.new uri_string
      end

      def close
      end

      def add(page)
        records = page.map do |record|
          Hash[in_schema.names.zip(record)]
        end

        records.each do |record|
          page_builder.add(proc_record(record).values)
          sleep @delay
        end
      end

      def finish
        page_builder.finish
      end

      private
      def proc_record(record)
        @key_names.each do |key_name|
          request_param = { text: record[key_name] }.merge(@params)
          Embulk.logger.debug("request_param => #{request_param}")
          response_hash = ::Crack::XML.parse(
            @resource.get(
              {
                Authorization: "Bearer #{@authorization_token}",
                params: request_param
              }
            ) 
          )
          record[key_name + @out_key_name_suffix] = response_hash['string']
        end
        record
      end
    end
  end
end
