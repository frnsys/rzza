
# intializes db
def initialize_db
	spawn_tables	# generate tables if they don't exist
	spawn_feeds		# add categories, sources & feeds to the respective tables
	print "Database successfully created!\n".bold.green
end

# displays feeds in the console
# param "name" is either a source or category name
def display_feeds(name)
	if name.nil? || name == "down"
		if name == "down"
			downed = 0
			puts "Checking which feeds are down. This may take awhile...".bold.green
			Feed.all.each do |feed|
				if check_url(feed.url) != "up".green
					display_feed(feed)
					downed += 1
				end
			end
			puts ("There were " + downed.to_s + " downed feeds.").red
		else
			puts (Feed.all.size.to_s + " feeds total").bold.green
			Feed.all.each do |feed|
				display_feed(feed)
			end
		end
	else
		source = Source.find_by_name(name.downcase)
		category = Category.find_by_name(name.downcase)
		if !source.nil?
			puts (source.name + " (id:" + source.id.to_s + ") has " + source.feeds.size.to_s + " feeds:").bold.green
			source.feeds.each do |feed|
				display_feed(feed)
			end
		elsif !category.nil?
			puts (category.name + " (id:" + category.id.to_s + ") has " + category.feeds.size.to_s + " feeds:").bold.green
			category.feeds.each do |feed|
				display_feed(feed)
			end
		else
			puts "Couldn't find a matching source or category.".red
		end
	end
end

def display_feed(_feed)
	if _feed.is_a? Feed
		feed = _feed
	else
		id = get_id(_feed)
 		feed = Feed.find_by_id(id)
	end
	if feed.nil?
		no_feed()
	else
		message = check_url(feed.url)
		printf "%-10s %-20s %-20s %-s\n",
			("[" + feed.id.to_s + "]"), message, feed.feed_entries.size.to_s + " entries", feed.url.cyan
	end
end

# remove a feed by id or URL
def remove_feed(argv)
	if !id.nil?
		Feed.destroy(id)
	end
end

def update_feed(argv)
	id = get_id(argv[2])
	url = argv[3]
	feed = Feed.find_by_id(id)
	if feed.nil?
		no_feed()
	elsif url.nil?
		puts "Please provide a url.".red
	else
		oldurl = feed.url
		if check_url(url)
			if feed.update_attributes(:url => url)
				puts oldurl.red + " => ".green + url.cyan
				puts "Update successful!".green
			else
				puts "Something went wrong.".red
			end
		else
			puts "That url doesn't appear to be up!".red
		end
	end
end

# show a random entry
def random_entry
	random_id = Random.rand(FeedEntry.all.size + 1)
	entry = FeedEntry.find_by_id(random_id)
	if entry.nil?
		puts "Randomly found a non-existant entry!".bold.red
	else
		display_entry(entry)
	end
end

# process a random entry (basic)
def random_process
	random_id = Random.rand(FeedEntry.all.size + 1)
	entry = FeedEntry.find_by_id(random_id)
	if entry.nil?
		puts "Randomly found a non-existant entry!".bold.red
	else
		100.times {print "=".red}
		puts "\nProcessing entry: ".green + entry.name.bold.cyan
		puts "From: " + entry.feed.source.name
		@stopwords_re = load_stopwords
		@text = wordify(Sanitize.clean(entry.fullcontent).strip, @stopwords_re)
		puts "Document length: " + @text.length.to_s
		@freqs = freqify(@text).sort_by { |key, value| -value[0] }

		printf "\n%-40s %-40s %-s\n",
			"Token", "Norm. Freq.", "Raw Freq."
		100.times {print "-".green}
		print "\n"
		@freqs.each do |key, value|
			printf "%-40s %-40s %-s\n",
				key, value[0].to_s, value[1].to_s	
		end
		100.times {print "=".red}
		puts "\nFeed Content ==>".cyan
		puts Sanitize.clean(entry.fullcontent).strip
	end
end

# show number of entries, feeds, sources, and categories
def display_stats
	puts (FeedEntry.all.size.to_s + " entries").bold.green
	puts "in " + Feed.all.size.to_s + " feeds"
	puts "from " + Source.all.size.to_s + " sources"
	puts "in " + Category.all.size.to_s + " categories."
end

# displays all categories in the console
def display_categories
	Category.all.each do |category|
		entries = 0
		category.feeds.each { |feed| entries += feed.feed_entries.size }
		printf "%-10s %-45s %-20s %-s\n",
			("[" + category.id.to_s + "]"), category.name.bold.green, category.feeds.size.to_s + " feeds", entries.to_s + " entries"
	end
end

# displays all sources in the console
def display_sources
	Source.all.each do |source|
		entries = 0
		source.feeds.each { |feed| entries += feed.feed_entries.size }
		printf "%-10s %-45s %-20s %-s\n",
			("[" + source.id.to_s + "]"), source.name.bold.green, source.feeds.size.to_s + " feeds", entries.to_s + " entries"
	end
end

# exports feeds to feeds_export.txt
def export_feeds
	logstring = ""
	Feed.all.each do |feed|
		categories = []
		feed.categories.each do |category|
			categories << category.name
		end
		logstring << (feed.url + ", " + feed.source.name + ", " + categories.join(" ") + "\n")
	end
	dir = Pathname.new(__FILE__).realpath.dirname
	File.new(dir+"exports/"+("feeds_export"+Time.new.strftime("%Y.%m.%d.%H.%M.%S")+".txt"), "w").write(logstring)
end

# updates all feeds
def update
	update_start = Time.new
	log_string = ""
	new_entries_total = 0
	connect_errors = 0
	connect_error_feeds = []
	updated_feed_stats = []
	total_feeds = Feed.all.size.to_s
	completed_feeds = 0
	Feed.all.each do |feed|
		@feed = feed # I just do this to take advantage of syntax highlighting...bad practice?
		error_messages = []
		new_entries = 0
		puts ("Updating " + @feed.url + "...").green

		rzza = Feedzirra::Feed.fetch_and_parse(@feed.url)

		# if feedzirra can't reach the feed,
		# count it as a connect error and move on
		if rzza == 0 or rzza.nil? or rzza.class == Fixnum
			connect_errors +=1
			connect_error_feeds << @feed.url
			next
		end

		# create new records for this feed's feed entries
		rzza.entries.each do |entry|
			# check if we need to get the entry's summary in lieu of content
			entry.content.blank? ? entry_content = entry.summary : entry_content = entry.content

			if entry_content.nil?
				entry_content = "entry_content was empty"
			end

			# define readability source url
			begin
				source = open(entry.url).read
			rescue => e
				puts "Error fetching entry url, skipping...".red
				puts "Error Message: " + e.message
				error_messages << e.message
			  # puts e.backtrace
				next
			end

			unless @feed.feed_entries.exists? :guid => entry.id				# <= check if the entry exists via its guid, if it doesn't exist...
				@feed.feed_entries.create!(															# <= create it!
					:name         => entry.title,
					:author				=> entry.author,
					:content 			=> Sanitize.clean(entry_content).strip,
					:fullcontent  => Readability::Document.new(source).content,
					:url          => entry.url,
					:published_at => entry.published,
					:guid         => entry.id,
					:feed_id      => @feed.id,
				)
				new_entries += 1 									# <= increment new entry count
			end
		end

		new_entries_total += new_entries

		# some feed reporting:
		feed_report = @feed.url + " (" + @feed.id.to_s + ") had " + new_entries.to_s + " new entries and errors with " + error_messages.length.to_s + " entries.\n"
		
		if error_messages.length > 0
			error_messages.each { |error| feed_report << ("\t" + error + "\n") }
		end

		puts feed_report

		updated_feed_stats << feed_report

		completed_feeds += 1
		puts "Completed " + (completed_feeds.to_s + "/" + total_feeds).cyan + " feeds."
	end

	update_end = Time.new

	# some reporting
	if new_entries_total > 0
		puts ("Update complete. There were " + new_entries_total.to_s + " new entries.").bold.green
		puts "Update took " + ( -(update_start - update_end)/60 ).to_s + " minutes."
	else
		puts "Update complete. No new entries found.".bold.green
	end
	if connect_errors > 0
		puts ("Couldn't connect to " + connect_errors.to_s + " feeds:").red
		puts connect_error_feeds
	end



	# LOGGING
	if new_entries_total > 0
		log_string << "Update started at: " + update_start.strftime("%Y.%m.%d.%H.%M.%S") + "\n"
		log_string << "rzza stats:\n"
			log_string << "\t" + FeedEntry.all.size.to_s + " entries\n"
			log_string << "\t" + Feed.all.size.to_s + " feeds\n"
			log_string << "\t" + Source.all.size.to_s + " sources\n"
			log_string << "\t" + Category.all.size.to_s + " categories\n"

		updated_feed_stats.each { |feed_stat| log_string << ("\t" + feed_stat + "\n")}

		log_string << "Couldn't connect to " + connect_errors.to_s + " out of " + total_feeds + " feeds:\n"
		connect_error_feeds.each { |feed| log_string << ("\t" + feed + "\n") }

		log_string << "There were " + new_entries_total.to_s + " new entries in " + Feed.all.size.to_s + " feeds from " + Source.all.size.to_s + " sources in " + Category.all.size.to_s + " categories.\n"
		log_string << "Completed " + completed_feeds.to_s + "/" + total_feeds + " feeds.\n"

		log_string << "Update took " + ( (update_end - update_start)/60 ).to_s + " minutes.\n"
		log_string << "Update completed at: " + update_end.strftime("%Y.%m.%d.%H.%M.%S") + "\n"
	end

	print "Update complete!\n".bold.green
	dir = Pathname.new(__FILE__).realpath.dirname
	File.new(dir+"logs/"+(update_end.strftime("%Y.%m.%d.%H.%M.%S")+".txt"), "w").write(log_string)
end


# creates or adds feeds from feeds.txt
# expects the format: feedUrl, feedSource, categories
# multiple categories can be used, they must be space delimited
def spawn_feeds(*feedParams)
	if feedParams.empty?
		dir = Pathname.new(__FILE__).realpath.dirname
		file = dir+"feeds.txt"
		File.open(file, "r").each_line do |line|
			feedParams = line.downcase.split(",").each { |param| param.strip! }
			birth_feed(feedParams, false)
		end
	else
		feedParams.each do |feedParam|
			feedParam = feedParam.downcase.split(",").each { |param| param.strip! }
			birth_feed(feedParam, true)
		end
	end
end

private

# add a new feed (and new categories/sources) to the db
# the second param specifies whether or not to append feeds.txt with the new feed
def birth_feed(feedParams, append)
	# split up the categories,
	# get their ids
	categories = feedParams[2].split()
	category_ids = []
	categories.each do |cat|
		unless @category = Category.find_by_name(cat)
			@category = Category.create(:name => cat)
		end
		category_ids.push(@category.id)
	end

	# try to find source,
	# if it doesn't exist, create a new one,
	# then get their ids
	unless @source = Source.find_by_name(feedParams[1])
		@source = Source.create(:name => feedParams[1])
	end

	# create the feed (unless it already exists)
	unless @feed = Feed.find_by_url(feedParams[0])
		@feed = Feed.create(:url => feedParams[0], :source_id => @source.id) 
	end

	# create the feed <-> category relationships
	category_ids.each do |cat|
		unless FeedsCategory.find_by_category_id_and_feed_id(cat, @feed.id)
			FeedsCategory.create(:category_id => cat, :feed_id => @feed.id )
		end
	end

	if append == true
		dir = Pathname.new(__FILE__).realpath.dirname
		file = dir+"/feeds.txt"
		File.open(file, "a") do |feedFile|
			feedFile.print("\n" + feedParams.join(", "))
		end
	end
end

def display_entry(entry)
	print "\n"
	100.times {print "=".red}
	100.times {print "=".red}
	print "\n"
	puts entry.name.bold.green
	print "Date: "
	puts entry.updated_at
	print "Author: "
	entry.author.nil? ? author = "nil" : author = entry.author
	puts author
	puts entry.url
	puts "Feed Content ==>".cyan
	puts entry.content
	100.times {print "=".red}
	100.times {print "=".red}
	print "\n"
	puts "Extracted Content ==>".cyan
	puts Sanitize.clean(entry.fullcontent).strip
	print "\n"
	100.times {print "=".red}
	100.times {print "=".red}
	print "\n\n"
end

# Check if the URL is still working
def check_url(feedUrl)
	url = URI.parse(feedUrl)
	req = Net::HTTP.new(url.host, url.port);
	begin
		res = req.request_head(url.path);
	rescue
		return false;
	end
	return res.code == "404" ? "down".red : "up".green
end

# Converts a feed URL to its id or just gives the id
def get_id(arg)
	begin
		return Integer(arg)
	rescue
		feed = Feed.find_by_url(arg)
		if feed.nil?
			return nil
		else
			return feed.id
		end
	end
end

def no_feed()
	puts "No feed by that id or url.".red
end