class CreateCollaborations < ActiveRecord::Migration[7.1]
  def change
    create_table :collaborations do |t|
      t.references :user, null: false, foreign_key: true
      t.references :collaborator, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end

    # Prevent duplicate collaborations (A-B is same as B-A for mutual)
    add_index :collaborations, [:user_id, :collaborator_id], unique: true
  end
end
