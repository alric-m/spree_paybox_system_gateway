module Spree
  class PayboxSystemTransaction < ActiveRecord::Base
    # attr_accessible :action, :amount, :auto, :error, :ref

    has_many :payments, :as => :source

    def actions
      # %w{capture void credit}
      %w{capture}
    end

=begin
    def can_capture?(payment)
      false # payment.state == 'pending'
    end
=end

    def auto_capture?
      true
    end

    def can_void?(payment)
      payment.state != 'void'
    end

    class << self
      def create_from_postback(params)
        self.create(
          :action => params[:action],
          :amount => params[:amount],
          :auto => params[:auto],
          :error => params[:error],
          :ref => params[:ref]
        )
      end
    end
  end
end
