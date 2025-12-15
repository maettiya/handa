Rails.application.routes.draw do
  devise_for :users

  # Projects
  resources :projects, only: [:create, :destroy] do
    member do
      get :download
    end
  end

  # Library
  get 'library/index'
  root "library#index"

  # Health Status
  get "up" => "rails/health#show", as: :rails_health_check

end
