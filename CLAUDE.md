# CLAUDE.md - Handa Project Guide

## Project Overview

**Handa** is a Ruby on Rails application designed as a "GitHub for music files" - a seamless storage and collaboration platform for music creators. It consolidates the workflow of sharing music projects into a single platform with automatic file extraction, preview creation, and flexible sharing.

**Current Status**: Core functionality complete - Upload, download, extraction, browsing, search, sharing, and audio playback all working. Landing page live.

## Tech Stack

- **Framework**: Ruby on Rails 7.1.6
- **Ruby Version**: 3.3.5
- **Database**: PostgreSQL
- **Authentication**: Devise
- **Frontend**: Hotwire (Turbo + Stimulus), Tailwind CSS v4
- **File Storage**: Active Storage (local dev, Cloudflare R2 in production)
- **JavaScript Bundler**: esbuild
- **Key Gems**: `devise`, `rubyzip`, `aws-sdk-s3`, `pg`, `turbo-rails`, `stimulus-rails`

## Project Structure

```
app/
├── controllers/
│   ├── application_controller.rb      # Devise auth, requires login for all pages
│   ├── pages_controller.rb            # Landing page (public)
│   ├── library_controller.rb          # index, move_asset - main dashboard
│   ├── assets_controller.rb           # CRUD for assets (files/folders)
│   ├── search_controller.rb           # Search with filters (bpm, key, title)
│   ├── share_links_controller.rb      # Public share links + save to library
│   ├── quick_shares_controller.rb     # Ephemeral quick shares
│   ├── profile_controller.rb          # User profile page
│   ├── collaborators_controller.rb    # Manage collaborators
│   └── notifications_controller.rb    # Notification management
├── helpers/
│   └── file_icon_helper.rb            # Icon selection for assets
├── jobs/
│   └── asset_extraction_job.rb        # Background ZIP extraction
├── models/
│   ├── user.rb                        # Devise user, has_many :assets
│   ├── asset.rb                       # Unified model for files/folders
│   ├── collaboration.rb               # User-to-user collaboration
│   ├── notification.rb                # User notifications
│   └── share_link.rb                  # Shareable links with password/expiry
├── services/
│   └── asset_extraction_service.rb    # ZIP extraction logic
├── views/
│   ├── layouts/
│   │   ├── application.html.erb       # Main app layout (dark theme)
│   │   └── landing.html.erb           # Landing page layout (no nav)
│   ├── pages/landing.html.erb         # Public landing page
│   ├── library/index.html.erb         # Main library grid view
│   ├── assets/
│   │   ├── show.html.erb              # Asset browser view
│   │   └── _breadcrumbs.html.erb      # Breadcrumb navigation
│   ├── search/index.html.erb          # Search results with filters
│   ├── quick_shares/index.html.erb    # Quick share management
│   ├── profile/                       # User profile views
│   ├── share_links/                   # Public share page views
│   └── devise/                        # Auth forms
└── javascript/
    ├── application.js                 # Entry point
    ├── upload.js                      # Library upload (drag-drop + progress)
    └── controllers/
        ├── dropdown_controller.js              # Three-dot menu toggle
        ├── notification_dropdown_controller.js # Notification bell dropdown
        ├── collaborator_search_controller.js   # Autocomplete user search
        ├── share_controller.js                 # Share link modal
        ├── quick_share_controller.js           # Quick share upload
        ├── asset_upload_controller.js          # Upload within assets
        ├── file_drag_controller.js             # Drag & drop file moving
        ├── audio_player_controller.js          # Audio playback + waveform
        ├── search_filters_controller.js        # Search filter controls
        ├── rename_controller.js                # Inline rename modal
        └── access_controller.js                # Share link password modal
```

## Key Models & Relationships

```
User
├── has_many :assets, dependent: :destroy
├── has_many :collaborations, dependent: :destroy
├── has_many :inverse_collaborations (as collaborator)
├── has_many :notifications
├── has_one_attached :avatar
├── validates: username (required, unique)
├── methods: collaborators, daw_projects_count, total_storage_used, storage_breakdown

Asset (unified model - replaces Project/ProjectFile)
├── belongs_to :user
├── belongs_to :parent (self-referential, optional)
├── belongs_to :shared_from_user (optional, for saved shares)
├── has_many :children, dependent: :destroy
├── has_many :share_links, dependent: :destroy
├── has_one_attached :file
├── fields: title, original_filename, path, file_size, is_directory, hidden,
│           file_type, asset_type, extracted, ephemeral, shared_from_user_id
├── scopes: root_level, library, ephemeral_shares, visible, directories, files
├── methods: extension, all_descendants, should_hide?

ShareLink
├── belongs_to :asset
├── has_secure_password (optional)
├── fields: token, expires_at, download_count, password_digest
├── methods: expired?, password_required?

Collaboration
├── belongs_to :user
├── belongs_to :collaborator (User)

Notification
├── belongs_to :user (recipient)
├── belongs_to :actor (User)
├── belongs_to :notifiable (polymorphic, optional)
├── fields: notification_type, read
├── Types: 'collaborator_added'
```

## Routes

```ruby
devise_for :users

# Root - Landing page (public)
root "pages#landing"

# Assets (path: /items to avoid Rails asset pipeline conflict)
resources :assets, path: 'items', only: [:create, :show, :destroy] do
  collection do
    post :create_folder
  end
  member do
    get :download
    get 'download_file/:file_id', to: :download_file
    get 'download_folder/:folder_id', to: :download_folder
    delete 'delete_file/:file_id', to: :destroy_file
    patch 'rename_file/:file_id', to: :rename_file
    post :duplicate
    patch :rename
    post :create_subfolder
    post :upload_files
    post :move_file
  end
  resources :share_links, only: [:create, :destroy]
end

# Public share links
get 's/:token', to: 'share_links#show'
get 's/:token/download', to: 'share_links#download'
post 's/:token/verify', to: 'share_links#verify_password'
post 's/:token/save', to: 'share_links#save_to_library'

# Quick shares (ephemeral)
get 'share', to: 'quick_shares#index'
post 'share', to: 'quick_shares#create'
delete 'share/:id', to: 'quick_shares#destroy'

# Library
get 'library/index'
post 'library/move_asset', to: 'library#move_asset'

# Search
get 'search', to: 'search#index'

# Profile, Collaborators, Notifications
resource :profile, only: [:show, :edit, :update]
resources :collaborators, only: [:index, :create, :destroy] do
  collection { get :search }
end
resources :notifications, only: [] do
  collection { post :mark_read }
end
```

## Key Files to Know

| Purpose | File |
|---------|------|
| Asset model | `app/models/asset.rb` |
| Asset controller | `app/controllers/assets_controller.rb` |
| ZIP extraction | `app/services/asset_extraction_service.rb` |
| Background extraction | `app/jobs/asset_extraction_job.rb` |
| File icon selection | `app/helpers/file_icon_helper.rb` |
| Library upload | `app/javascript/upload.js` |
| Asset upload | `app/javascript/controllers/asset_upload_controller.js` |
| File drag/drop | `app/javascript/controllers/file_drag_controller.js` |
| Audio player | `app/javascript/controllers/audio_player_controller.js` |
| Search filters | `app/javascript/controllers/search_filters_controller.js` |
| Landing page | `app/views/pages/landing.html.erb` |
| Landing CSS | `app/assets/stylesheets/landing.css` |
| Library view | `app/views/library/index.html.erb` |
| Asset browser | `app/views/assets/show.html.erb` |
| Search page | `app/views/search/index.html.erb` |
| Main styling | `app/assets/stylesheets/application.tailwind.css` |

## Asset Model Architecture

Everything is a unified **Asset** model with self-referential tree structure:

```
User's Library (parent_id: NULL, ephemeral: false)
├── 🎵 Track.wav                    ← Asset (is_directory: false)
├── 📁 My Folder                    ← Asset (is_directory: true, asset_type: "folder")
│   └── 🎵 beat.wav                 ← Asset (parent_id: folder.id)
├── 🔶 SERENADE Project             ← Asset (is_directory: true, asset_type: "ableton", extracted: true)
│   ├── 🔶 SERENADE.als             ← Child asset
│   └── 📁 Samples                  ← Child folder
│       └── 🎵 kick.wav             ← Grandchild asset

Quick Shares (parent_id: NULL, ephemeral: true)
└── 🎵 demo.mp3                     ← Ephemeral asset with auto ShareLink
```

### Asset Types
- `ableton` - Ableton Live project (.als detected)
- `logic` - Logic Pro project (.logicx detected)
- `fl_studio` - FL Studio project (.flp detected)
- `lossless_audio` - WAV, AIF, FLAC
- `compressed_audio` - MP3, M4A, AAC
- `folder` - User-created folder

See `docs/ASSET_ARCHITECTURE.md` for full documentation.

## What's Implemented

### Core Features
- User authentication (Devise)
- Asset upload with drag-drop and progress bar
- ZIP file extraction with tree structure
- Background job extraction (async)
- Asset type auto-detection (Ableton/Logic/FL Studio)
- File/folder download (individual or as ZIP)
- Asset deletion, duplication, renaming
- Folder creation (root level and nested)
- Library grid view with three-dot menus
- Asset browser with subfolder navigation
- Breadcrumb navigation
- File type icons throughout UI
- Dark theme UI

### Search
- Full search with BPM, key, and title filters
- Key detection from filename (e.g., "Track_Cmaj_120bpm.wav")
- BPM detection from filename
- Filter by exact or range BPM
- Musical key dropdown with all keys

### Sharing
- **Share Links**: Password protection, expiry, download tracking
- **Quick Shares**: Ephemeral uploads with auto-generated share link
- **Save to Library**: Recipients can save shared files to their own library
- Public share pages at `/s/:token`

### Audio Player
- Persistent audio player bar (bottom of screen)
- Waveform visualization (WaveSurfer.js)
- Play/pause, restart, volume control
- Survives Turbo navigation (turbo-permanent)
- Click any audio file to play

### Profile
- Avatar upload
- Username/email/password editing
- Storage usage display with breakdown bar
- Category breakdown (DAW projects, audio, other)

### Landing Page
- Public landing page at root URL
- Separate layout (no app header)
- Typing animation hero text
- Screenshot showcases
- Screen recording video
- Redirects to library if logged in

### Other
- Collaborators management
- Notifications with unread badge
- Drag & drop file organization

## What's NOT Implemented Yet

- Audio previews/waveforms in file browser (player works, but no inline previews)
- Payment integration
- Real-time collaboration

## Common Development Tasks

```bash
# Run server
bin/rails server
bin/dev                    # With foreman

# Database
bin/rails db:migrate
bin/rails db:reset

# Assets
yarn build                 # JavaScript
yarn build:css             # Tailwind CSS
```

## Storage Configuration

```yaml
# Development: Local disk
# Production: Cloudflare R2 (S3-compatible)
```

## Technical Debt / Known Issues

1. Legacy `projects` and `project_files` tables still in database (can be dropped)
2. Devise mailer not configured for password resets
3. Zero test coverage
4. No error handling UI for failed extractions
