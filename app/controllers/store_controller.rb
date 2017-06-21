class StoreController < ApplicationController

  def index
	asins = ["0989887901","0989887936","154634974X"]
	@items = asins.map{|asin| Product.lookup_by_asin(asin)} 
	@title = "My Books"
  end

  def product
	@item = Product.lookup_by_asin params[:asin]
	@title = @item["ItemAttributes"]["Title"]
  end

  def cart
  	@title = "Shopping Cart"
  	if params[:offer_id]
  	  get_cart
  	  if @cart
  	    @cart = Product.add_to_cart(params[:offer_id], session[:cart_id], session[:hmac])
  	  else
	    @cart = Product.create_cart(params[:offer_id])
  	  end
  	  save_cart
  	end
  	get_cart if @cart.blank?
  end

  def modify_cart
  	@title = "Shopping Cart"
  	if get_cart && request.post?
  	  cart_params = params.select{|k,v| k.include?("Item")}
  	  @cart = Product.modify_cart(cart_params, session[:cart_id], session[:hmac])
  	end
  	render :action=>:cart
  end

  def remove
  	@title = "Shopping Cart"
  	if get_cart && params[:cart_item_id]
  	  cart_params = {"Item.1.CartItemId"=>params[:cart_item_id], "Item.1.Quantity"=>0}
  	  @cart = Product.modify_cart(cart_params, session[:cart_id], session[:hmac])
  	end
  	render :action=>:cart
  end


protected

  def get_cart
    if session[:cart_id]
  	  @cart = Product.get_cart session[:cart_id], session[:hmac]
    end
  end

  def save_cart
    session[:cart_id] = @cart["CartId"]
    session[:hmac] = @cart["HMAC"]
    session[:url_encoded_hmac] = @cart["URLEncodedHMAC"]
    session[:purchase_url] = @cart["PurchaseURL"]
  end

end
