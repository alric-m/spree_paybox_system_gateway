=begin
#
#encoding: utf-8
#
module Spree
  CheckoutController.class_eval do
    prepend_before_filter :paybox_check_response, :only => [ :paybox_paid ]

    before_filter :load_paybox_params, :only => [ :paybox_pay ]
    before_filter :validate_paybox, :except => [ :edit ]
    skip_before_filter :load_order, :only => [ :paybox_paid]
    before_filter :check_registration, :except => [:registration, :update_registration]

    #
    # Very bad hack to handle paybox external payment from
    # standard checkout process
    #
    def update_with_paybox
      if params[:order][:payments_attributes].present?
        p_id =  params[:order][:payments_attributes].first[:payment_method_id]
        unless p_id.nil?
          if PaymentMethod.find(p_id).class == Spree::PaymentMethod::PayboxSystem
            redirect_to :action => :paybox_pay, :params => { :payment_method_id => p_id, :sra => Time.now.to_f } and return
          end
        end
      end
      update_without_paybox
    end
    alias_method_chain :update, :paybox

    def paybox_pay
      response.headers["Cache-Control"] = "no-cache, no-store, max-age=0, must-revalidate"
      response.headers["Pragma"] = "no-cache"
      response.headers["Expires"] = "Fri, 01 Jan 1990 00:00:00 GMT"

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
    end

    def paybox_paid
      # order_id, payment_method_id = params[:ref].split('|')
      unless @order.payments.where(:source_type => 'Spree::PayboxSystemTransaction').present?
        payment_method = @order.payments.first.payment_method # PaymentMethod.find(payment_method_id)
        paybox_transaction = Spree::PayboxSystemTransaction.create_from_postback params.merge(:action => 'paid') # new(:action => 'paid', :amount => params[:amount], :auto => params[:auto], :error => params[:error], :ref => order_id)

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
      #     state_callback(:after)
      #   end
      # end

      # a faire dans le ipn controller
      # @order.finalize!

      puts 'before finalize'
      puts '@order.payments.last.state'
      puts @order.payments.last.state
      puts '@order.state'
      puts @order.state

      @order.finalize!

      puts 'before next'
      puts '@order.payments.last.state'
      puts @order.payments.last.state
      puts '@order.state'
      puts @order.state
      @order.next

      puts 'after next'
      puts '@order.payments.last.state'
      puts @order.payments.last.state
      puts '@order.state'
      puts @order.state
      if @order.complete?
        flash.notice = Spree.t(:order_processed_successfully)
        flash[:commerce_tracking] = "nothing special"
        session[:order_id] = nil
        redirect_to checkout_state_path(@order.state)
      end

      logger.debug "PAYBOX_PAID: #{payment_method.inspect} #{@order.payments.inspect} #{@order.inspect} #{params.inspect}"
      render nothing: true, :status => 200, :content_type => 'text/html'


      logger.debug "PAYBOX_PAID: #{payment_method.inspect} #{@order.payments.inspect} #{@order.inspect} #{params.inspect}"

      flash.notice = t(:order_processed_successfully)
      @order.reload
      redirect_to order_path(@order, :token => @order.guest_token)

    end

    def paybox_refused
      flash[:error] = "OP&Eacute;RATION REFUS&Eacute;E".html_safe
      redirect_to "/checkout/payment"
    end

    def paybox_cancelled
      flash[:error] = "OP&Eacute;RATION ANNUL&Eacute;E".html_safe
      redirect_to "/checkout/payment"
    end

    private
      def paybox_check_response
        unless Payr::Client.new.check_response(request.url)
          raise "Bad paybox sign response"
          # redirect to failure
          return
        end
        @order = Spree::Order.find_by_number(params[:ref])
        puts "In paybox_check_response"
        puts @order
        return redirect_to cart_path if @order.nil?
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
  end
end
=end
