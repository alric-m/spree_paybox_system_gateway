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

=begin
    unless @order.payments.where(:source_type => 'Spree::PayboxSystemTransaction').present?
      #
      # Record used payment method before payment
      # because there is no way to pass additionnal params
      # to paybox system
      #
      payment_method = PaymentMethod.find(params[:payment_method_id])
      payment = @order.payments.create(:amount => @order.total,
                                       # :source => paybox_transaction,
                                       :payment_method_id => payment_method.id)
      render action: 'paybox_pay', layout: false
    end
=end
    render action: 'paybox_pay', layout: false
  end

  def ipn
    #super

    if params[:error] == NO_ERROR #&& Payr::Client.new.check_response_ipn(request.url)
      @order = current_order || raise(ActiveRecord::RecordNotFound)
      puts params.merge(:action => 'paid')
      paybox_transaction = Spree::PayboxSystemTransaction.create_from_postback params.merge(:action => 'paid')
      @order.payments.create!({
        :source => paybox_transaction,
        :source_type => paybox_transaction.class.to_s,
        :amount => @order.total,
        :payment_method => payment_method
      })
      order.next
      if order.complete?
        flash.notice = Spree.t(:order_processed_successfully)
        flash[:commerce_tracking] = "nothing special"
        session[:order_id] = nil
        redirect_to completion_route(order)
      else
        redirect_to checkout_state_path(order.state)
      end
    else
      #do stuff
      logger.debug "Erreur: #{params[:error]}"
    end

=begin
    @order = Spree::Order.find_by_number(params[:ref])
    if params[:error] == NO_ERROR #&& Payr::Client.new.check_response_ipn(request.url)
      unless @order.payments.where(:source_type => 'Spree::PayboxSystemTransaction').present?
        puts 'in the unless'
        payment_method = Spree::PaymentMethod.where(type: "Spree::PaymentMethod::PayboxSystem").first
        paybox_transaction = Spree::PayboxSystemTransaction.create_from_postback params.merge(:action => 'paid')
        payment = @order.payments.where(:state => 'checkout',
                                        :payment_method_id => payment_method.id).first

        puts 'paybox_transaction'
        puts paybox_transaction
        if payment
          payment.source = paybox_transaction
          payment.save
        else
          payment = @order.payments.create(:amount => @order.total,
                                           :source => paybox_transaction,
                                           :payment_method_id => payment_method.id)
        end

        payment.started_processing!
        unless payment.completed?
          # see: app/controllers/spree/skrill_status_controller.rb line 22
          payment.complete!
        end
      end

      @order.finalize!
      @order.next
      if @order.complete?
        flash.notice = Spree.t(:order_processed_successfully)
        flash[:commerce_tracking] = "nothing special"
        session[:order_id] = nil
        redirect_to checkout_state_path(@order.state)
      end

      logger.debug "PAYBOX_PAID: #{payment_method.inspect} #{@order.payments.inspect} #{@order.inspect} #{params.inspect}"
      render nothing: true, :status => 200, :content_type => 'text/html'
    else
      logger.debug "Erreur: #{params[:error]}"
    end
=end
  end

  private

    def payment_method
      Spree::PaymentMethod.find(params[:payment_method_id])
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
