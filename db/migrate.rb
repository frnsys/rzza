# connects to database
def db_connect
	dir = Pathname.new(__FILE__).realpath.dirname
	
	# Need to dynamically gen this instead of loading it from yaml.
	# dbconfig = YAML::load(File.open(dir + 'database.yml')) # load database config

	dbconfig = {
		'adapter' => 'sqlite3',
		'host' => 'localhost',
		'user' => 'root',
		'password' => 'root',
		'database' => (dir + 'database').to_s
	}

	ActiveRecord::Base.establish_connection(dbconfig) # "connect" to db
end

# generates tables if there are none
def spawn_tables
	# pseudo-migration / schema
	if !FeedEntry.table_exists?
		print "Creating feed entry table...\n"
		ActiveRecord::Base.connection.create_table(:feed_entries) do |t|
			t.column :name, :string
			t.column :author, :string
			t.column :content, :string
			t.column :fullcontent, :string
			t.column :url, :string
			t.column :guid, :string
			t.column :published_at, :datetime
			t.column :feed_id, :integer
			t.column :created_at, :datetime
			t.column :updated_at, :datetime
		end
	end
	if !Feed.table_exists?
		print "Creating feed table...\n"
		ActiveRecord::Base.connection.create_table(:feeds) do |t|
			t.column :url, :string
			t.column :source_id, :integer
			t.column :created_at, :datetime
			t.column :updated_at, :datetime
		end
	end
	if !Category.table_exists?
		print "Creating category table...\n"
		ActiveRecord::Base.connection.create_table(:categories) do |t|
			t.column :name, :string
			t.column :created_at, :datetime
			t.column :updated_at, :datetime
		end
	end
	if !Source.table_exists?
		print "Creating source table...\n"
		ActiveRecord::Base.connection.create_table(:sources) do |t|
			t.column :name, :string
			t.column :created_at, :datetime
			t.column :updated_at, :datetime
		end
	end
	if !FeedsCategory.table_exists?
		print "Creating feeds_categories table...\n"
		ActiveRecord::Base.connection.create_table(:feeds_categories) do |t|
			t.column :category_id, :integer
			t.column :feed_id, :integer 
			t.column :created_at, :datetime
			t.column :updated_at, :datetime
		end
	end
end
