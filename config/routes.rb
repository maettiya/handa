Rails.application.routes.draw do
  devise_for :users

  # Projects
  # Create: Upload new project (ZIP or single file)
  # Show: View extracted contents of a project (Look inside)
  # Destroy: Delete a project (and it's contents)
  # Download: Download the original uploaded file
  resources :projects, only: [:create, :show, :destroy] do
    collection do
      post :create_folder
    end

    member do
      # Downloads the original ZIP file
      get :download
      # Downloads an individual file
      get 'download_file/:file_id', to: 'projects#download_file', as: :download_file
      # Downloads an individual folder
      get 'download_folder/:folder_id', to: 'projects#download_folder', as: :download_folder
      # Deletes an individual file or folder
      delete 'delete_file/:file_id', to: 'projects#destroy_file', as: :destroy_file
      # Duplicate a project
      post :duplicate
      # Rename a project
      patch :rename
      # Create a folder inside a project
      post :create_subfolder
    end

    # Nested share links (for creating)
    resources :share_links, only: [:create, :destroy]
  end

  # Public share link routes (short URLs)
  get 's/:token', to: 'share_links#show', as: :share_link
  get 's/:token/download', to: 'share_links#download', as: :share_link_download
  post 's/:token/verify', to: 'share_links#verify_password', as: :share_link_verify

  # Library - main dashboard showing all user's files
  get 'library/index'
  root "library#index"

  # Profile - user profile dashboard
  resource :profile, only: [:show, :edit, :update], controller: 'profile'

  # Collaborators
  resources :collaborators, only: [:index, :create, :destroy] do
    collection do
      get :search
    end
  end

  # Notifications
  resources :notifications, only: [] do
    collection do
      post :mark_read
    end
  end

  # Search
  get 'search', to: 'search#index', as: :search

  # Health Status
  get 'up' => 'rails/health#show', as: :rails_health_check

end
