class AddProcessingFieldsToAssets < ActiveRecord::Migration[7.1]
  def change
    add_column :assets, :processing_status, :string, default: nil
    add_column :assets, :processing_progress, :integer, default: 0
    add_column :assets, :processing_total, :integer, default: 0
  end
end
