class UpdateShareLinksForAssets < ActiveRecord::Migration[7.1]
  def up
    # Add asset_id column
    add_reference :share_links, :asset, foreign_key: true, null: true

    # Drop and recreate mapping table
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

    # Migrate data from project_id to asset_id
    execute <<-SQL
      UPDATE share_links
      SET asset_id = (
        SELECT asset_id FROM project_asset_map
        WHERE project_id = share_links.project_id
      )
      WHERE EXISTS (
        SELECT 1 FROM project_asset_map
        WHERE project_id = share_links.project_id
      )
    SQL

    # Remove old project_id column
    remove_foreign_key :share_links, :projects
    remove_column :share_links, :project_id

    # Make asset_id required now that data is migrated
    change_column_null :share_links, :asset_id, false
  end

  def down
    # Add back project_id column
    add_reference :share_links, :project, foreign_key: true, null: true

    # Recreate mapping table
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

    # Migrate data back
    execute <<-SQL
      UPDATE share_links
      SET project_id = (
        SELECT project_id FROM project_asset_map
        WHERE asset_id = share_links.asset_id
      )
      WHERE EXISTS (
        SELECT 1 FROM project_asset_map
        WHERE asset_id = share_links.asset_id
      )
    SQL

    # Remove asset_id
    remove_foreign_key :share_links, :assets
    remove_column :share_links, :asset_id

    # Make project_id required
    change_column_null :share_links, :project_id, false
  end
end
