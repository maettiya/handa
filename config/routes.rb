Rails.application.routes.draw do
  devise_for :users

  # Projects
  # Create: Upload new project (ZIP or single file)
  # Show: View extracted contents of a project (Look inside)
  # Destroy: Delete a project (and it's contents)
  # Download: Download the original uploaded file
  resources :projects, only: [:create, :show, :destroy] do
    member do
      get :download
    end
  end

  # Library - main dashboard showing all user's files
  get 'library/index'
  root "library#index"

  # Health Status
  get "up" => "rails/health#show", as: :rails_health_check

end
