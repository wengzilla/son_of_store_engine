class OrdersController < ApplicationController

  before_filter :is_logged_in?
  before_filter :belongs_to_current_user?, only: [:show]

  def new
    if current_user.credit_cards.empty?
      redirect_to new_credit_card_path(current_store.slug) and return
    end

    if current_user.shipping_details.empty?
      redirect_to new_shipping_detail_path(current_store.slug) and return
    end

    @order = Order.new()
    @order.credit_card = current_user.credit_cards.last
    @order.shipping_detail = current_user.shipping_details.last
  end

  def index
    @orders = current_user.orders.desc
  end

  def create
    @order = Order.create_for(current_user, current_cart, params[:order])

    if @order.set_cc_from_stripe_customer_token(params[:order][:customer_token])
      redirect_to order_path(current_store.slug, @order.id),
        :notice => "Thank you for placing an order." if @order.charge(current_cart)
      OrderMailer.order_confirmation(@or).deliver
    else
      render :new
    end
  end

  def show
    @order = current_user.orders.find_by_id(params[:id])
    @shipping_detail = @order.shipping_detail
    redirect_to root_path, :notice => "Order not found." if @order.nil?
  end

private
  def belongs_to_current_user?
    unless Order.user_by_order_id(params[:id]) == current_user
      redirect_to root_path
    end
  end

  def is_logged_in?
    redirect_to new_guest_order_path unless current_user
  end

end
