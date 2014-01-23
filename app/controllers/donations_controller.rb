class DonationsController < ApplicationController
  force_ssl except: [:index, :stats]

  before_filter :cors_preflight, only: [:index, :stats]
  after_filter :cors_set_headers, only: [:index, :stats]

  before_filter :normalize_params, only: [:checkout, :create]

  def index
    render json: Donation.order('created_at DESC').as_json
  end

  def stats
    render json: Donation.stats
  end

  def create
    if donation.valid?
      donation.save_with_payment!
      # send_confirmation
      render :checkout
      # redirect_to confirm_donation_url(donation)
    else
      render :checkout
    end
  rescue Stripe::StripeError => e
    return render :checkout
  end

  def show
    render :confirm_creation
  end

  def confirm
    render :confirm_creation
  end

  protected

    helper_method :donation, :company?, :needs_vat?

    # def send_confirmation
    #   DonationMailer.confirmation(donation).deliver
    # end

    def donation
      @donation ||= params[:id] ? Donation.find(params[:id]) : Donation.new(params[:donation])
    end

    def company?
      false
    end

    def needs_vat?
      company?
    end

    def normalize_params
      params[:amount] = params[:amount].to_i if params[:amount]
      params[:donation] ||= { package: params[:package] || 'tiny', amount: params[:amount] }
      params[:donation][:stripe_card_token] ||= params[:stripeToken]
    end

    def cors_set_headers
      headers['Access-Control-Allow-Origin'] = '*'
      headers['Access-Control-Allow-Methods'] = 'POST, GET, OPTIONS'
      headers['Access-Control-Max-Age'] = "1728000"
    end

    def cors_preflight
      if request.method == :options
        headers['Access-Control-Allow-Origin'] = '*'
        headers['Access-Control-Allow-Methods'] = 'POST, GET, OPTIONS'
        headers['Access-Control-Allow-Headers'] = 'X-Requested-With, X-Prototype-Version'
        headers['Access-Control-Max-Age'] = '1728000'
        render text: '', content_type: 'text/plain'
      end
    end
end
