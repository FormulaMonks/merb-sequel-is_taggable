class IsTaggableMigration < ActiveRecord::Migration
  def self.up
    create_table :taggings do |t|
      t.column :tagger_type, :string
      t.column :tagger_id, :integer
      t.column :taggable_type, :string
      t.column :taggable_id, :integer

      t.column :tag, :string
      t.column :context, :string
      
      t.column :created_at, :datetime
    end
    
    add_index :taggings, :tag_id
    add_index :taggings, [:taggable_id, :taggable_type]
    add_index :taggings, [:taggable_id, :taggable_type, :context]
    add_index :taggings, [:taggable_id, :taggable_type, :context, :tag], :uniq => true
  end
  
  def self.down
    drop_table :taggings
  end
end
