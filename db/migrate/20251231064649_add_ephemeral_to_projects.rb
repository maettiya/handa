class AddEphemeralToProjects < ActiveRecord::Migration[7.1]
  def change
    add_column :projects, :ephemeral, :boolean, default: false, null: false
    add_reference :projects, :shared_from_user, foreign_key: { to_table: :users }, null: true
    add_index :projects, [:user_id, :ephemeral]
  end
end
