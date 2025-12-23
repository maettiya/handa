Rails.application.routes.draw do
  devise_for :users

  # Projects
  # Create: Upload new project (ZIP or single file)
  # Show: View extracted contents of a project (Look inside)
  # Destroy: Delete a project (and it's contents)
  # Download: Download the original uploaded file

  resources :projects, only: [:create, :show, :destroy] do
    member do
      # Downloads the original ZIP file
      get :download
      # Downloads an individual file
      get 'download_file/:file_id', to: 'projects#download_file', as: :download_file
      # Downloads an individual folder
      get 'download_folder/:folder_id', to: 'projects#download_folder', as: :download_folder
      # Deletes an individual file or folder
      delete 'delete_file/:file_id', to: 'projects#destroy_file', as: :destroy_file
    end
  end

  # Library - main dashboard showing all user's files
  get 'library/index'
  root "library#index"

  # Health Status
  get "up" => "rails/health#show", as: :rails_health_check

end
