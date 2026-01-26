class Download < ApplicationRecord
  belongs_to :user
  belongs_to :asset

  has_one_attached :zip_file

  STATUSES = %w[pending processing ready failed downloaded].freeze

  validates :status, inclusion: { in: STATUSES }

  scope :active, -> { where(status: %w[pending processing ready]) }
  scope :stale, -> { where('updated_at < ?', 24.hours.ago) }

  def pending?
    status == 'pending'
  end

  def processing?
    status == 'processing'
  end

  def ready?
    status == 'ready'
  end

  def failed?
    status == 'failed'
  end

  def downloaded?
    status == 'downloaded'
  end

  def progress_text
    return "Preparing..." if total.zero?
    "#{progress}/#{total}"
  end
end
