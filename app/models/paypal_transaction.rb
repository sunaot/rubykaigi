require 'paypal/ipn_verifier'
class PaypalTransaction < ActiveRecord::Base
  has_one :exchange_ticket

  validates_presence_of :txn_id, :item_number, :payer_email, :last_name, :first_name,
    :payment_status, :residence_country,:verify, :notified_json
  validates_uniqueness_of :txn_id

  class << self
    def create_for_verify_later!(called_back_params)
      attrs = HashWithIndifferentAccess.new
      [:txn_id, :receipt_id, :item_number, :payer_email, :last_name, :first_name,
        :payment_status, :residence_country, :memo].each do |sym|
        attrs[sym] = called_back_params[sym]
      end
      attrs[:verify] = "NOTYET"
      attrs[:notified_json] = called_back_params.to_json
      attrs[:exchange_ticket] = ExchangeTicket.new
      PaypalTransaction.transaction do
        trans = PaypalTransaction.create!(attrs)
      end
    end

  end

  def validate_transaction
    verifier = ::Paypal::IPNVerifier.new
    result = verifier.https_postback(notified_params)
    update_attribute(:verify, result)
    validate_transaction?
  end

  def validate_transaction?
    verify == "VERIFIED"
  end

  def notified_params
    ActiveSupport::JSON.decode(notified_json)
  end

  def notify_exchange_ticket_information_to_payer
    exchange_ticket.deliver_confirmation_email
  end
end
