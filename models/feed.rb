class Feed < ActiveRecord::Base
	belongs_to :source
	has_many :feed_entries, :dependent => :destroy
	has_many :feeds_categories
	has_many :categories, :through => :feeds_categories
	attr_accessible :url, :category_id, :source_id
end
