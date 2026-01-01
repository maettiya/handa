class MigrateAttachmentsToAssets < ActiveRecord::Migration[7.1]
  def up
    # Drop and recreate mapping tables
    execute "DROP TABLE IF EXISTS project_asset_map"
    execute "DROP TABLE IF EXISTS file_asset_map"
    execute <<-SQL
      CREATE TEMPORARY TABLE project_asset_map AS
      SELECT p.id as project_id, a.id as asset_id
      FROM projects p
      INNER JOIN assets a ON
        a.title = p.title AND
        a.user_id = p.user_id AND
        a.created_at = p.created_at AND
        a.parent_id IS NULL
    SQL

    # Build file_asset_map by matching project_files to assets via original_filename and path
    execute <<-SQL
      CREATE TEMPORARY TABLE file_asset_map AS
      SELECT pf.id as project_file_id, a.id as asset_id
      FROM project_files pf
      INNER JOIN project_asset_map pam ON pam.project_id = pf.project_id
      INNER JOIN assets a ON
        a.original_filename = pf.original_filename AND
        a.path = pf.path AND
        a.created_at = pf.created_at
    SQL

    # Update Active Storage attachments for Projects
    execute <<-SQL
      UPDATE active_storage_attachments
      SET record_type = 'Asset',
          record_id = (
            SELECT asset_id FROM project_asset_map
            WHERE project_id = active_storage_attachments.record_id
          )
      WHERE record_type = 'Project'
        AND EXISTS (
          SELECT 1 FROM project_asset_map
          WHERE project_id = active_storage_attachments.record_id
        )
    SQL

    # Update Active Storage attachments for ProjectFiles
    execute <<-SQL
      UPDATE active_storage_attachments
      SET record_type = 'Asset',
          record_id = (
            SELECT asset_id FROM file_asset_map
            WHERE project_file_id = active_storage_attachments.record_id
          )
      WHERE record_type = 'ProjectFile'
        AND EXISTS (
          SELECT 1 FROM file_asset_map
          WHERE project_file_id = active_storage_attachments.record_id
        )
    SQL
  end

  def down
    # Recreate reverse mapping
    execute <<-SQL
      CREATE TEMPORARY TABLE project_asset_map AS
      SELECT p.id as project_id, a.id as asset_id
      FROM projects p
      INNER JOIN assets a ON
        a.title = p.title AND
        a.user_id = p.user_id AND
        a.created_at = p.created_at AND
        a.parent_id IS NULL
    SQL

    execute <<-SQL
      CREATE TEMPORARY TABLE file_asset_map AS
      SELECT pf.id as project_file_id, a.id as asset_id
      FROM project_files pf
      INNER JOIN project_asset_map pam ON pam.project_id = pf.project_id
      INNER JOIN assets a ON
        a.original_filename = pf.original_filename AND
        a.path = pf.path AND
        a.created_at = pf.created_at
    SQL

    # Reverse: Asset back to Project
    execute <<-SQL
      UPDATE active_storage_attachments
      SET record_type = 'Project',
          record_id = (
            SELECT project_id FROM project_asset_map
            WHERE asset_id = active_storage_attachments.record_id
          )
      WHERE record_type = 'Asset'
        AND EXISTS (
          SELECT 1 FROM project_asset_map
          WHERE asset_id = active_storage_attachments.record_id
        )
    SQL

    # Reverse: Asset back to ProjectFile
    execute <<-SQL
      UPDATE active_storage_attachments
      SET record_type = 'ProjectFile',
          record_id = (
            SELECT project_file_id FROM file_asset_map
            WHERE asset_id = active_storage_attachments.record_id
          )
      WHERE record_type = 'Asset'
        AND EXISTS (
          SELECT 1 FROM file_asset_map
          WHERE asset_id = active_storage_attachments.record_id
        )
    SQL
  end
end
