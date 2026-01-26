class ChangeActorIdNullableOnNotifications < ActiveRecord::Migration[7.1]
  def change
    change_column_null :notifications, :actor_id, true
  end
end
