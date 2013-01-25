class Source < ActiveRecord::Base
	has_many :feeds, :dependent => :destroy
	attr_accessible :name
end
