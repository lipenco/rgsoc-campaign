require 'gravatar-ultimate'

class Donation < ActiveRecord::Base
  attr_accessible :stripe_card_token, :stripe_customer_id, :package, :amount, :vat_id, :add_vat, :display,
    :name, :email, :address, :zip, :city, :state, :country, :twitter_handle, :github_handle, :homepage, :comment

  class << self
    def total
      sum(:amount).to_f / 100
    end

    def stats
      stats = Hash[*connection.select_rows('SELECT package, count(id) FROM orders GROUP BY package').flatten].symbolize_keys
      stats.each { |key, value| stats[key] = value.to_i }
    end
  end

  def twitter_handle=(name)
    write_attribute(:twitter_handle, name.to_s.gsub(/^@/, ''))
  end

  def homepage=(url)
    write_attribute(:homepage, url.blank? || url =~ %r{^https?://} ? url : "http://#{url}")
  end

  def gravatar_url
    Gravatar.new(email || '').image_url
  end

  def vat
    raise "cannot calculate VAT without risking rounding issues" unless amount % 100 == 0
    (amount / 100) * 19
  end

  def amount_in_dollars
    (amount.to_f / 100).to_i
  end

  def vat_in_dollars
    vat.to_f / 100
  end

  def amount_with_vat_in_dollars
    (amount + vat).to_f / 100
  end

  def amount_with_vat
    amount + vat
  end

  def save_with_payment!
    stripe_create_customer
    stripe_create_charge
    save!
  end

  ANONYMOUS  = { name: 'Anonymous', twitter_handle: '', github_handle: '', homepage: '', comment: '' }
  JSON_ATTRS = [:package, :name, :twitter_handle, :github_handle, :homepage, :comment, :created_at]

  def as_json(options = {})
    json = super(only: JSON_ATTRS).merge(amount: amount_in_dollars)
    json.update(ANONYMOUS) unless display?
    json.update(gravatar_url: gravatar_url)
    json
  end

  private

    def stripe_create_customer
      customer = Stripe::Customer.create(description: name, email: email, card: stripe_card_token)
      # address_line1: address, address_zip: zip, address_state: state, address_country: country)
      self.stripe_customer_id = customer.id
    rescue Stripe::StripeError => e
      logger.error "Stripe error while creating stripe customer: #{e.message} (#{name}, #{email})"
      errors.add :base, "An error occured while trying to charge your credit card: #{e.message}."
      raise e
    end

    def stripe_create_charge
      amount = add_vat? ? amount_with_vat : self.amount
      description = "#{email} (#{[package, self.amount].join(', ')})"
      Stripe::Charge.create(description: description, amount: amount, currency: 'usd', customer: stripe_customer_id)
    rescue Stripe::StripeError => e
      logger.error "Stripe error while creating a stripe charge: #{e.message} (#{description})"
      errors.add :base, "An error occured while trying to charge your credit card: #{e.message}."
      raise e
    end

end
