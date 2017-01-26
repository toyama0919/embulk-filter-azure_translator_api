require_relative  'azure_translator_api/azure_translator_client'

module Embulk
  module Filter

    class AzureTranslatorApi < FilterPlugin
      Plugin.register_filter("azure_translator_api", self)

      def self.transaction(config, in_schema, &control)
        task = {
          "api_type" => config.param("api_type", :string),
          "out_key_name_suffix" => config.param("out_key_name_suffix", :string),
          "key_names" => config.param("key_names", :array),
          "params" => config.param("params", :hash, default: {}),
          "delay" => config.param("delay", :integer, default: 0),
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
        task['authorization_token'] = AzureTranslatorClient.get_authorization_token(task["subscription_key"])

        yield(task, out_columns)
      end

      def init
        @delay = task['delay']
        @key_names = task['key_names']
        @out_key_name_suffix = task['out_key_name_suffix']

        params = {
          'to' => task['to'],
        }
        params['from'] = task['from'] if task['from']
        params['content_type'] = task['content_type'] if task['content_type']
        params['category'] = task['category'] if task['category']
        @client = AzureTranslatorClient.new(
          params: params,
          authorization_token: task['authorization_token'],
          api_type: task['api_type']
        )
      end

      def close
      end

      def add(page)
        records = page.map do |record|
          Hash[in_schema.names.zip(record)]
        end

        records.each do |record|
          @key_names.each do |key_name|
            record[key_name + @out_key_name_suffix] = @client.translate_text(record[key_name])
          end
          page_builder.add(record.values)
          sleep @delay
        end
      end

      def finish
        page_builder.finish
      end
    end
  end
end
