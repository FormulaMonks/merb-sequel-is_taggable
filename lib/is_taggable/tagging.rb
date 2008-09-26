class Tagging < ActiveRecord::Base #:nodoc:
  belongs_to :taggable, :polymorphic => true
  belongs_to :tagger, :polymorphic => true

  validates_presence_of :context
  validates_presence_of :tag
  validates_uniqueness_of :tag, :with_scope => [ :context, :taggable_type, :taggable_id ]
  
  # LIKE is used for cross-database case-insensitivity
  class << self
    def find_or_create_with_like_by_tag(tag)
      find(:first, :conditions => ["tag LIKE ?", tag]) || create(:tag => tag)
    end
    alias :find_or_create_with_like_by_name :find_or_create_with_like_by_tag
  end
  
  def to_s
    tag
  end
  
  def count
    read_attribute(:count).to_i
  end
end