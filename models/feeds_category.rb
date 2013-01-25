class FeedsCategory < ActiveRecord::Base
	belongs_to :feed
	belongs_to :category
	attr_accessible :feed_id, :category_id
end
