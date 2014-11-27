class Spree::PayboxCallbacksController < Payr::BillsController
  before_filter :authenticate_user!, except: [:ipn]
  skip_before_filter :check_ipn_response
  NO_ERROR = "00000"

  def ipn
    #super
    @order = Spree::Order.find_by_number(params[:ref])
    if params[:error] == NO_ERROR #&& Payr::Client.new.check_response_ipn(request.url)
      unless @order.payments.where(:source_type => 'Spree::PayboxSystemTransaction').present?
        payment_method = Spree::PaymentMethod.where(type: "Spree::PaymentMethod::PayboxSystem").first
        paybox_transaction = Spree::PayboxSystemTransaction.create_from_postback params.merge(:action => 'paid')
        payment = @order.payments.where(:state => 'checkout',
                                        :payment_method_id => payment_method.id).first

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

      # until @order.state == 'complete'
      #   if @order.next!
      #     @order.update!
      #   end
      # end

      @order.finalize!
      @order.next
      if @order.complete?
        flash.notice = Spree.t(:order_processed_successfully)
        flash[:commerce_tracking] = "nothing special"
        session[:order_id] = nil
        redirect_to @order_path(order, :token => @order.guest_token)
      else
        puts '$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$'
        puts @order.errors.full_messages
        puts '$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$'
        redirect_to checkout_state_path(@order.state)
      end

      logger.debug "PAYBOX_PAID: #{payment_method.inspect} #{@order.payments.inspect} #{@order.inspect} #{params.inspect}"
      render nothing: true, :status => 200, :content_type => 'text/html'
    else
      logger.debug "Erreur: #{params[:error]}"
    end

  end
end
