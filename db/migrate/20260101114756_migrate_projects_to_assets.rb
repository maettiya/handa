class MigrateProjectsToAssets < ActiveRecord::Migration[7.1]
  def up
    # Create a temporary mapping table for project_id -> asset_id
    execute <<-SQL
      CREATE TEMPORARY TABLE project_asset_map (
        project_id BIGINT PRIMARY KEY,
        asset_id BIGINT
      )
    SQL

    # Migrate all projects as root-level assets
    execute <<-SQL
      INSERT INTO assets (
        title,
        original_filename,
        user_id,
        parent_id,
        path,
        is_directory,
        asset_type,
        extracted,
        ephemeral,
        shared_from_user_id,
        created_at,
        updated_at
      )
      SELECT
        title,
        title,
        user_id,
        NULL,
        title,
        CASE WHEN project_type = 'folder' THEN true ELSE false END,
        project_type,
        COALESCE(extracted, false),
        COALESCE(ephemeral, false),
        shared_from_user_id,
        created_at,
        updated_at
      FROM projects
    SQL

    # Build the mapping table by matching on unique fields
    # Using created_at + user_id + title to match
    execute <<-SQL
      INSERT INTO project_asset_map (project_id, asset_id)
      SELECT p.id, a.id
      FROM projects p
      INNER JOIN assets a ON
        a.title = p.title AND
        a.user_id = p.user_id AND
        a.created_at = p.created_at AND
        a.parent_id IS NULL
    SQL
  end

  def down
    # Delete assets that were migrated from projects (root level)
    execute "DELETE FROM assets WHERE parent_id IS NULL"
    execute "DROP TABLE IF EXISTS project_asset_map"
  end
end
