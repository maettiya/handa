class CreateShareLinks < ActiveRecord::Migration[7.1]
  def change
    create_table :share_links do |t|
      t.string :token
      t.datetime :expires_at
      t.integer :download_count
      t.string :password_digest
      t.references :project, null: false, foreign_key: true

      t.timestamps
    end
  end
end
