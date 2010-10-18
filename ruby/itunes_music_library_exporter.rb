#!/usr/bin/env ruby192
# -*- coding: utf-8 -*-
require "fileutils"
require "open-uri"
require "kconv"

require "rubygems"
require "plist"
require "id3lib"

src_mp3_dir = "mp3"
if Dir.exitst?(src_mp3_file)
  warn("I can't find source mp3 directory. Pleace copy from ~/Music/iTunes/iTunes Music.")
  exit(1)
end

# You can find ~/Music/iTunes/iTunes Music Library.xml
plist = Plist::parse_xml("iTunesMusicLibrary.xml")

# Load plist
tracks_hash = plist["Tracks"]

home_path = File.expand_path("~")
itunes_dir = home_path + "/Music/iTunes"
itunes_dir_uri = "file://localhost" + itunes_dir + "/iTunes Music"
itunes_dir_uri = itunes_dir_uri.sub(" ", "%20")

tracks_hash.each do |track_hash|
  track_hash.shift
  
  track_hash.each do |track_info|
    # print target mp3 file's infomation.
    printf(track_info["Artist"] + "'s " + track_info["Name"] + " in " + track_info["Album"] + " at " + track_info["Track Number"].to_s + "\n")

    # source mp3 file and path
    mp3_file = track_info["Location"].sub(itunes_dir_uri + "/", "mp3/")
    mp3_file = URI.decode(mp3_file)

    # distination mp3 file
    renamed_mp3_file_name = "track-" + sprintf("%02d", track_info["Track Number"]) + ".mp3"
    # distination directory
    if track_info["Compilation"] == true
      # mp3 file is a part of comilation.
      renamed_mp3_file_dir = "mp3_rename/va/" + track_info["Album"]
    else
      renamed_mp3_file_dir = "mp3_rename/" + track_info["Artist"] + "/" + track_info["Album"]
    end
    # create distination directory.
    FileUtils.mkdir_p(renamed_mp3_file_dir)
    renamed_mp3_file = renamed_mp3_file_dir + "/" + renamed_mp3_file_name
    printf("copy to : " + renamed_mp3_file + "\n")
    # copy file.
    FileUtils.cp(mp3_file, renamed_mp3_file)
    # update id3v2 tag.
    tag = ID3Lib::Tag.new(renamed_mp3_file)
    tag.title = track_info["Name"]
    tag.album = track_info["Album"]
    tag.performer = track_info["Artist"]
    tag.track = track_info["Track Number"].to_s + "/" + track_info["Track Count"].to_s
    tag.update!
    printf("id3v2 tag update.\n")
    printf("\n")
  end
end
