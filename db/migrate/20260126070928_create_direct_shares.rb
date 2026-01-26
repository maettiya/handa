class CreateDirectShares < ActiveRecord::Migration[7.1]
  def change
    create_table :direct_shares do |t|
      t.references :user, null: false, foreign_key: true
      t.references :recipient, null: false, foreign_key: { to_table: :users }
      t.references :asset, null: false, foreign_key: true
      t.references :share_link, null: false, foreign_key: true

      t.timestamps
    end

    # Index for finding top recipients (who user shares with most)
    add_index :direct_shares, [:user_id, :recipient_id]
  end
end
