class AddShareLinkToDownloads < ActiveRecord::Migration[7.1]
  def change
    add_reference :downloads, :share_link, null: true, foreign_key: true
  end
end
