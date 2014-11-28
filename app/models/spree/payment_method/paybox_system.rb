module Spree
  class PaymentMethod::PayboxSystem < PaymentMethod
    def actions
      %{capture void}
    end

    # Indicates whether its possible to capture the payment
    def can_capture?(payment)
      ['checkout', 'pending'].include?(payment.state)
    end

    # Indicates whether its possible to void the payment.
    def can_void?(payment)
      payment.state != 'void'
    end

    def capture(*args)
      # ActiveMerchant::Billing::Response.new(true, "", {}, {})
      raise args.inspect
    end

    def void(*args)
      # ActiveMerchant::Billing::Response.new(true, "", {}, {})
      raise args.inspect
    end

    def source_required?
      false
    end

    def payment_source_class
      Spree::PayboxSystemTransaction
    end
  end
end
