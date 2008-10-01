module ActiveRecord
  module Is
    module Taggable
      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        def taggable?
          false
        end

        def is_taggable
          is_taggable :tags
        end

        def is_taggable(*args)
          args.flatten! if args
          args.compact! if args
          for tag_type in args
            tag_type = tag_type.to_s
            self.class_eval do
              has_many "#{tag_type.singularize}_taggings".to_sym, :as => :taggable, :dependent => :destroy, :conditions => ["context = ?",tag_type], :class_name => "Tagging"
            end

            self.class_eval <<-RUBY
              def self.taggable?
                true
              end

              def self.caching_#{tag_type.singularize}_list?
                caching_tag_list_on?("#{tag_type}")
              end

              def self.#{tag_type.singularize}_counts(options={})
                tag_counts_on('#{tag_type}',options)
              end

              def #{tag_type.singularize}_list
                tag_list_on('#{tag_type}').to_s
              end

              def #{tag_type}
                tag_list_on('#{tag_type}')
              end

              def #{tag_type}=(tags)
                set_tags_on('#{tag_type}', tags)
              end

              def #{tag_type.singularize}_list=(new_tags)
                set_tag_list_on('#{tag_type}', new_tags)
              end

              def #{tag_type.singularize}_counts(options = {})
                tag_counts_on('#{tag_type}',options)
              end

              def #{tag_type}_from(owner)
                tag_list_on('#{tag_type}', owner)
              end

              def find_related_#{tag_type}(options = {})
                related_tags_for('#{tag_type}', self.class, options)
              end
              alias_method :find_related_on_#{tag_type}, :find_related_#{tag_type}

              def find_related_#{tag_type}_for(klass, options = {})
                related_tags_for('#{tag_type}', klass, options)
              end
            RUBY
          end

          if respond_to?(:tag_types)
            write_inheritable_attribute( :tag_types, (tag_types + args).uniq )
          else
            self.class_eval do
              write_inheritable_attribute(:tag_types, args.uniq)
              class_inheritable_reader :tag_types

              has_many :taggings, :as => :taggable, :dependent => :destroy

              attr_writer :custom_contexts

              before_save :save_cached_tag_list
              after_save :save_tags

              if respond_to?(:named_scope)
                named_scope :tagged_with, lambda{ |tags, options|
                  find_options_for_find_tagged_with(tags, options)
                }
              end
            end

            include ActiveRecord::Is::Taggable::InstanceMethods
            extend  ActiveRecord::Is::Taggable::SingletonMethods
            alias_method_chain :reload, :tag_list
          end
        end

        def is_taggable?
          false
        end
      end

      module SingletonMethods
        # Pass either a tag string, or an array of strings or tags
        #
        # Options:
        #   :exclude - Find models that are not tagged with the given tags
        #   :match_all - Find models that match all of the given tags, not just one
        #   :conditions - A piece of SQL conditions to add to the query
        #   :on - scopes the find to a context
        def find_tagged_with(*args)
          options = find_options_for_find_tagged_with(*args)
          options.blank? ? [] : find(:all,options)
        end

        def caching_tag_list_on?(context)
          column_names.include?("cached_#{context.to_s.singularize}_list")
        end

        def tag_counts_on(context, options = {})
          Tagging.find(:all, find_options_for_tag_counts(options.merge({:on => context.to_s})))
        end

        def find_options_for_find_tagged_with(tags, options = {})
          tags = tags.is_a?(Array) ? TagList.new(tags.map(&:to_s)) : TagList.from(tags)

          return {} if tags.empty?

          conditions = []
          conditions << sanitize_sql(options.delete(:conditions)) if options[:conditions]

          unless (on = options.delete(:on)).nil?
            conditions << sanitize_sql(["context = ?",on.to_s])
          end

          taggings_alias = "#{table_name}_taggings"

          if options.delete(:exclude)
            conditions << sanitize_sql(["#{table_name}.id NOT IN (SELECT #{Tagging.table_name}.taggable_id FROM #{Tagging.table_name} WHERE (#{Tagging.table_name}.normalized IN(?)) AND #{Tagging.table_name}.taggable_type = #{quote_value(base_class.name)})", tags.normalized])
          else
            conditions << sanitize_sql(["#{taggings_alias}.normalized IN(?)", tags.normalized])

            if options.delete(:match_all)
              group = "#{taggings_alias}.taggable_id HAVING COUNT(#{taggings_alias}.taggable_id) = #{taggings.size}"
            end
          end

          { :select     => "DISTINCT #{table_name}.*",
            :joins      => "LEFT OUTER JOIN #{Tagging.table_name} #{taggings_alias} ON #{taggings_alias}.taggable_id = #{table_name}.#{primary_key} AND #{taggings_alias}.taggable_type = #{quote_value(base_class.name)}",
            :conditions => conditions.join(" AND "),
            :group      => group
          }.update(options)
        end

        # Calculate the tag counts for all tags.
        #
        # Options:
        #  :start_at - Restrict the tags to those created after a certain time
        #  :end_at - Restrict the tags to those created before a certain time
        #  :conditions - A piece of SQL conditions to add to the query
        #  :limit - The maximum number of tags to return
        #  :order - A piece of SQL to order by. Eg 'tags.count desc' or 'taggings.created_at desc'
        #  :at_least - Exclude tags with a frequency less than the given value
        #  :at_most - Exclude tags with a frequency greater than the given value
        #  :on - Scope the find to only include a certain context
        def find_options_for_tag_counts(options = {})
          options.assert_valid_keys :start_at, :end_at, :conditions, :at_least, :at_most, :order, :limit, :on

          scope = scope(:find)
          start_at = sanitize_sql(["#{Tagging.table_name}.created_at >= ?", options.delete(:start_at)]) if options[:start_at]
          end_at = sanitize_sql(["#{Tagging.table_name}.created_at <= ?", options.delete(:end_at)]) if options[:end_at]
          
          type_and_context = "#{Tagging.table_name}.taggable_type = #{quote_value(base_class.name)}"
          type_and_context << sanitize_sql(["AND #{Tagging.table_name}.context = ?", options.delete(:on).to_s]) unless options[:on].nil?
          
          conditions = [
            type_and_context,
            start_at,
            end_at
          ]

          conditions = conditions.compact.join(' AND ')
          conditions = merge_conditions(conditions, options.delete(:conditions)) if options[:conditions]
          conditions = merge_conditions(conditions, scope[:conditions]) if scope

          joins = ["LEFT OUTER JOIN #{table_name} ON #{table_name}.#{primary_key} = #{Tagging.table_name}.taggable_id"]
          joins << scope[:joins] if scope && scope[:joins]

          at_least  = sanitize_sql(['COUNT(*) >= ?', options.delete(:at_least)]) if options[:at_least]
          at_most   = sanitize_sql(['COUNT(*) <= ?', options.delete(:at_most)]) if options[:at_most]
          having    = [at_least, at_most].compact.join(' AND ')
          
          # note that it makes sense here to group by both (and allow both to 
          # be selected) since we're enforcing that tags that normalize to the
          # same thing can't exist. this means there will never be a case when
          # one normalized tag has multiple non-normalized representations,
          # meaning we still have a proper set when grouping by either column
          group_by  = "#{Tagging.table_name}.normalized, #{Tagging.table_name}.tag HAVING COUNT(*) > 0"
          group_by << " AND #{having}" unless having.blank?
          
          { :select     => "#{Tagging.table_name}.tag, COUNT(*) AS count",
            :joins      => joins.join(" "),
            :conditions => conditions,
            :group      => group_by
          }.update(options)
        end

        def is_taggable?
          true
        end
      end

      module InstanceMethods

        def tag_types
          self.class.tag_types
        end

        def custom_contexts
          @custom_contexts ||= []
        end

        def is_taggable?
          self.class.is_taggable?
        end

        def add_custom_context(value)
          custom_contexts << value.to_s unless custom_contexts.include?(value.to_s) or self.class.tag_types.map(&:to_s).include?(value.to_s)
        end

        def tag_list_on(context, owner=nil)
          var_name = context.to_s.singularize + "_list"
          add_custom_context(context)
          return instance_variable_get("@#{var_name}") unless instance_variable_get("@#{var_name}").nil?

          if !owner && self.class.caching_tag_list_on?(context) and !(cached_value = cached_tag_list_on(context)).nil?
            instance_variable_set("@#{var_name}", TagList.from(self["cached_#{var_name}"]))
          else
            instance_variable_set("@#{var_name}", TagList.new(*taggings_on(context, owner).map(&:tag)))
          end
        end

        def taggings_on(context, owner=nil)
          if owner
            opts = {:conditions => ["context = ? AND tagger_id = ? AND tagger_type = ?", context.to_s, owner.id, owner.class.to_s]}
          else
            opts = {:conditions => ["context = ?", context.to_s]}
          end
          taggings.find(:all, opts)
        end

        def cached_tag_list_on(context)
          self["cached_#{context.to_s.singularize}_list"]
        end

        def set_tag_list_on(context,new_list, tagger=nil)
          instance_variable_set("@#{context.to_s.singularize}_list", TagList.from_owner(tagger, new_list))
          add_custom_context(context)
        end
        
        def set_tags_on(context, new_tags, tagger=nil)
          instance_variable_set("@#{context.to_s.singularize}_list", TagList.new_from_owner(tagger, *new_tags))
          add_custom_context(context)
        end

        def tag_counts_on(context,options={})
          self.class.tag_counts_on(context,{:conditions => ["#{Tagging.table_name}.normalized IN (?)", tag_list_on(context).normalized]}.reverse_merge!(options))
        end

        def related_tags_for(context, klass, options = {})
          search_conditions = related_search_options(context, klass, options)

          klass.find(:all, search_conditions)
        end

        def related_search_options(context, klass, options = {})
          tags_to_find = self.taggings_on(context).collect(&:normalized)

          { :select     => "#{klass.table_name}.*, related_ids.count AS count",
            :from       => "#{klass.table_name}",
            :joins      => sanitize_sql(["INNER JOIN(
              SELECT #{klass.table_name}.id, COUNT(#{Tagging.table_name}.id) AS count
                FROM #{klass.table_name}, #{Tagging.table_name}
               WHERE #{klass.table_name}.id = #{Tagging.table_name}.taggable_id AND #{Tagging.table_name}.taggable_type = '#{klass.to_s}'
                 AND #{Tagging.table_name}.context = '#{context}' AND #{Tagging.table_name}.normalized IN (?)
               GROUP BY #{klass.table_name}.id
              ) AS related_ids ON(#{klass.table_name}.id = related_ids.id)", tags_to_find]),
            :order      => "count DESC"
          }.update(options)
        end

        def save_cached_tag_list
          self.class.tag_types.map(&:to_s).each do |tag_type|
            if self.class.send("caching_#{tag_type.singularize}_list?")
              self["cached_#{tag_type.singularize}_list"] = send("#{tag_type.singularize}_list").to_s
            end
          end
        end

        def save_tags
          all_taggings = {}
          self.taggings.find(:all, :order => 'context ASC').each do |tagging|
            all_taggings[tagging.context] ||= []
            all_taggings[tagging.context] << tagging
          end
          
          (custom_contexts + self.class.tag_types.map(&:to_s)).each do |tag_type|
            next unless contextual_tag_list = instance_variable_get("@#{tag_type.singularize}_list")
            normalized_tag_list = contextual_tag_list.normalized
            owner = contextual_tag_list.owner
            existing_taggings = all_taggings[tag_type.to_sym] || []
            new_tag_names = normalized_tag_list - existing_taggings.map(&:normalized)
            old_tags = existing_taggings.reject { |tagging| normalized_tag_list.include?(tagging.normalized) }

            self.class.transaction do
              self.taggings.delete(*old_tags) if old_tags.any?
              if new_tag_names.any? # it's possible we're just removing existing tags
                sql  = "INSERT INTO taggings (tag, normalized, context, taggable_id, taggable_type, tagger_id, tagger_type, created_at) VALUES "
                sql += new_tag_names.collect { |tag| tag_insert_value(tag, tag_type, self, owner) }.join(", ")
                ActiveRecord::Base.connection.execute(sql)
              end
            end
          end

          true
        end

        def sanitize_sql attrs
          ActiveRecord::Base.send(:sanitize_sql, attrs)
        end

        def tag_insert_value(tag, type, taggable, owner=nil)
          sanitize_sql(["(?, ?, ?, ?, ?, ?, ?, ?)",
            tag,
            TagList.normalize(tag),
            type,
            taggable.id,
            taggable.class.base_class.to_s, # base_class to support STI properly
            owner ? owner.id : nil,
            owner ? owner.class.to_s : nil,
            Time.now.utc.to_s(:db)
          ])
        end

        def reload_with_tag_list(*args)
          self.class.tag_types.each do |tag_type|
            self.instance_variable_set("@#{tag_type.to_s.singularize}_list", nil)
          end

          reload_without_tag_list(*args)
        end
      end
    end
  end
end
