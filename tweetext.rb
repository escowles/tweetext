#!/usr/bin/env ruby

require 'highline'
require 'inifile'
require 'rbconfig'
require 'rest-client'

def config
  @config ||= IniFile.load(config_file)
end

def main_config
  config['twtxt'] || {}
end

def tweetfile
  main_config['twtfile']
end

def timeline_limit
  main_config['limit_timeline'] || 20
end

def timeline_sort
  main_config['sorting'] || 'descending'
end

def my_info
  { main_config['nick'] => main_config['twturl'] }
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
  exec main_config['post_tweet_hook'] if main_config['post_tweet_hook']
end

# timeline: show list of tweets
def timeline
  tweets = []
  following.merge(my_info).each do |nick,url|
    tweets.concat timeline_for_user(nick,url)
  end
  tweeets = tweets[-timeline_limit, timeline_limit].sort_by { |h| h[:date] }
  (timeline_sort == 'descending') ? tweets.reverse : tweets
end

def timeline_for_user(nick, url)
  RestClient.get(url).split("\n").map do |line|
    parts = line.split("\t")
    { from: nick, date: parts[0], text: parts[1] }
  end
end

# quickstart: wizard to create initial config
def quickstart
  if File.exist?(config_file)
    puts "config file already exists: #{config_file}"
    return
  end

  cli = HighLine.new
  nick = cli.ask("Username:")
  file = cli.ask("Full local path to twtxt file:")
  url = cli.ask("URL where txtxt will be published:")
  open(config_file, 'w') do |f|
    f.puts "[twtxt]"
    f.puts "nick = #{nick}"
    f.puts "twturl = #{url}"
    f.puts "twtfile = #{file}"
    f.puts "#check_following = True"
    f.puts "#use_pager = False"
    f.puts "#limit_timeline = 20"
    f.puts "#sorting = descending"
    f.puts "#post_tweet_hook = \"scp tw.txt bob@example.com:~/public_html/twtxt.txt\""
  end
  puts "example config written to #{config_file}"
end

def usage
puts <<"USAGE"
usage: tweetext command [args]

a ruby reimplementation of twtxt

commands:
  follow [nick] [twturl]  follow a new user
  following               list users you are following
  quickstart              generate a basic configuration
  timeline                show your timeline
  tweet [text] (date)     post a tweet (optional: date to use instead of now)
  unfollow [nick]         unfollow a user

USAGE
end

# command line options
if ARGV[0] == 'follow' && ARGV[1] && ARGV[2]
  follow ARGV[1], ARGV[2]
elsif ARGV[0] == 'following'
  following.sort.each do |nick, url|
    puts "#{nick} @ #{url}"
  end
elsif ARGV[0] == 'quickstart'
  quickstart
elsif ARGV[0] == 'timeline'
  timeline.each do |tweet|
    puts "#{tweet[:from]} (#{tweet[:date]}):"
    puts tweet[:text]
    puts
  end
elsif ARGV[0] == 'tweet' && ARGV[1]
  tweet ARGV[1], ARGV[2]
elsif ARGV[0] == 'unfollow' && ARGV[1]
  unfollow ARGV[1]
else
  usage
end
