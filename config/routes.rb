Rails.application.routes.draw do
  devise_for :users

  # Projects
  resources :projects, only: [:create, :destroy]

  # Library
  get 'library/index'
  root "library#index"

  # Health Status
  get "up" => "rails/health#show", as: :rails_health_check

end
