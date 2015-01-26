class Link < ActiveRecord::Base
  # TODO: acts_as_editable and acts_as_protected
  # Maintain this order for the index page.
  CATEGORIES = HashWithIndifferentAccess.new(
    Homepage: 9,
    Download: 10,
    Community: 7,
    Documentation: 4,
    Forums: 3,
    'Issue Trackers' => 5,
    'Mailing Lists' => 6,
    Other: 8
  ).freeze

  belongs_to :project
  acts_as_editable editable_attributes: [:title, :url, :link_category_id],
                   merge_within: 30.minutes
  acts_as_protected parent: :project
  has_many :accounts, through: :edits

  validates :title, length: { in: 3..60 }, presence: true
  validates :url, presence: true,
                  uniqueness: { scope: [:project_id, :link_category_id] },
                  url_format: { message: :invalid_url }
  validates :link_category_id, presence: true

  def revive_or_create
    deleted_link = Link.find_by(url: url, project_id: project_id, deleted: true)

    return save unless deleted_link

    CreateEdit.where(target: deleted_link).first.redo!(editor_account)
    deleted_link.editor_account = editor_account
    deleted_link.update_attributes(title: title, link_category_id: link_category_id)
  end

  def category
    self.class.find_category_by_id(link_category_id)
  end

  def allow_undo?(key)
    ![:title, :url, :link_category_id].include?(key)
  end

  class << self
    def find_category_by_id(category_id)
      return unless category_id

      CATEGORIES.find { |_k, v| v == category_id.to_i }.first
    end
  end
end