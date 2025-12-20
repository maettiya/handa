# CLAUDE.md - Handa Project Guide

## Project Overview

**Handa** is a Ruby on Rails application designed as a "GitHub for music files" - a seamless storage and collaboration platform for music creators. It consolidates the workflow of sharing music projects into a single platform with automatic file extraction, preview creation, and flexible sharing.

**Current Status**: Early development - Core upload/download/extraction functionality is working. Many planned features not yet built.

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
│   └── projects_controller.rb       # create, download
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
│   └── devise/                         # Auth forms
└── javascript/
    └── upload.js                       # Drag-drop, file picker logic
```

## Key Models & Relationships

```
User
├── has_many :projects

Project
├── belongs_to :user
├── has_many :project_files
├── has_one_attached :file (original ZIP)
├── fields: title, project_type (ableton/logic/folder), extracted

ProjectFile (tree structure for extracted files)
├── belongs_to :project
├── belongs_to :parent (optional, self-referential)
├── has_many :children
├── has_one_attached :file
├── fields: original_filename, path, file_size, is_directory, hidden, file_type

ShareLink (NOT YET IMPLEMENTED)
├── belongs_to :project
├── fields: token, expires_at, download_count, password_digest
```

## Routes

```ruby
root "library#index"                    # Main library page
resources :projects, only: [:create, :destroy] do
  member { get :download }
end
devise_for :users                       # Auth routes
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
| Upload UI/UX | `app/javascript/upload.js` |
| Main view | `app/views/library/index.html.erb` |
| Styling | `app/assets/stylesheets/application.tailwind.css` |
| Routes | `config/routes.rb` |
| Database schema | `db/schema.rb` |

## ProjectFile Hidden File Logic

Files are auto-hidden during extraction:
- **Extensions**: `.asd`, `.ds_store`
- **Folders**: `Ableton Project Info`, `__MACOSX`
- **Patterns**: Files starting with `.` or `Icon`

See `ProjectFile.should_hide?(filename, is_directory:)` for implementation.

## What's Implemented

- User authentication (sign up, login, logout, password reset)
- Project upload with drag-drop and file picker
- ZIP file extraction with tree structure preservation
- Project type auto-detection (Ableton/Logic/Folder)
- Project download
- Library grid view
- Dark theme UI

## What's NOT Implemented Yet

- **ShareLink functionality** (model exists, no controller/UI)
- **Project file browser** (extracted files not displayed)
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

## Testing

Test framework is Minitest but **no tests have been written yet**. Test files exist as empty stubs in `test/`.

## Known Issues / Technical Debt

1. Large ZIP files block request (need background job)
2. No error handling in extraction service
3. Hardcoded "3" notification badge
4. ShareLink model unused
5. ProjectFile records created but never displayed
6. Devise mailer not configured for password resets
7. Zero test coverage
