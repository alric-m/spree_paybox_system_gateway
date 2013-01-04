class Spree::PayboxCallbacksController < Payr::BillsController
  skip_before_filter :check_ipn_response
  NO_ERROR = "00000"

  def ipn
    #super
    @order = Spree::Order.find(params[:ref])
    if params[:error] == NO_ERROR #&& Payr::Client.new.check_response_ipn(request.url)
      unless @order.payments.where(:source_type => 'Spree::PayboxSystemTransaction').present?
        payment_method = @order.payment_method
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

      until @order.state == 'complete'
        if @order.next!
          @order.update!
          #Spree::CheckoutController.state_callback(:after)
        end
      end

      logger.debug "PAYBOX_PAID: #{payment_method.inspect} #{@order.payments.inspect} #{@order.inspect} #{params.inspect}"
      render nothing: true, :status => 200, :content_type => 'text/html'
    else
      logger.debug "Erreur: #{params[:error]}"
    end
    #raise params.inspect
  end
end
