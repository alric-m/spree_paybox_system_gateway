Spree::Core::Engine.add_routes do
  # Add your extension routes here

  # payr_routes callback_controller: "spree/paybox_system/callbacks"

  # # resources :orders do
  #   resource :checkout, :controller => 'checkout' do
  #     # member do
  #     collection do
  #       get :paybox_pay
  #       get :paybox_paid
  #       get :paybox_refused
  #       get :paybox_cancelled
  #       # get :paybox_ipn
  #     end
  #   end
  # # end


=begin
  get '/checkout/paybox_pay', :to => 'checkout#paybox_pay', :as => :paybox_pay
  get '/checkout/paybox_paid', :to => 'checkout#paybox_paid', :as => :paybox_paid
  get '/checkout/paybox_refused', :to => 'checkout#paybox_refused', :as => :paybox_refused
  get '/checkout/paybox_cancelled', :to => 'checkout#paybox_cancelled', :as => :paybox_cancelled
=end

  get '/paybox/paybox_pay', :to => 'paybox_callbacks#paybox_pay', :as => :paybox_pay
  match '/paybox/ipn' => "paybox_callbacks#ipn", :via => :get, :as => :paybox_ipn
  match '/paybox/ipn_n_times' => "paybox_callbacks#ipn_n_times", :via => :get, :as => :paybox_ipn_n_times

  namespace :admin do
    resource :paybox_system_gateway_settings
  end
end
