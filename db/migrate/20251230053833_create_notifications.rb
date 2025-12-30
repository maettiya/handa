class CreateNotifications < ActiveRecord::Migration[7.1]
  def change
    create_table :notifications do |t|
      t.references :user, null: false, foreign_key: true        # Who receives the notification
      t.references :actor, null: false, foreign_key: { to_table: :users }  # Who triggered it
      t.string :notification_type, null: false                   # e.g., "collaborator_added"
      t.string :message                                          # Optional custom message
      t.boolean :read, default: false, null: false
      t.timestamps
    end

    add_index :notifications, [:user_id, :read]  # For fetching unread notifications quickly
  end
end
