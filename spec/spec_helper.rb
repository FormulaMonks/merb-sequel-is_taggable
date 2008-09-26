# require File.dirname(__FILE__) + '/../../../../spec/spec_helper'
# hack the require with absolute path like this for now...
# require '/Users/benalavi/Sites/causecast/spec/spec_helper'
require '/Users/michel/CitrusByte/causecast/spec/spec_helper'

module Spec::Example::ExampleGroupMethods
  alias :context :describe
end

plugin_spec_dir = File.dirname(__FILE__)
ActiveRecord::Base.logger = Logger.new(plugin_spec_dir + "/debug.log")

load(File.dirname(__FILE__) + '/schema.rb')

class TaggableModel < ActiveRecord::Base
  is_taggable :tags, :languages
  is_taggable :skills
end

class OtherTaggableModel < ActiveRecord::Base
  is_taggable :tags, :languages
end

class InheritingTaggableModel < TaggableModel
end

class AlteredInheritingTaggableModel < TaggableModel
  is_taggable :parts
end

class TaggableUser < ActiveRecord::Base
  is_tagger
end

class UntaggableModel < ActiveRecord::Base
end
