#!/usr/bin/env ruby

require 'highline'
require 'inifile'
require 'rbconfig'

# config
#  load config from ~/Library/Application Support/twtxt/config
#    [twtxt] basic app config
#    twtfile: file to post tweets to
#    post_tweet_hook: command to run after posting a tweet
#    use_pager: whether or not to page timeline
#    sorting: sort timeline asc or desc
#    *check_following: ???
#    *twurl: where my twtxt is published
#    *nick: nick i use for myself
#    [following]: list of nick = twxturls
#
# commands:
#   following: list who i'm following
#   follow: add nick = url to [following] section
#   unfollow: remove someone from list
#   tweet: post a tweet
#   timeline: show list of tweets

def config
  @config ||= IniFile.load(config_file)
end

def tweetfile
  config['twtxt']['twtfile']
end

def config_file
  File.expand_path(config_dir + "config")
end

def config_dir
  # macosx: ~/Library/Application Support/twtxt
  # linux: ~/.config/twtxt
  # windows: who cares?
  macos? ? '~/Library/Application Support/twtxt/' : '~/.config/twtxt/'
end

def macos?
  RbConfig::CONFIG['host_os'] =~ /darwin/
end

# timelines to follow as a hash: nick = twtxt_url
def following
  config['following']
end

# add nick = url to [following] config
def follow(nick, url)
  config['following'][nick] = url
  config.save
end

# remove nick from from [following] config
def unfollow(nick)
  config['following'].delete(nick)
  config.save
end

# tweet: post a tweet
def tweet(text, at = current_timestamp)
  return unless check_length(text.length)
  open(tweetfile, 'a') do |f|
    f.puts "#{at}\t#{text}"
  end
  post_tweet_hook
end

# require confirmation if text is longer than 140
def check_length(length)
  return true if length <= 140
  msg = "tweet is longer than 140 characters (#{length}).  are you sure? (y/N)"
  ans = HighLine.new.ask(msg)
  return ans.downcase == 'y'
end

def current_timestamp
  Time.new.strftime('%FT%T%z')
end

# command to run after posting a tweet
def post_tweet_hook
  exec config['twtxt']['post_tweet_hook']
end

# timeline: show list of tweets
def timeline
  # XXX
end

# quickstart: wizard to create initial config
def quickstart
  # XXX
end

#unfollow ARGV[0]
#puts following
tweet(ARGV[0])

# XXX impl command line parsing and display
