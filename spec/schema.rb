ActiveRecord::Schema.define :version => 0 do
  create_table "taggings", :force => true do |t|
    t.string   "tag"
    t.string   "normalized"
    t.string   "context"
    t.integer  "taggable_id",   :limit => 11
    t.string   "taggable_type"
    t.datetime "created_at"
    t.integer  "tagger_id",     :limit => 11
    t.string   "tagger_type"
  end

  add_index "taggings", ["tag"], :name => "index_taggings_on_tag"
  add_index "taggings", ["taggable_id", "taggable_type", "context"], :name => "index_taggings_on_taggable_id_and_taggable_type_and_context"
  add_index "taggings", ["taggable_id", "taggable_type", "context", "normalized"], :name => "index_taggings_on_taggable_and_context_and_normalized", :uniq => true
  
  create_table :taggable_models, :force => true do |t|
    t.column :name, :string
    t.column :type, :string
    #t.column :cached_tag_list, :string
  end
  create_table :taggable_users, :force => true do |t|
    t.column :name, :string
  end
  create_table :other_taggable_models, :force => true do |t|
    t.column :name, :string
    t.column :type, :string
    #t.column :cached_tag_list, :string
  end
end
