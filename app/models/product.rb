require 'time'
require 'uri'
require 'openssl'
require 'base64'
require 'open-uri'
class Product < ActiveRecord::Base
  attr_accessible :asin, :xml, :expires_at
  validates_presence_of :expires_at

  def expired?
  	if expires_at < Time.now.to_date
  	  self.destroy
  	  false
  	else
  	  true
  	end
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

  def self.lookup_by_asin asin
  	self.item_lookup "ItemId" => asin, "IdType" => "ASIN", "ResponseGroup" => "EditorialReview,Images,ItemAttributes,Offers,Reviews"
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

  def self.create_cart offer_id
    opts = {"Item.1.OfferListingId" => offer_id, "Item.1.Quantity" => "1", "ResponseGroup" => "Cart"}
    xml = self.lookup "CartCreate", opts
    return Hash.from_xml(xml)["CartCreateResponse"]["Cart"]
  end

  def self.add_to_cart offer_id, cart_id, hmac
    opts = {"Item.1.OfferListingId" => offer_id, "Item.1.Quantity" => "1", "ResponseGroup" => "Cart", "CartId" => cart_id, "HMAC" => hmac, "ResponseGroup" => "Cart"}
    xml = self.lookup "CartAdd", opts
    return Hash.from_xml(xml)["CartAddResponse"]["Cart"]
  end

  def self.get_cart cart_id, hmac
    opts = {"CartId" => cart_id, "HMAC" => hmac, "ResponseGroup" => "Cart"}
    xml = self.lookup "CartGet", opts
    return Hash.from_xml(xml)["CartGetResponse"]["Cart"]
  end

  def self.modify_cart params, cart_id, hmac
    opts = {"CartId" => cart_id, "HMAC" => hmac, "ResponseGroup" => "Cart"}.merge(params)
    xml = self.lookup "CartModify", opts
    return Hash.from_xml(xml)["CartModifyResponse"]["Cart"]
  end

end
