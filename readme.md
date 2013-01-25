# rzza
Francis Tseng

[yadonchow.com](yadonchow.com)

This script collects articles from specified news feeds to compile a corpus of news articles and other relevant information.
It does no significant processing on the articles - it just archives them to a database.

### To use rzza from the command line:
	$ cd /path/to/rzza
	$ sudo ln -s rzza /usr/bin/rzza
	$ sudo chmod u+x /usr/bin/rzza

Then you can do:

	$ rzza [command]


### Using rzza

######You can add your initial feeds to `feeds.txt` with the format:

	feedURL, sourceName, categories
	http://www.dailyplanet.com/feeds/news.xml, Daily Planet, news business politics

Categories are space delimited, and each feed gets its own line.

######Then, to generate the database and create the first set of feeds:
	$ rzza init

######You can add more feeds to `feeds.txt` and update the feeds database with:
	$ rzza migrate

######To check the feeds and pull down their entries:
	$ rzza update

######To get an overview of rzza's stats:
	$ rzza stats

######To view a random entry:
	$ rzza random

######To do some basic processing on a random entry:
	$ rzza process

######To view information on the feeds:
	$ rzza feeds

This may take awhile. You can also pass a source or category as an argument to filter.

	$ rzza feeds politics

There's also a special `down` argument which will list the feeds that appear to be down.

	$ rzza feeds down

######To view information on the categories or sources
	$ rzza categories
	$ rzza sources

#### Managing feeds
For all of these, either a feed's ID or URL may be passed as the parameter

######View a feed
	$ rzza feed 24
	$ rzza feed http://www.dailyplanet.com/feeds/news.xml

######Change a feed's url
	$ rzza feed update 24 http://www.dailyplanet.com/movedfeeds/news.xml

######Remove a feed
	$ rzza feed remove 24

######Add a single feed
	$ rzza feed add "http://www.dailyplanet.com/feeds/world.xml, Daily Planet, news world international"
The parameters should be formatted like they would be for `feeds.txt`


