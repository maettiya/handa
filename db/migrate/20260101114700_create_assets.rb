class CreateAssets < ActiveRecord::Migration[7.1]
  def change
    create_table :assets do |t|
      # Core fields
      t.string :title
      t.string :original_filename
      t.references :user, null: false, foreign_key: true

      # Tree structure (self-referential)
      t.references :parent, foreign_key: { to_table: :assets }, null: true

      # File metadata
      t.string :path
      t.bigint :file_size
      t.boolean :is_directory, default: false
      t.boolean :hidden, default: false
      t.string :file_type

      # Project-specific fields
      t.string :asset_type
      t.boolean :extracted, default: false
      t.boolean :ephemeral, default: false, null: false
      t.references :shared_from_user, foreign_key: { to_table: :users }, null: true

      t.timestamps
    end

    # Indexes for performance
    add_index :assets, [:user_id, :ephemeral]
    add_index :assets, [:user_id, :parent_id]
  end
end
