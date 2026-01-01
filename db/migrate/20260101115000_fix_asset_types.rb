class FixAssetTypes < ActiveRecord::Migration[7.1]
  def up
    # Fix asset_type for files based on their filename extension
    # This corrects migrated data where asset_type wasn't properly set

    # Lossless audio files
    execute <<-SQL
      UPDATE assets
      SET asset_type = 'lossless_audio'
      WHERE is_directory = false
        AND asset_type IS NULL
        AND (
          original_filename ILIKE '%.wav' OR
          original_filename ILIKE '%.aif' OR
          original_filename ILIKE '%.aiff' OR
          original_filename ILIKE '%.flac'
        )
    SQL

    # Compressed audio files
    execute <<-SQL
      UPDATE assets
      SET asset_type = 'compressed_audio'
      WHERE is_directory = false
        AND asset_type IS NULL
        AND (
          original_filename ILIKE '%.mp3' OR
          original_filename ILIKE '%.m4a' OR
          original_filename ILIKE '%.aac' OR
          original_filename ILIKE '%.ogg'
        )
    SQL

    # Also check attached file filename for root-level assets
    # that may only have title set (not original_filename)
    execute <<-SQL
      UPDATE assets
      SET asset_type = 'lossless_audio'
      WHERE is_directory = false
        AND asset_type IS NULL
        AND parent_id IS NULL
        AND id IN (
          SELECT record_id FROM active_storage_attachments
          WHERE record_type = 'Asset'
            AND name = 'file'
            AND blob_id IN (
              SELECT id FROM active_storage_blobs
              WHERE filename ILIKE '%.wav'
                 OR filename ILIKE '%.aif'
                 OR filename ILIKE '%.aiff'
                 OR filename ILIKE '%.flac'
            )
        )
    SQL

    execute <<-SQL
      UPDATE assets
      SET asset_type = 'compressed_audio'
      WHERE is_directory = false
        AND asset_type IS NULL
        AND parent_id IS NULL
        AND id IN (
          SELECT record_id FROM active_storage_attachments
          WHERE record_type = 'Asset'
            AND name = 'file'
            AND blob_id IN (
              SELECT id FROM active_storage_blobs
              WHERE filename ILIKE '%.mp3'
                 OR filename ILIKE '%.m4a'
                 OR filename ILIKE '%.aac'
                 OR filename ILIKE '%.ogg'
            )
        )
    SQL

    # Set 'other' for any remaining files without asset_type
    execute <<-SQL
      UPDATE assets
      SET asset_type = 'other'
      WHERE is_directory = false
        AND asset_type IS NULL
    SQL
  end

  def down
    # Can't reliably reverse this - data migration
  end
end
