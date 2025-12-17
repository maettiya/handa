class AddExtractionFieldsToProjectsAndProjectFiles < ActiveRecord::Migration[7.1]
  def change
    # Add project type detection fields
    add_column :projects, :project_type, :string
    add_column :projects, :extracted, :boolean, default: false

    # Add fields for file hierarchy
    add_column :project_files, :path, :string
    add_column :project_files, :file_size, :bigint
    add_column :project_files, :is_directory, :boolean, default: false
    add_column :project_files, :hidden, :boolean, default: false
    add_reference :project_files, :parent, foreign_key: { to_table: :project_files }, null: true
  end
end
