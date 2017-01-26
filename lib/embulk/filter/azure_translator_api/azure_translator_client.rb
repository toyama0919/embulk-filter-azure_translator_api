require 'crack/xml'
require 'rest-client'

module Embulk
  module Filter
    class AzureTranslatorApi < FilterPlugin
      class AzureTranslatorClient
        ENDPOINT_PREFIX = "https://api.microsofttranslator.com/v2/http.svc"
        AUTH_ENDPOINT_PREFIX = "https://api.cognitive.microsoft.com/sts/v1.0/issueToken"

        def self.get_authorization_token(subscription_key)
          RestClient.post AUTH_ENDPOINT_PREFIX, "", {
            params: { 'Subscription-Key' => subscription_key }
          }
        end

        def initialize(params: , authorization_token: , api_type:)
          uri_string = "#{ENDPOINT_PREFIX}/#{api_type}"
          @resource = RestClient::Resource.new uri_string
          @params = params
          @authorization_token = authorization_token
        end

        def translate_text(text)
          translate(text)['string']
        end

        def translate(text)
          request(text)
        end

        def request(text)
          request_param = { text: text }.merge(@params)
          Embulk.logger.debug("request_param => #{request_param}")
          ::Crack::XML.parse(
            @resource.get(
              {
                Authorization: "Bearer #{@authorization_token}",
                params: request_param
              }
            )
          )
        end
      end
    end
  end
end