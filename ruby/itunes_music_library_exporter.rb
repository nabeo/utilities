#!/usr/bin/env ruby192
require "fileutils"

require "rubygems"
require "plist"
require "id3lib"

plist = Plist::parse_xml("iTunesMusicLibrary.xml")
warn("load file done.")
tracks_hash = plist["Tracks"]

home_path = File.expand_path("~")
itunes_dir = home_path + "/Music/iTunes"
itunes_dir_for_gsub = itunes_dir.gsub(/\//, "\\\/")

tracks_hash.each do |track_hash|
  track_hash.shift
  
  track_hash.each do |track_info|
    printf(track_info["Artist"] + "'s " + track_info["Name"] + " in " + track_info["Album"] + " at " + track_info["Track Number"].to_s + "\n")
    mp3_file_name = sprintf("%02d", track_info["Track Number"]) + " " + track_info["Name"] + ".mp3"
    mp3_file = Dir.glob("mp3/**/" + mp3_file_name).shift

    renamed_mp3_file_name = "track-" + sprintf("%02d", track_info["Track Number"]) + ".mp3"
    if track_info["Compilation"] == true
      renamed_mp3_file_dir = "mp3_rename/va/" + track_info["Album"]
    else
      renamed_mp3_file_dir = "mp3_rename/" + track_info["Artist"] + "/" + track_info["Album"]
    end
    FileUtils.mkdir_p(renamed_mp3_file_dir)
    renamed_mp3_file = renamed_mp3_file_dir + "/" + renamed_mp3_file_name
    printf("copy to : " + renamed_mp3_file + "\n")
    FileUtils.cp(mp3_file, renamed_mp3_file)
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
