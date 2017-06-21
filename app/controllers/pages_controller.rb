class PagesController < ApplicationController

	def index
		@items = Product.item_search "SearchIndex"=>"Books", "ResponseGroup"=>"Images,ItemAttributes,Offers", "Author"=>"N. M. Beguesse"
		@title = "My Books"
	end

	def product
		@item = Product.item_lookup "ItemId" => params[:asin], "IdType" => "ASIN", "ResponseGroup" => "EditorialReview,Images,ItemAttributes,Offers,Reviews"
		@title = @item["ItemAttributes"]["Title"]
	end


end
