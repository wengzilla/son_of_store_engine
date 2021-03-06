# model for stores
class Store < ActiveRecord::Base
  STATUSES = %w{ approved pending declined disabled }

  attr_accessible :name, :slug, :description, :status

  validates :name, :presence => true,
                   :uniqueness => true
  validates :slug, :presence => true,
                   :uniqueness => true

  has_many :carts
  has_many :categories
  has_many :credit_cards
  has_many :orders, :extend => FindByStatusExtension
  has_many :products
  has_many :shipping_details
  # has_many :store_users
  # has_many :users, :through => :store_users

  has_many :roles
  has_many :users, :through => :roles

  STATUSES.each do |status|
    define_method(status+"!") do
      self.status = status
    end

    define_method(status+"?") do
      self.status == status
    end

    scope status.to_sym, where(:status => status)
  end

  def active_roles
    roles.where('user_id IS NOT NULL')
  end

  def stockers
    roles.where(name: "store_stocker").pluck(:user_id).collect do |user_id|
      User.find(user_id)
    end
  end

  def creator
    roles.where(name: "store_admin").order("created_at DESC").first.user
  end

  def admins
    roles.where(name: "store_admin").pluck(:user_id).collect do |user_id|
      User.find(user_id)
    end
  end

  def has_multiple_admin?
    roles.where(name: "store_admin").size > 1 ? true : false
  end

  def active_products
    products.where(:retired => false)
  end

  def retired_products
    products.where(:retired => true)
  end

  def update_status(params)
    if params[:status] == "approved"
      self.status = "approved"
    elsif params[:status] == "declined"
      self.status = "declined"
    elsif params[:status] == "disabled"
      self.status = "disabled"
    end
    self
  end

  def notify_store_admin_of_status
    if status == "approved"
      Resque.enqueue(StoreEmailer, "store_approval_notification", id)
    elsif status == "declined"
      Resque.enqueue(StoreEmailer, "store_declined_notification", id)
    end
  end
end
