class CreateDownloads < ActiveRecord::Migration[7.1]
  def change
    create_table :downloads do |t|
      t.references :user, null: false, foreign_key: true
      t.references :asset, null: false, foreign_key: true
      t.string :status
      t.integer :progress
      t.integer :total
      t.string :filename
      t.string :error_message

      t.timestamps
    end
  end
end
