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
- **File Storage**: Active Storage (local, production should use S3/GCP)
- **JavaScript Bundler**: esbuild
- **Key Gems**: `devise`, `rubyzip`, `pg`, `turbo-rails`, `stimulus-rails`

## Project Structure

```
app/
├── controllers/
│   ├── application_controller.rb    # Devise auth, requires login for all pages
│   ├── library_controller.rb        # index - main dashboard
│   └── projects_controller.rb       # create, show, download
├── helpers/
│   └── file_icon_helper.rb          # Icon selection for projects and files
├── models/
│   ├── user.rb                      # Devise user, has_many :projects
│   ├── project.rb                   # Uploaded music project (ZIP/file)
│   ├── project_file.rb              # Extracted files with tree structure
│   └── share_link.rb                # Sharing (model exists, not implemented)
├── services/
│   └── project_extraction_service.rb  # ZIP extraction logic
├── views/
│   ├── layouts/application.html.erb   # Dark theme layout with header
│   ├── library/index.html.erb         # Main library grid view
│   ├── projects/show.html.erb         # Project file browser view
│   └── devise/                         # Auth forms
└── javascript/
    └── upload.js                       # Drag-drop, file picker logic
```

## Key Models & Relationships

```
User
├── has_many :projects, dependent: :destroy
├── validates: username (required, unique)

Project
├── belongs_to :user
├── has_many :project_files, dependent: :destroy
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

ShareLink (NOT YET IMPLEMENTED)
├── belongs_to :project
├── fields: token, expires_at, download_count, password_digest
```

## Routes

```ruby
devise_for :users                       # Auth routes

resources :projects, only: [:create, :show, :destroy] do
  member do
    get :download
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
| File hiding rules | `app/models/project_file.rb` (HIDDEN_EXTENSIONS, HIDDEN_FOLDERS) |
| File icon selection | `app/helpers/file_icon_helper.rb` |
| Upload UI/UX | `app/javascript/upload.js` |
| Library view | `app/views/library/index.html.erb` |
| Project browser | `app/views/projects/show.html.erb` |
| Styling | `app/assets/stylesheets/application.tailwind.css` |
| Routes | `config/routes.rb` |
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
- ZIP file extraction with tree structure preservation
- Project type auto-detection (Ableton/Logic/Folder)
- Project download (original ZIP)
- Library grid view
- **Project file browser** - View extracted files and navigate subfolders
- File type icons throughout UI
- Dark theme UI

## What's NOT Implemented Yet

- **ShareLink functionality** (model exists, no controller/UI)
- **Individual file downloads** (can only download original ZIP)
- **Search** (icon in UI, no logic)
- **Notifications** (icon with hardcoded badge, no backend)
- **Project deletion** (route exists, no controller action)
- **Background job extraction** (currently synchronous)
- **Audio previews/waveforms**
- **Collaboration features**
- **Payment integration**
- **Cloud storage** (using local Active Storage)

## Architecture Notes

1. **Active Storage**: Used for both original project files AND individual extracted files
2. **Service Objects**: Business logic in `app/services/` (e.g., ProjectExtractionService)
3. **Self-referential association**: ProjectFile uses `parent_id` for folder tree structure
4. **Synchronous extraction**: ZIP extraction happens in controller - should move to background job for large files
5. **Helper modules**: FileIconHelper for icon selection logic, included in views

## Controller Actions

### ProjectsController
- `show` - View project contents, supports subfolder navigation via `folder_id` param
- `create` - Upload new project, triggers ZIP extraction
- `download` - Download original uploaded file
- `destroy` - Route exists but **not implemented**

### LibraryController
- `index` - Main dashboard (empty action, view renders user's projects)

## Testing

Test framework is Minitest but **no tests have been written yet**. Test files exist as empty stubs in `test/`.

## Known Issues / Technical Debt

1. Large ZIP files block request (need background job)
2. No error handling in extraction service
3. Hardcoded "3" notification badge
4. ShareLink model unused
5. Project destroy action not implemented
6. Individual file download not available
7. Devise mailer not configured for password resets
8. Zero test coverage
