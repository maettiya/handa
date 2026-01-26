class CreateDownloads < ActiveRecord::Migration[7.1]
  def change
    create_table :downloads do |t|
      t.references :user, null: false, foreign_key: true
      t.references :asset, null: false, foreign_key: true
      t.string :status, default: 'pending', null: false
      t.integer :progress, default: 0
      t.integer :total, default: 0
      t.string :filename
      t.string :error_message

      t.timestamps
    end

    add_index :downloads, [:user_id, :status]
  end
end
