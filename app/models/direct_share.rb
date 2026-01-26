class DirectShare < ApplicationRecord
  belongs_to :user           # The person sharing
  belongs_to :recipient, class_name: 'User'  # The person receiving
  belongs_to :asset
  belongs_to :share_link

  # Get top N recipients for a user (people they share with most)
  def self.top_recipients_for(user, limit: 5)
    User.where(id:
      where(user: user)
        .group(:recipient_id)
        .order(Arel.sql('COUNT(*) DESC'))
        .limit(limit)
        .select(:recipient_id)
    )
  end
end
