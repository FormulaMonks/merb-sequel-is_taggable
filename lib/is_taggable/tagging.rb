class Tagging < ActiveRecord::Base #:nodoc:
  belongs_to :taggable, :polymorphic => true
  belongs_to :tagger, :polymorphic => true
  
  # these validations are useless since we don't save tags this way...
  validates_presence_of :context
  validates_presence_of :tag
  validates_presence_of :normalized
  validates_uniqueness_of :normalized, :scope => [ :context, :taggable_type, :taggable_id ]
  
  def tag=(tag)
    self[:tag] = tag
    self[:normalized] = TagList.normalize(tag)
  end
  
  def context
    self[:context] ? self[:context].to_sym : nil
  end
  
  def to_s
    tag
  end
  
  def count
    read_attribute(:count).to_i
  end
  
  def save
    raise "Taggings are protected from being created individually, please use the tagging methods on Taggable objects"
  end
end
