require 'time'
require 'uri'
require 'openssl'
require 'base64'
require 'open-uri'
class Product < ActiveRecord::Base
  attr_accessible :asin, :xml, :expires_at
  validates_presence_of :expires_at

  def expired?
  	expires_at < Time.now.to_date
  end

  def self.lookup operation, opts
	# Your AWS Access Key ID, as taken from the AWS Your Account page
	aws_access_key_id = ENV['AWS_ACCESS_KEY_ID']

	# Your AWS Secret Key corresponding to the above ID, as taken from the AWS Your Account page
	aws_secret_key = ENV['AWS_SECRET_KEY']

	# The region you are interested in
	endpoint = "webservices.amazon.com"

	request_uri = "/onca/xml"

	params = {
	  "Service" => "AWSECommerceService",
	  "Operation" => operation,
	  "AWSAccessKeyId" => aws_access_key_id,
	  "AssociateTag" => ENV['ASSOCIATE_TAG']
	}.merge(opts)

	# Set current timestamp if not set
	params["Timestamp"] = Time.now.gmtime.iso8601 if !params.key?("Timestamp")

	# Generate the canonical query
	canonical_query_string = params.sort.collect do |key, value|
	  [URI.escape(key.to_s, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]")), URI.escape(value.to_s, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))].join('=')
	end.join('&')

	# Generate the string to be signed
	string_to_sign = "GET\n#{endpoint}\n#{request_uri}\n#{canonical_query_string}"

	# Generate the signature required by the Product Advertising API
	signature = Base64.encode64(OpenSSL::HMAC.digest(OpenSSL::Digest.new('sha256'), aws_secret_key, string_to_sign)).strip()

	# Generate the signed URL
	request_url = "http://#{endpoint}#{request_uri}?#{canonical_query_string}&Signature=#{URI.escape(signature, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))}"

	return open(request_url).read
  end

  def self.item_search opts
  	already = self.find_by_asin(0)
  	if already.nil? || already.expired?
  	  xml = self.lookup "ItemSearch", opts
  	  already = self.create!(:asin=>0, :xml=>xml, :expires_at=>1.day.from_now)
  	end
  	xml = already.xml
  	return Hash.from_xml(xml)["ItemSearchResponse"]["Items"]["Item"]
  end


  def self.item_lookup opts
  	asin = opts["ItemId"]
  	already = self.find_by_asin(asin)
  	if already.nil? || already.expired?
  	  xml = self.lookup "ItemLookup", opts
  	  already = self.create!(:asin=>asin, :xml=>xml, :expires_at=>1.day.from_now)
  	end
  	xml = already.xml
  	return Hash.from_xml(xml)["ItemLookupResponse"]["Items"]["Item"]


  end


end
