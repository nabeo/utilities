#!/usr/bin/env ruby192
# -*- coding: utf-8 -*-

require "fileutils"

require "rubygems"
require "id3lib"
require "mimemagic"

target_dir = ARGV.shift
if target_dir == nil
  target_dir = FileUtils.pwd()
else
  if Dir.exist?(target_dir) == false
    warn("I can't find #{target_dir}.\n")
    exit(false)
  end
end

Dir.glob(target_dir + "/**/*.{mp3,MP3}") do |mp3_file|
  print("#{mp3_file} : ")
  mp3_file_name = File.basename(mp3_file)
  mp3_file_dir = File.dirname(mp3_file)

  # search cover art picture
  # cover art picture is png or jpg file.
  cover_file = Dir.glob(mp3_file_dir + "/cover.{jpg,JPG,png,PNG}").shift
  if cover_file != nil
    # detect cover_file"s mimetype
    cover_file_mimetype = MimeMagic.by_magic(File.open(cover_file)).to_s
    
    mp3_tag = ID3Lib::Tag.new(mp3_file)
    # if mp3_file does not have APIC tag, attach cover_file as APIC
    if mp3_tag.frame(:APIC) == nil
      mp3_tag << { 
        :id => :APIC,
        :mimetype => cover_file_mimetype,
        :picturetype => 3,
        :description => "",
        :textenc => 0,
        :data => File.read(cover_file)
      }
      mp3_tag.update!
      print("#{cover_file}\n")
      else
      print("has apic tag.\n")
    end
  else
    print("cover file not found.\n")
  end
end
