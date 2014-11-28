class Spree::PayboxCallbacksController < Payr::BillsController
  before_filter :authenticate_user!, except: [:ipn]
  skip_before_filter :check_ipn_response, :only => [ :ipn ]
  before_filter :load_paybox_params, :only => [ :paybox_pay ]
  before_filter :validate_paybox, :except => [ :edit ]
  skip_before_filter :load_order, :only => [ :paybox_paid]

  NO_ERROR = "00000"

  def paybox_pay
    response.headers["Cache-Control"] = "no-cache, no-store, max-age=0, must-revalidate"
    response.headers["Pragma"] = "no-cache"
    response.headers["Expires"] = "Fri, 01 Jan 1990 00:00:00 GMT"

    render action: 'paybox_pay', layout: false
  end

  def ipn
    if params[:error] == NO_ERROR && !@order.payments.where(:source_type => 'Spree::PayboxSystemTransaction').present?
      @order = Spree::Order.find_by_number(params[:ref]) || raise(ActiveRecord::RecordNotFound)
      paybox_transaction = Spree::PayboxSystemTransaction.create_from_postback params.merge(:action => 'paid')
      @order.payments.create!({
        :source => paybox_transaction,
        :source_type => paybox_transaction.class.to_s,
        :amount => @order.total,
        :payment_method => payment_method
      })
      @order.next
      @order.reload
      if @order.complete?
        @order.payments.last.started_processing!
        unless @order.payments.last.completed?
          # see: app/controllers/spree/skrill_status_controller.rb line 22
          @order.payments.last.complete!
        end
        flash.notice = Spree.t(:order_processed_successfully)
        flash[:commerce_tracking] = "nothing special"
        session[:order_id] = nil
        redirect_to completion_route(@order)
      else
        redirect_to checkout_state_path(@order.state)
      end
    else
      #do stuff
      logger.debug "Erreur: #{params[:error]}"
    end

  end

  private

    def payment_method
      payment_method = Spree::PaymentMethod.where(type: "Spree::PaymentMethod::PayboxSystem").last
    end

    def paybox_check_ipn_response
      unless Payr::Client.new.check_response(request.url)
        raise "Bad paybox sign response"
        # redirect to failure
        return
      end
    end

    def load_paybox_params
      # return unless params[:state] == 'payment'

      @payr = Payr::Client.new

      @paybox_params = @payr.get_paybox_params_from command_id: @order.id,
                                                    buyer_email: @order.email,
                                                    total_price: ( @order.total * 100 ).to_i,
                                                    callbacks: {
                                                      paid: "#{Spree::Config.site_url}#{paybox_paid_path}",
                                                      refused: "#{Spree::Config.site_url}#{paybox_refused_path}",
                                                      cancelled: "#{Spree::Config.site_url}#{paybox_cancelled_path}",
                                                      ipn: "#{Spree::Config.site_url}paybox/ipn"
                                                    }
    end

    def validate_paybox
      return if [ 'address', 'delivery' ].include?(params[:state])
      # raise params.inspect
    end

    def completion_route(order)
      order_path(order, :token => order.guest_token)
    end

end
