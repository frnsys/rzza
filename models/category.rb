class Category < ActiveRecord::Base
	has_many :feeds_categories
	has_many :feeds, :through => :feeds_categories
	attr_accessible :name
end
