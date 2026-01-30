# CLAUDE.md - Handa Project Guide

## Project Overview

**Handa** is a Ruby on Rails application designed as a "GitHub for music files" - a seamless storage and collaboration platform for music creators. It consolidates the workflow of sharing music projects into a single platform with automatic file extraction, preview creation, and flexible sharing.

**Current Status**: Core functionality complete - Upload, download, extraction, browsing, search, sharing, and audio playback all working. Landing page live.

---

## Product Vision

**The Ultimate Goal**: Handa is not "Dropbox for music" - it's the **missing infrastructure for seamless remote music collaboration**.

### The Dream Workflow

1. Producer opens Ableton and starts a song
2. Clicks "Save As" → saves directly to Handa folder
3. Auto-syncs to Handa cloud instantly
4. Creates share link, sends to collaborator via iMessage
5. Collaborator clicks "Save to Library"
6. The EXACT project appears in their Handa
7. They open Ableton → everything is there, ready to continue

**No exporting stems. No manual ZIP. No uploading/downloading. No "Collect All and Save" issues. No missing samples. Just ONE link - Handa handles the rest.**

### Two-Product Architecture

**Browser Handa** (Current Focus)
- The "home base" where all music files live
- Beautiful, organized library (not generic like Dropbox)
- Share links, collaborator management, version history
- Audio playback, comments, project overview
- Works without any DAW or native app installed

**Native Handa** (Future - macOS App)
- The invisible sync engine
- Watches a "Handa Projects" folder
- Detects saves via FSEvents
- Packages project + samples correctly (solves "Collect All and Save")
- Uploads to Handa cloud instantly
- Pushes notifications to collaborators
- Downloads and unpacks on their end automatically

### Fast Iteration Sync

When both collaborators have a project open:
1. One producer saves
2. Handa detects the save instantly
3. Syncs to cloud
4. Collaborator gets notification: "New version available - reload?"
5. They click reload → Ableton loads the updated project

This isn't Google Docs-level real-time, but it's **dramatically faster** than the current export→upload→download→import loop.

### Why This Matters

Every producer collaborates remotely. The current workflow is painful:
- Create → Export → Upload → Send link → Download → Import → Repeat

Handa collapses this into:
- Create → It's there

The browser version we're building now is the foundation. The API, storage, user accounts, share links, collaborator system - all gets reused by the native app. Current work isn't throwaway; it's building toward this vision.

---

## Tech Stack

- **Framework**: Ruby on Rails 7.1.6
- **Ruby Version**: 3.3.5
- **Database**: PostgreSQL
- **Authentication**: Devise
- **Frontend**: Hotwire (Turbo + Stimulus), Tailwind CSS v4
- **File Storage**: Active Storage (local dev, Cloudflare R2 in production)
- **JavaScript Bundler**: esbuild
- **Key Gems**: `devise`, `rubyzip`, `zipline`, `aws-sdk-s3`, `pg`, `turbo-rails`, `stimulus-rails`

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
│   ├── notifications_controller.rb    # Notification management
│   ├── downloads_controller.rb        # Streaming ZIP downloads
│   └── direct_shares_controller.rb    # Share directly with collaborators
├── helpers/
│   └── file_icon_helper.rb            # Icon selection for assets
├── jobs/
│   ├── asset_extraction_job.rb        # Background ZIP extraction
│   ├── save_to_library_job.rb         # Clone shared assets to user's library
│   └── create_zip_job.rb              # Background ZIP creation (legacy)
├── models/
│   ├── user.rb                        # Devise user, has_many :assets
│   ├── asset.rb                       # Unified model for files/folders
│   ├── collaboration.rb               # User-to-user collaboration
│   ├── notification.rb                # User notifications
│   ├── share_link.rb                  # Shareable links with password/expiry
│   └── download.rb                    # Track download progress/status
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
        ├── access_controller.js                # Share link password modal
        └── download_status_controller.js       # Download progress tracking
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
├── has_many :downloads, dependent: :destroy
├── has_one_attached :file
├── fields: title, original_filename, path, file_size, is_directory, hidden,
│           file_type, asset_type, extracted, ephemeral, shared_from_user_id,
│           processing_status, processing_progress, processing_total
├── scopes: root_level, library, ephemeral_shares, visible, directories, files
├── methods: extension, root_asset, deep_clone_to_user, should_hide?

ShareLink
├── belongs_to :asset
├── has_many :downloads, dependent: :destroy
├── has_secure_password (optional)
├── fields: token, expires_at, download_count, password_digest
├── methods: expired?, password_required?

Download
├── belongs_to :user (optional - nil for anonymous)
├── belongs_to :asset
├── belongs_to :share_link (optional)
├── has_one_attached :zip_file
├── fields: status, progress, total, filename, error_message
├── States: pending → processing → ready → downloaded → failed
├── scopes: active

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

# Downloads (streaming ZIP)
resources :downloads, only: [:create, :destroy] do
  member { get :status; get :file }
  collection { get :active; get :stream }
end

# Direct shares (share with collaborators)
resources :direct_shares, only: [:create] do
  collection { get :frequent_recipients }
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
| Share links controller | `app/controllers/share_links_controller.rb` |
| Downloads controller | `app/controllers/downloads_controller.rb` |
| Save to library job | `app/jobs/save_to_library_job.rb` |
| Download status JS | `app/javascript/controllers/download_status_controller.js` |

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
- `garageband` - GarageBand project (.band detected)
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
- **Save to Library**: Instant clone using blob references (no file re-upload)
- **Direct Shares**: Share directly with collaborators (sends notification)
- Public share pages at `/s/:token`

### Downloads
- **Streaming ZIP downloads**: Uses `zipline` gem to stream directly from R2
- **Single file downloads**: Redirects directly to R2 signed URL
- **Folder downloads**: Streams ZIP on-the-fly (no timeout issues)
- **Anonymous downloads**: Session-based tracking for share link downloads

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

1. Legacy `projects` and `project_files` tables still in database (can be dropped when confident)
2. Zero test coverage
3. No error handling UI for failed extractions

---

## Architecture Notes

### Streaming Downloads (Zipline)

Downloads use the `zipline` gem to stream ZIPs directly from R2 to the browser:

```
User clicks Download → DownloadsController#stream → Zipline streams from R2 → Browser
```

- **Single files**: Redirect directly to R2 signed URL (instant)
- **Folders**: Stream ZIP on-the-fly using zipline (no server memory/timeout issues)
- **No background jobs**: Files stream directly, avoiding Heroku's 30s timeout

Key file: `app/controllers/downloads_controller.rb`

### Reference-Based Save to Library

When a user saves a shared asset to their library, we use **blob references** instead of re-downloading/re-uploading files:

```ruby
# OLD (slow) - downloaded and re-uploaded every file
cloned.file.attach(
  io: StringIO.new(file.download),
  filename: file.filename.to_s,
  content_type: file.content_type
)

# NEW (instant) - just references the same blob
cloned.file.attach(file.blob)
```

**How it works:**
- Active Storage blobs are reference-counted
- Multiple Asset records can point to the same blob
- Blob is only deleted when ALL references are removed
- User A deletes → User B's copy unaffected (and vice versa)

Key files: `app/models/asset.rb` (`deep_clone_to_user`), `app/jobs/save_to_library_job.rb`

### Direct Uploads

File uploads go directly from browser to R2, bypassing Rails:

```
Browser → R2 (direct) → Rails receives blob key
```

Uses Active Storage's `direct_upload: true` option. No server-side file handling for uploads.

---

## Upcoming Features To-Do

### 1. Enhanced Notifications

**Goal**: Rich activity tracking and clickable notifications.

- **"User listened to X"** - Notify when someone plays your shared audio
- **"User listened to X for 13 seconds"** - Include listen duration
- **"User opened X"** - Know when someone accessed your share link (even before listen/download)
- **Clickable notifications** - Click "Someone listened to SERENADE [79bpm]" to jump to that file

### 2. Real-time Collaboration

**Goal**: Allow multiple users to collaborate on the same project in real-time.

**Difference from Save to Library:**
- **Save to Library**: Creates independent copy (blob references, but separate Asset records)
- **Collaborate**: Shared access to the SAME Asset record (both users see same version)

### 3. Native macOS App

**Goal**: Invisible sync engine that watches a "Handa Projects" folder.

- Detects saves via FSEvents
- Packages project + samples correctly
- Uploads to Handa cloud instantly
- Delta sync (only upload changed bytes)

### 4. Version History

**Goal**: Track versions of files over time, allow rollback.

---

### Bottom Bar Layout (Current)

```
┌────────────────────────────────────────────────────────────────────────┐
│ [Download Status]        [Audio Player]              [Upload Status]   │
│   (left)                   (center)                    (right)         │
└────────────────────────────────────────────────────────────────────────┘
```

- **Left**: Download progress/ready status (turbo-permanent)
- **Center**: Audio player (existing, turbo-permanent)
- **Right**: Upload progress (existing functionality)
