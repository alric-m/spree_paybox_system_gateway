class Spree::PayboxCallbacksController < Payr::BillsController
  skip_before_filter :check_ipn_response, :only => [ :ipn, :ipn_n_times ]
  skip_before_filter :check_response, :only => [ :paybox_pay ]
  before_filter :validate_paybox, :except => [ :edit ]
  skip_before_filter :load_order, :only => [ :paybox_paid]

  NO_ERROR = "00000"

  def paybox_pay
  end

  def ipn
    @order = Spree::Order.find_by_number(params[:ref]) || raise(ActiveRecord::RecordNotFound)
    if params[:error] == NO_ERROR && !@order.payments.where(:source_type => 'Spree::PayboxSystemTransaction').present?
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
    elsif params[:error] != NO_ERROR
      #do stuff
      logger.debug "Erreur: #{params[:error]}"
      @order.failure!
      redirect_to checkout_state_path(@order.state)
    else
      # Doublon request
    end

  end

  def ipn_n_times
    @order = Spree::Order.find_by_number(params[:ref]) || raise(ActiveRecord::RecordNotFound)
    if params[:error] == NO_ERROR && params[:secure] == 'O' && !@order.payments.where(:source_type => 'Spree::PayboxSystemTransaction').present?
      paybox_transaction = Spree::PayboxSystemTransaction.create_from_postback params.merge(:action => 'paid')
      @order.payments.create!({
        :source => paybox_transaction,
        :source_type => paybox_transaction.class.to_s,
        :amount => (@order.total * 0.4),
        :payment_method => payment_method
      })
      @order.next
      @order.reload
      if @order.complete?
        for i in 0..2
          @order.payments[i].started_processing!
          unless @order.payments[i].completed?
            # see: app/controllers/spree/skrill_status_controller.rb line 22
            @order.payments[i].complete!
          end
          if i < 2
            @order.payments.create!({
              :source => paybox_transaction,
              :source_type => paybox_transaction.class.to_s,
              :amount => (@order.total * 0.3),
              :payment_method => payment_method
            })
          end
        end
        flash.notice = Spree.t(:order_processed_successfully)
        flash[:commerce_tracking] = "nothing special"
        session[:order_id] = nil
        redirect_to completion_route(@order)
      else
        redirect_to checkout_state_path(@order.state)
      end
    elsif params[:error] != NO_ERROR
      #do stuff
      logger.debug "Erreur: #{params[:error]}"
      redirect_to checkout_state_path(@order.state)
    else
      puts params[:secure]
      # Doublon request
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
