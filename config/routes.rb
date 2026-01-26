Rails.application.routes.draw do
  devise_for :users

  # Library items (files and folders)
  # Using 'items' path to avoid conflict with Rails asset pipeline (/assets)
  # Create: Upload new asset (ZIP or single file)
  # Show: View contents of an asset (browse children)
  # Destroy: Delete an asset (and its children)
  # Download: Download the original uploaded file
  resources :assets, path: 'items', only: [:create, :show, :destroy] do
    collection do
      post :create_folder
    end

    member do
      get :status
      # Downloads the original file
      get :download
      # Downloads an individual child file
      get 'download_file/:file_id', to: 'assets#download_file', as: :download_file
      # Downloads an individual folder
      get 'download_folder/:folder_id', to: 'assets#download_folder', as: :download_folder
      # Deletes an individual file or folder
      delete 'delete_file/:file_id', to: 'assets#destroy_file', as: :destroy_file
      # Rename an individual file or folder
      patch 'rename_file/:file_id', to: 'assets#rename_file', as: :rename_file
      # Duplicate an asset
      post :duplicate
      # Rename an asset
      patch :rename
      # Create a folder inside an asset
      post :create_subfolder
      # Upload files to an asset
      post :upload_files
      # Move files
      post :move_file
    end

    # Nested share links (for creating)
    resources :share_links, only: [:create, :destroy]
  end

  # Public share link routes (short URLs)
  get 's/:token', to: 'share_links#show', as: :share_link
  get 's/:token/download', to: 'share_links#download', as: :share_link_download
  post 's/:token/verify', to: 'share_links#verify_password', as: :share_link_verify

  # Quick share routes
  get 'share', to: 'quick_shares#index', as: :quick_shares
  post 'share', to: 'quick_shares#create'
  delete 'share/:id', to: 'quick_shares#destroy', as: :quick_share

  # Save shared asset to library
  post 's/:token/save', to: 'share_links#save_to_library', as: :share_link_save

  # Library - main dashboard showing all user's files
  get 'library/index'
  post 'library/move_asset', to: 'library#move_asset', as: :library_move_asset
  root "pages#landing"

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

  # Downloads
  resources :downloads, only: [:create] do
    member do
      get :status
      get :file
    end
    collection do
      get :active
    end
  end

  # Search
  get 'search', to: 'search#index', as: :search

  # Health Status
  get 'up' => 'rails/health#show', as: :rails_health_check

end
