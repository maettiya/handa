# CLAUDE.md - Handa Project Guide

## Project Overview

**Handa** is a Ruby on Rails application designed as a "GitHub for music files" - a seamless storage and collaboration platform for music creators. It consolidates the workflow of sharing music projects into a single platform with automatic file extraction, preview creation, and flexible sharing.

**Current Status**: Early development - Core upload/download/extraction and project browsing functionality is working. Many planned features not yet built.

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
│   ├── library_controller.rb          # index - main dashboard
│   ├── projects_controller.rb         # create, show, download, destroy, download_file, download_folder, destroy_file, upload_files
│   ├── share_links_controller.rb      # create, destroy, show, download, verify_password - public share links
│   ├── profile_controller.rb          # show, edit, update - user profile page
│   ├── collaborators_controller.rb    # index, create, destroy, search - manage collaborators
│   └── notifications_controller.rb    # mark_read - notification management
├── helpers/
│   └── file_icon_helper.rb            # Icon selection for projects and files
├── jobs/
│   └── project_extraction_job.rb      # Background ZIP extraction
├── models/
│   ├── user.rb                        # Devise user, has_many :projects, :collaborations, :notifications
│   ├── project.rb                     # Uploaded music project (ZIP/file)
│   ├── project_file.rb                # Extracted files with tree structure
│   ├── collaboration.rb               # User-to-user collaboration relationship
│   ├── notification.rb                # User notifications (collaborator_added, etc.)
│   └── share_link.rb                  # Shareable links with optional password/expiry
├── services/
│   └── project_extraction_service.rb  # ZIP extraction logic
├── views/
│   ├── layouts/application.html.erb   # Dark theme layout with header + notification dropdown
│   ├── library/index.html.erb         # Main library grid view
│   ├── projects/
│   │   ├── show.html.erb              # Project file browser view
│   │   └── _breadcrumbs.html.erb      # File path navigation partial
│   ├── profile/                       # User profile views
│   ├── collaborators/                 # Collaborator management views
│   ├── share_links/                   # Public share page views (show, expired, not_found)
│   └── devise/                        # Auth forms
└── javascript/
    ├── application.js                  # Entry point
    ├── upload.js                       # Drag-drop, file picker, progress bar (library page)
    └── controllers/
        ├── dropdown_controller.js              # Three-dot menu toggle with submenu support
        ├── notification_dropdown_controller.js # Notification bell dropdown + mark as read
        ├── collaborator_search_controller.js   # Autocomplete search for adding collaborators
        ├── share_controller.js                 # Share link modal (create link, copy URL)
        └── project_upload_controller.js        # File uploads within projects (drag-drop + picker)
```

## Key Models & Relationships

```
User
├── has_many :projects, dependent: :destroy
├── has_many :collaborations, dependent: :destroy
├── has_many :inverse_collaborations (as collaborator)
├── has_many :notifications
├── has_one_attached :avatar
├── validates: username (required, unique)
├── methods: collaborators, collaborators_count, daw_projects_count, total_storage_used, storage_breakdown

Project
├── belongs_to :user
├── has_many :project_files, dependent: :destroy
├── has_many :share_links, dependent: :destroy
├── has_one_attached :file (original ZIP)
├── fields: title, project_type (ableton/logic/folder), extracted
├── validates: title presence, file presence

ProjectFile (tree structure for extracted files)
├── belongs_to :project
├── belongs_to :parent (optional, self-referential)
├── has_many :children
├── has_one_attached :file
├── fields: original_filename, path, file_size, is_directory, hidden, file_type
├── scopes: visible, directories, files, root_level
├── methods: extension, icon_type, should_hide?

Collaboration
├── belongs_to :user (the person who added the collaborator)
├── belongs_to :collaborator (User)
├── Represents a mutual collaboration relationship between users

Notification
├── belongs_to :user (recipient)
├── belongs_to :actor (User who triggered notification)
├── belongs_to :notifiable (polymorphic, optional - for linking to projects)
├── fields: notification_type, read (boolean)
├── scopes: unread, recent
├── Types: 'collaborator_added'

ShareLink
├── belongs_to :project
├── has_secure_password (optional - for password-protected links)
├── fields: token, expires_at, download_count, password_digest
├── methods: expired?, password_required?
├── Token auto-generated on create (SecureRandom.urlsafe_base64)
```

## Routes

```ruby
devise_for :users                       # Auth routes

resources :projects, only: [:create, :show, :destroy] do
  collection do
    post :create_folder
  end
  member do
    get :download                                      # Download original file
    get 'download_file/:file_id', to: :download_file   # Download single file
    get 'download_folder/:folder_id', to: :download_folder  # Download folder as ZIP
    delete 'delete_file/:file_id', to: :destroy_file   # Delete file or folder
    post :duplicate                                    # Duplicate a project
    patch :rename                                      # Rename a project
    post :create_subfolder                             # Create folder inside project
    post :upload_files                                 # Upload files to existing project
  end
  resources :share_links, only: [:create, :destroy]    # Nested share link management
end

# Public share link routes (no auth required)
get 's/:token', to: 'share_links#show'                 # View shared project
get 's/:token/download', to: 'share_links#download'    # Download shared project
post 's/:token/verify', to: 'share_links#verify_password'  # Verify password

resource :profile, only: [:show, :edit, :update]       # User profile

resources :collaborators, only: [:index, :create, :destroy] do
  collection do
    get :search                                        # Autocomplete search for users
  end
end

resources :notifications, only: [] do
  collection do
    post :mark_read                                    # Mark all notifications as read
  end
end

get 'library/index'
root "library#index"                    # Main library page
```

## Common Development Tasks

### Running the Application
```bash
bin/rails server           # Start Rails server
bin/dev                    # Start with foreman (if Procfile.dev exists)
```

### Database
```bash
bin/rails db:migrate       # Run migrations
bin/rails db:reset         # Drop, create, migrate, seed
```

### Building Assets
```bash
yarn build                 # Bundle JavaScript with esbuild
yarn build:css             # Build Tailwind CSS
```

## Key Files to Know

| Purpose | File |
|---------|------|
| ZIP extraction logic | `app/services/project_extraction_service.rb` |
| Background extraction | `app/jobs/project_extraction_job.rb` |
| File hiding rules | `app/models/project_file.rb` (HIDDEN_EXTENSIONS, HIDDEN_FOLDERS) |
| File icon selection | `app/helpers/file_icon_helper.rb` |
| Upload UI/UX + progress (library) | `app/javascript/upload.js` |
| Upload within projects | `app/javascript/controllers/project_upload_controller.js` |
| Dropdown menus | `app/javascript/controllers/dropdown_controller.js` |
| Share link modal | `app/javascript/controllers/share_controller.js` |
| Notification dropdown | `app/javascript/controllers/notification_dropdown_controller.js` |
| Collaborator search | `app/javascript/controllers/collaborator_search_controller.js` |
| Library view | `app/views/library/index.html.erb` |
| Project browser | `app/views/projects/show.html.erb` |
| Breadcrumb navigation | `app/views/projects/_breadcrumbs.html.erb` |
| Styling | `app/assets/stylesheets/application.tailwind.css` |
| Routes | `config/routes.rb` |
| Storage config | `config/storage.yml` |
| Database schema | `db/schema.rb` |

## ProjectFile Hidden File Logic

Files are auto-hidden during extraction:
- **Extensions**: `.asd`, `.ds_store`
- **Folders**: `Ableton Project Info`, `__MACOSX`
- **Patterns**: Files starting with `.` or `Icon`

See `ProjectFile.should_hide?(filename, is_directory:)` for implementation.

## FileIconHelper

Provides icon selection for visual file type display:
- `project_icon_for(project)` - Icon for library view (checks project_type first, then file extension)
- `file_icon_for(project_file)` - Icon for extracted files within project browser

Supported file types:
- **DAW Projects**: Ableton (.als), Logic (.logicx)
- **Lossless Audio**: WAV, AIF, AIFF, FLAC
- **Compressed Audio**: MP3, M4A, AAC
- **Folders**: Directory icon
- **Fallback**: Generic file icon

## What's Implemented

- User authentication (sign up, login, logout, password reset)
- Project upload with drag-drop and file picker
- Upload progress bar with percentage display
- ZIP file extraction with tree structure preservation
- Background job extraction (avoids Heroku 30s timeout)
- Project type auto-detection (Ableton/Logic/Folder)
- Original project download
- Individual file download
- Folder download as ZIP (in-memory ZIP creation)
- Project deletion
- Individual file/folder deletion (with cascade for folders)
- Project duplication
- Project renaming
- Folder creation (top-level and inside projects)
- Library grid view with three-dot menus
- Project file browser with subfolder navigation
- Breadcrumb navigation in project browser
- File type icons throughout UI
- Dark theme UI
- Cloud storage (Cloudflare R2 in production)
- **User Profile**: Avatar upload, username/email/password editing, storage usage display
- **Collaborators**: Add/remove collaborators with autocomplete search, mutual relationship
- **Notifications**: Bell icon with unread count badge, dropdown showing recent activity, auto mark-as-read on open
  - Currently supports: `collaborator_added` notification type
  - Polymorphic `notifiable` ready for future notification types (e.g., file shared, project downloaded)
- **Share Links**: Create shareable URLs for projects with optional password protection and expiry
  - Public URLs at `/s/:token` (no login required)
  - Password protection with session-based verification
  - Expiry options: 1 hour, 24 hours, 7 days, 30 days, or never
  - Download tracking (download_count field)
- **File uploads within projects**: Drag & drop or file picker to add files to existing projects/folders

## What's NOT Implemented Yet

- **Search** (icon in UI, no logic)
- **Audio previews/waveforms**
- **Payment integration**

## Architecture Notes

1. **Active Storage**: Used for both original project files AND individual extracted files
2. **Service Objects**: Business logic in `app/services/` (e.g., ProjectExtractionService)
3. **Background Jobs**: ProjectExtractionJob handles ZIP extraction asynchronously
4. **Self-referential association**: ProjectFile uses `parent_id` for folder tree structure
5. **Helper modules**: FileIconHelper for icon selection logic, included in views
6. **Stimulus Controllers**:
   - `DropdownController` - Three-dot menu toggle with submenu support (CSS bridge for hover stability)
   - `NotificationDropdownController` - Bell icon dropdown with AJAX mark-as-read
   - `CollaboratorSearchController` - Autocomplete search with avatar display
   - `ShareController` - Share link modal (create, display URL, copy to clipboard)
   - `ProjectUploadController` - File uploads within projects (Direct Upload to R2)
7. **Cloud Storage**: Cloudflare R2 (S3-compatible) configured with special checksum settings
8. **Polymorphic associations**: Notification `notifiable` allows linking to any model (future: projects, files)

## Controller Actions

### ProjectsController
- `show` - View project contents, supports subfolder navigation via `folder_id` param
- `create` - Upload new project, triggers background extraction job
- `download` - Download original file, or ZIP of contents, or empty ZIP for folders
- `download_file` - Download individual extracted file with original filename
- `download_folder` - Download folder as in-memory ZIP file
- `destroy` - Delete entire project and all extracted files
- `destroy_file` - Delete individual file or folder (cascades to children)
- `upload_files` - Upload files to existing project (handles Direct Upload signed blobs)

### ShareLinksController
- `create` - Create new share link (nested under project, requires auth)
- `destroy` - Delete a share link
- `show` - Public page to view/download shared project (no auth, renders expired/not_found views)
- `download` - Download shared project (checks password if required)
- `verify_password` - AJAX endpoint to verify password, stores in session

### LibraryController
- `index` - Main dashboard (empty action, view renders user's projects)

### ProfileController
- `show` - User profile page with stats, avatar, storage breakdown
- `edit` - Edit individual fields (username, email, password)
- `update` - Save profile changes, handle avatar upload

### CollaboratorsController
- `index` - List all collaborators
- `create` - Add a collaborator (creates notification for them)
- `destroy` - Remove a collaborator
- `search` - JSON endpoint for autocomplete (returns id, username, avatar_url)

### NotificationsController
- `mark_read` - Mark all user's notifications as read (AJAX)

## Storage Configuration

```yaml
# config/storage.yml
local:
  service: Disk
  root: storage/

cloudflare:
  service: S3
  endpoint: https://<account>.r2.cloudflarestorage.com
  access_key_id: <%= ENV['CLOUDFLARE_ACCESS_KEY_ID'] %>
  secret_access_key: <%= ENV['CLOUDFLARE_SECRET_ACCESS_KEY'] %>
  bucket: <%= ENV['CLOUDFLARE_BUCKET'] %>
  region: auto
  force_path_style: true
  request_checksum_calculation: when_required
  response_checksum_validation: when_required
```

- **Development**: Uses local disk storage
- **Production**: Uses Cloudflare R2 (S3-compatible)

## Testing

Test framework is Minitest but **no tests have been written yet**. Test files exist as empty stubs in `test/`.

## Known Issues / Technical Debt

1. Devise mailer not configured for password resets
2. Zero test coverage
3. No error handling UI for failed extractions
