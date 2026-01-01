# Asset Model Architecture

> Reference document for Handa's unified Asset model structure.
> This replaces the previous Project/ProjectFile dual-model approach.

## Overview

Everything in Handa is an **Asset**. Whether it's a single .wav file, an Ableton project with extracted contents, or a folder - it's all the same model with a self-referential tree structure.

## Database Schema

```sql
CREATE TABLE assets (
  id                    BIGSERIAL PRIMARY KEY,
  title                 VARCHAR,           -- User-editable display name
  original_filename     VARCHAR,           -- Original filename (for downloads)
  user_id               BIGINT NOT NULL,   -- FK → users (owner)
  parent_id             BIGINT,            -- FK → assets (self-ref, NULL = library root)
  path                  VARCHAR,           -- Full path for tree traversal
  file_size             BIGINT,            -- Cached size in bytes
  is_directory          BOOLEAN DEFAULT FALSE,
  hidden                BOOLEAN DEFAULT FALSE,
  file_type             VARCHAR,           -- Extension-based (als, wav, mp3, etc)
  asset_type            VARCHAR,           -- Detected type (ableton, logic, folder, audio)
  extracted             BOOLEAN DEFAULT FALSE,
  ephemeral             BOOLEAN DEFAULT FALSE,
  shared_from_user_id   BIGINT,            -- FK → users (attribution for saved shares)
  created_at            TIMESTAMP NOT NULL,
  updated_at            TIMESTAMP NOT NULL
);

-- Indexes
CREATE INDEX idx_assets_user_parent ON assets (user_id, parent_id);
CREATE INDEX idx_assets_user_ephemeral ON assets (user_id, ephemeral);
CREATE INDEX idx_assets_parent ON assets (parent_id);

-- Foreign keys
ALTER TABLE assets ADD FOREIGN KEY (user_id) REFERENCES users(id);
ALTER TABLE assets ADD FOREIGN KEY (parent_id) REFERENCES assets(id);
ALTER TABLE assets ADD FOREIGN KEY (shared_from_user_id) REFERENCES users(id);
```

## Field Reference

| Field | Type | Purpose |
|-------|------|---------|
| `id` | bigint | Primary key |
| `title` | string | User-editable display name (shown in UI) |
| `original_filename` | string | Original filename, used for downloads |
| `user_id` | FK | Owner of the asset |
| `parent_id` | FK (self) | Parent asset (NULL = library root level) |
| `path` | string | Full path from root (e.g., "Samples/kicks/kick_01.wav") |
| `file_size` | bigint | File size in bytes (cached for performance) |
| `is_directory` | boolean | true = folder, false = file |
| `hidden` | boolean | true = junk file (.asd, __MACOSX, etc) |
| `file_type` | string | File extension (als, wav, mp3, midi, etc) |
| `asset_type` | string | Detected project type (see below) |
| `extracted` | boolean | true = ZIP has been extracted into children |
| `ephemeral` | boolean | true = Quick Share (temporary, not in main library) |
| `shared_from_user_id` | FK | Original owner when saved from a share link |

### Asset Types

| Value | Description |
|-------|-------------|
| `ableton` | Ableton Live project (.als file detected) |
| `logic` | Logic Pro project (.logicx detected) |
| `fl_studio` | FL Studio project (.flp detected) |
| `pro_tools` | Pro Tools session (.ptx detected) |
| `lossless_audio` | Lossless audio file (.wav, .aif, .flac) |
| `compressed_audio` | Compressed audio (.mp3, .m4a, .aac) |
| `folder` | User-created folder |
| `other` | Any other file type |

## Tree Structure

```
User's Library (parent_id: NULL)
│
├── 🎵 Track_Master.wav                    ← Asset (is_directory: false)
│   └── file attached: Track_Master.wav
│
├── 📁 My Beats Collection                 ← Asset (is_directory: true, asset_type: "folder")
│   ├── 🎵 beat_01.wav                     ← Asset (parent_id: My Beats.id)
│   ├── 🎵 beat_02.mp3                     ← Asset (parent_id: My Beats.id)
│   └── 📁 Drafts                          ← Asset (is_directory: true)
│       └── 🎵 draft_idea.wav              ← Asset (parent_id: Drafts.id)
│
├── 🔶 SERENADE Project                    ← Asset (is_directory: true, extracted: true, asset_type: "ableton")
│   └── file attached: SERENADE.zip (original upload)
│   │
│   └── Children (extracted contents):
│       ├── 🔶 SERENADE.als                ← Asset (parent_id: SERENADE.id)
│       ├── 📁 Samples                     ← Asset (is_directory: true)
│       │   ├── 🎵 kick.wav                ← Asset (parent_id: Samples.id)
│       │   ├── 🎵 snare.wav
│       │   └── 🎵 hihat.wav
│       └── 📁 Ableton Project Info        ← Asset (hidden: true)
│           └── Project8.asd               ← Asset (hidden: true)
│
└── 🟣 Logic Session                       ← Asset (is_directory: true, asset_type: "logic")
    └── Children...
```

## Model Relationships

```ruby
class Asset < ApplicationRecord
  # Ownership
  belongs_to :user
  belongs_to :shared_from_user, class_name: "User", optional: true

  # Tree structure (self-referential)
  belongs_to :parent, class_name: "Asset", optional: true
  has_many :children, class_name: "Asset", foreign_key: "parent_id", dependent: :destroy

  # Sharing
  has_many :share_links, dependent: :destroy

  # File attachment
  has_one_attached :file
end

class User < ApplicationRecord
  has_many :assets, dependent: :destroy
end

class ShareLink < ApplicationRecord
  belongs_to :asset
end
```

## Scopes

```ruby
class Asset < ApplicationRecord
  # Library root (what user sees on main page)
  scope :root_level, -> { where(parent_id: nil) }

  # Main library (excludes ephemeral quick shares)
  scope :library, -> { root_level.where(ephemeral: false) }

  # Quick shares (ephemeral, temporary)
  scope :ephemeral_shares, -> { root_level.where(ephemeral: true) }

  # Filter out hidden junk files
  scope :visible, -> { where(hidden: false) }

  # Type filters
  scope :directories, -> { where(is_directory: true) }
  scope :files, -> { where(is_directory: false) }
end
```

## Common Queries

```ruby
# User's main library (root-level, non-ephemeral)
current_user.assets.library.visible.order(created_at: :desc)

# Inside a folder/project
@asset.children.visible.order(:original_filename)

# Quick shares
current_user.assets.ephemeral_shares.order(created_at: :desc)

# All DAW files across user's library
current_user.assets.files.where(file_type: %w[als logicx flp ptx])

# All audio files
current_user.assets.files.where(file_type: %w[wav mp3 aif aiff flac m4a aac ogg])

# Total storage used
current_user.assets.sum(:file_size)

# Find all children recursively (for ZIP download)
def all_descendants
  children.includes(:children).flat_map { |c| [c] + c.all_descendants }
end
```

## Example Data

| id | title | original_filename | user_id | parent_id | is_directory | asset_type | extracted | ephemeral |
|----|-------|-------------------|---------|-----------|--------------|------------|-----------|-----------|
| 1 | My Track | My_Track.wav | 1 | NULL | false | lossless_audio | false | false |
| 2 | SERENADE | SERENADE.zip | 1 | NULL | true | ableton | true | false |
| 3 | SERENADE.als | SERENADE.als | 1 | 2 | false | NULL | false | false |
| 4 | Samples | Samples | 1 | 2 | true | NULL | false | false |
| 5 | kick.wav | kick.wav | 1 | 4 | false | NULL | false | false |
| 6 | My Folder | My Folder | 1 | NULL | true | folder | false | false |
| 7 | Quick Share | demo.mp3 | 1 | NULL | false | compressed_audio | false | true |

## Key Behaviors

### Upload Flow
1. User uploads file → Create Asset with `parent_id: nil`
2. If ZIP → `AssetExtractionJob` extracts contents as child Assets
3. Detect `asset_type` from contents (look for .als, .logicx, etc.)
4. Set `extracted: true` when complete

### Folder Navigation
1. Library shows `current_user.assets.library.visible`
2. Clicking asset with `is_directory: true` shows `asset.children.visible`
3. Breadcrumbs built by walking `parent` chain upward

### Sharing
1. Any Asset can have ShareLinks
2. ShareLink has token, optional password, optional expiry
3. Quick Share creates `ephemeral: true` asset with auto-generated ShareLink

### Drag & Drop
1. Files can be dragged into folders (update `parent_id`)
2. Audio files dragged onto each other → create "untitled folder" with both
3. Breadcrumbs are drop targets to move files to any level

### Hidden Files
Automatically hidden during extraction:
- Extensions: `.asd`, `.ds_store`
- Folders: `Ableton Project Info`, `__MACOSX`
- Files starting with `.` or `Icon`

## Migration from Project/ProjectFile

The old architecture had:
- `Project` - Root-level container (confusing for single files)
- `ProjectFile` - Extracted contents with tree structure

Issues with old approach:
- A single .wav file was wrapped in a Project container
- Inconsistent: Project had `title`, ProjectFile had `original_filename`
- Two different models for essentially the same thing

New approach unifies everything:
- Single `Asset` model
- `parent_id: nil` = library root (was Project)
- Children = extracted contents (was ProjectFile)
- Same model, same queries, same drag-drop behavior everywhere

## File Locations

| Purpose | Path |
|---------|------|
| Model | `app/models/asset.rb` |
| Controller | `app/controllers/assets_controller.rb` |
| Extraction Service | `app/services/asset_extraction_service.rb` |
| Extraction Job | `app/jobs/asset_extraction_job.rb` |
| Icon Helper | `app/helpers/file_icon_helper.rb` |
| Library View | `app/views/library/index.html.erb` |
| Asset Browser | `app/views/assets/show.html.erb` |
| Breadcrumbs | `app/views/assets/_breadcrumbs.html.erb` |
| Drag Controller | `app/javascript/controllers/file_drag_controller.js` |
| Upload Controller | `app/javascript/controllers/asset_upload_controller.js` |
