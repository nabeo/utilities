#!/usr/bin/env ruby192
# -*- coding: utf-8 -*-
require "fileutils"
require "uri"
require "kconv"
require "logger"

require "rubygems"
require "plist"
require "id3lib"
require "mimemagic"

home_path = File.expand_path("~")
pwd_path = FileUtils.pwd()

def copy_file_info(copy_dist_dir, track_info)
  # distination mp3 file
  if track_info["Disc Number"] != nil
    # multiple disk
    # track-disc_num-track_num.mp3
    renamed_mp3_file_name = "track-" + sprintf("%02d", track_info["Disc Number"]) + "-" + sprintf("%02d", track_info["Track Number"]) + ".mp3"
  else
    # single disk
    # track-track_num.mp3
    renamed_mp3_file_name = "track-" + sprintf("%02d", track_info["Track Number"]) + ".mp3"
  end
  
  # distination directory
  if track_info["Compilation"] == true
    # mp3 file is a part of comilation.
    renamed_mp3_file_dir = copy_dist_dir + "/va/" + track_info["Album"]
  else
    renamed_mp3_file_dir = copy_dist_dir + "/" + track_info["Artist"] + "/" + track_info["Album"]
  end

  # create distination directory.
  FileUtils.mkdir_p(renamed_mp3_file_dir)
  renamed_mp3_file = renamed_mp3_file_dir + "/" + renamed_mp3_file_name

  return renamed_mp3_file
end

def update_id3v2_tag(renamed_mp3_file, track_info)
  tag = ID3Lib::Tag.new(renamed_mp3_file)
  # song title
  tag.title = track_info["Name"]
  # album
  tag.album = track_info["Album"]
  # artist
  tag.performer = track_info["Artist"]
  # track number
  if track_info["Track Count"] == false
    tag_track = track_info["Track Number"].to_s
  else
    tag_track = track_info["Track Number"].to_s + "/" + track_info["Track Count"].to_s
  end
  tag.track = tag_track
  # disc number
  if track_info["Disc Number"] != nil and track_info["Disc Count"] != nil
    tag_part_of_set = track_info["Disc Number"].to_s + "/" + track_info["Disc Count"].to_s
  elsif track_info["Disc Number"] != nil
    tag_part_of_set = track_info["Disc Number"].to_s
  else
    tag_part_of_set = false
  end
  if tag_part_of_set != false
    tag.part_of_set = tag_part_of_set
  end
  tag.update!
end

def search_album_artwork_file(itunes_album_artwork_cache_dir,
                             library_persistent_id,
                             track_info)
  # track's Persistent ID
  track_persistent_id = track_info["Persistent ID"]
  
  # artwork file name
  album_artwork_file_name = library_persistent_id + "-" + track_persistent_id + ".itc"
  
  album_artwork_file = Dir.glob(itunes_album_artwork_cache_dir + "/**/" + album_artwork_file_name).shift
  
  return album_artwork_file
end

def copy_cover_image(copy_dist)
  # read itc file
  i = 0
  ary = []
  open(copy_dist + "/tmp.img","rb") do |itc_fp|
    itc_fp.each_byte do |ch|
      if i > 491                  # image part
        ary << ch
      end
      i += 1
    end
  end
  
  # write image file
  open(copy_dist + "/cover.img", "w+b") do |artwork_fp|
    artwork_fp.write(ary.pack("c*"))
  end
  
  # delete itc file
  File.delete(copy_dist + "/tmp.img")
  
  # detect image file's mime-type, and copy.
  artwork_file_mimetype = MimeMagic.by_magic(File.open(copy_dist + "/cover.img"))
  if artwork_file_mimetype == "image/jpg"
    cover_file = copy_dist + "/cover.jpg"
  elsif artwork_file_mimetype == "image/png"
    cover_file = copy_dist + "/cover.png"
  end
  FileUtils.mv(copy_dist + "/cover.img", cover_file)

  return cover_file
end

# program directories and files.
prog_dir = home_path + "/.config/itunes_music_library_exporter" 
if Dir.exist?(prog_dir) == false
  FileUtils.mkdir_p(prog_dir)
end
copy_dist_dir = pwd_path + "/mp3_rename"

# for logger
log_dir = prog_dir + "/logs"
if Dir.exist?(log_dir) == false
  FileUtils.mkdir_p(log_dir)
end
log_file = log_dir + "/log-" + Time.now().strftime("%Y%m%d-%H%M") + ".txt"
log = Logger.new(log_file)
log.level = Logger::INFO
print("log file : #{log_file}\n")

# iTunes directories and files.
itunes_dir = home_path + "/Music/iTunes"
itunes_music_dir = itunes_dir + "/iTunes Music"
if Dir.exist?(pwd_path + "/mp3") == true
  itunes_music_dir = pwd_path + "/mp3"
  log.info("iTuens Music directory : #{itunes_music_dir}")
end
itunes_music_library_file = itunes_dir + "/iTunes Music Library.xml"
if File.exist?(pwd_path + "/iTunesMusicLibrary.xml") == true
  itunes_music_library_file = pwd_path + "/iTunesMusicLibrary.xml"
  log.info("iTunes Music Library.xml : #{itunes_music_library_file}")
end
itunes_album_artwork_cache_dir = itunes_dir + "/Album Artwork/Cache"

# Load plist
plist = Plist::parse_xml(itunes_music_library_file)

# main part
tracks_hash = plist["Tracks"]

library_persistent_id = plist["Library Persistent ID"]
log.info("Library Persistent ID : #{library_persistent_id}")

tracks_hash.each do |track_hash|
  track_hash.shift
  
  track_hash.each do |track_info|
    # podcast is out of scope.
    if track_info["Podcast"] == nil and track_info["Track Type"] == "File"
      # print target mp3 file's infomation.
      log.info(track_info["Artist"] + "'s " + track_info["Name"] + " in " + track_info["Album"] + " at " + track_info["Track Number"].to_s)
      
      # source mp3 file and path
      mp3_file = track_info["Location"].sub("file://localhost", "")
      mp3_file = URI.decode(mp3_file)
      
      # distination file
      renamed_mp3_file = copy_file_info(copy_dist_dir, track_info)
      
      # copy file.
      FileUtils.cp(mp3_file, renamed_mp3_file)
      log.info("copy to : " + renamed_mp3_file)
      
      # update id3v2 tag.
      update_id3v2_tag(renamed_mp3_file, track_info)
      log.info("id3v2 tag update.")

      # search album artwork file from cache directory.
      album_artwork_file = search_album_artwork_file(itunes_album_artwork_cache_dir,
                                                     library_persistent_id,
                                                     track_info)
      # copy artwork file.
      if album_artwork_file != nil
        if track_info["Compilation"] == true
          copy_dist = copy_dist_dir + "/va/" + track_info["Album"]
        else
          copy_dist = copy_dist_dir + "/" + track_info["Artist"] + "/" + track_info["Album"]
        end
        FileUtils.mkdir_p(copy_dist)
        FileUtils.cp(album_artwork_file, copy_dist + "/tmp.img")
        cover_file = copy_cover_image(copy_dist)

        log.info("copy to : #{cover_file}")
      end
    end
  end
end
