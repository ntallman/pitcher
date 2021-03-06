require 'pitcher/version'
require 'pitcher/options'
require 'savon'
require 'csv'
require 'nokogiri'

module Pitcher
  class Pitcher
    attr_accessor :message

    # load the csv and parse
    def load_csv(file)
      metadata = File.open(file, 'r')
      metadata_parsed  = CSV.new(metadata, :headers => true, :header_converters => :symbol)
      return metadata_parsed
    end

    def create_message(metadata_parsed,settings)
      self.message = {}
      self.message[:cdmurl] = settings.cdmurl
      self.message[:username] = settings.username
      self.message[:password] = settings.password
      self.message[:license] = settings.license

      metadata_parsed.each do |line|
        self.message[:action] = line[:action]
        self.message[:collection] = line[:collection]

        contentdm_record = {
            'field' => 'dmrecord' ,
            'value' => line[:cdmnumber]
        }

        file_name = {
            'field' => line[:field],
            'value' => line[:value]
        }

        metadata = {'metadata' => [contentdm_record, file_name]}

        metadataList = {'metadataList' => metadata}

        self.message[:metadata] = metadataList
        # Define the server creds and the alias for the collection you want to use
        send_message(self.message)
      end
    end

    def send_message(message)
      # Initialize the SOAP client with the catcher service url
      client = Savon.client(
          wsdl: 'https://worldcat.org/webservices/contentdm/catcher?wsdl',
          pretty_print_xml: true,
          log: true
      )
      # Create the hash that will be sent as a message to the service with the creds and data above
      response = client.call(:process_conten_tdm, message: message)
      # build request without sending
      request = client.build_request(:process_conten_tdm, message: message)
      
      # parse request body xml, extract username and contendm record number
      doc = Nokogiri::XML(request.body)
      user = doc.at('username').text
      recordids = doc.xpath('//value')
      recordid = recordids[0].text
      # Write response to a file
      File.open('./logs/response-' + user + '.txt', 'a') { |file| file.write("\r\r" + "CONTENTdm Record Number:" + recordid + "\r" + response.body.to_hash[:process_conten_tdm_response][:return] ) }
    end
  end
end
