class MigrateProjectFilesToAssets < ActiveRecord::Migration[7.1]
  def up
    # Drop any existing temp table, then recreate the project_asset_map
    execute "DROP TABLE IF EXISTS project_asset_map"
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

    # Create mapping table for project_file_id -> asset_id
    execute <<-SQL
      CREATE TEMPORARY TABLE file_asset_map (
        project_file_id BIGINT PRIMARY KEY,
        asset_id BIGINT
      )
    SQL

    # First pass: Insert all project_files as assets with parent_id pointing to root asset
    # For files with parent_id = NULL, they are direct children of the project (root asset)
    execute <<-SQL
      INSERT INTO assets (
        title,
        original_filename,
        user_id,
        parent_id,
        path,
        file_size,
        is_directory,
        hidden,
        file_type,
        created_at,
        updated_at
      )
      SELECT
        pf.original_filename,
        pf.original_filename,
        p.user_id,
        pam.asset_id,
        pf.path,
        pf.file_size,
        COALESCE(pf.is_directory, false),
        COALESCE(pf.hidden, false),
        pf.file_type,
        pf.created_at,
        pf.updated_at
      FROM project_files pf
      INNER JOIN projects p ON p.id = pf.project_id
      INNER JOIN project_asset_map pam ON pam.project_id = pf.project_id
      WHERE pf.parent_id IS NULL
    SQL

    # Build the file mapping for root-level project_files
    execute <<-SQL
      INSERT INTO file_asset_map (project_file_id, asset_id)
      SELECT pf.id, a.id
      FROM project_files pf
      INNER JOIN projects p ON p.id = pf.project_id
      INNER JOIN project_asset_map pam ON pam.project_id = pf.project_id
      INNER JOIN assets a ON
        a.original_filename = pf.original_filename AND
        a.parent_id = pam.asset_id AND
        a.created_at = pf.created_at
      WHERE pf.parent_id IS NULL
    SQL

    # Handle nested files - we need to do this iteratively for each level
    # Process files whose parent exists in file_asset_map
    10.times do |depth|
      # Insert children whose parent is already mapped
      execute <<-SQL
        INSERT INTO assets (
          title,
          original_filename,
          user_id,
          parent_id,
          path,
          file_size,
          is_directory,
          hidden,
          file_type,
          created_at,
          updated_at
        )
        SELECT
          pf.original_filename,
          pf.original_filename,
          p.user_id,
          fam.asset_id,
          pf.path,
          pf.file_size,
          COALESCE(pf.is_directory, false),
          COALESCE(pf.hidden, false),
          pf.file_type,
          pf.created_at,
          pf.updated_at
        FROM project_files pf
        INNER JOIN projects p ON p.id = pf.project_id
        INNER JOIN file_asset_map fam ON fam.project_file_id = pf.parent_id
        WHERE pf.id NOT IN (SELECT project_file_id FROM file_asset_map)
      SQL

      # Map the newly inserted files
      execute <<-SQL
        INSERT INTO file_asset_map (project_file_id, asset_id)
        SELECT pf.id, a.id
        FROM project_files pf
        INNER JOIN file_asset_map parent_fam ON parent_fam.project_file_id = pf.parent_id
        INNER JOIN assets a ON
          a.original_filename = pf.original_filename AND
          a.parent_id = parent_fam.asset_id AND
          a.created_at = pf.created_at
        WHERE pf.id NOT IN (SELECT project_file_id FROM file_asset_map)
      SQL
    end
  end

  def down
    # Delete assets that were migrated from project_files (have parent_id)
    execute "DELETE FROM assets WHERE parent_id IS NOT NULL"
    execute "DROP TABLE IF EXISTS file_asset_map"
    execute "DROP TABLE IF EXISTS project_asset_map"
  end
end
