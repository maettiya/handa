class ChangeUserIdNullableOnDownloads < ActiveRecord::Migration[7.1]
  def change
    change_column_null :downloads, :user_id, true
  end
end
