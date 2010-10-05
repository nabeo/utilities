#!/usr/bin/env ruby192
#encoding:utf-8

require "fileutils"

require "rubygems"
require "exifr"

DIST_PREFIX = "/data00/Picts/Photos"
if Dir.exist?(DIST_PREFIX) == false
  warn("I can't find #{DIST_PREFIX}. Please check `DIST_PREFIX`.")
  exit(false)
end

target_dir = ARGV.shift
if target_dir == nil
  target_dir = FileUtils.pwd()
else
  if Dir.exist?(target_dir) == false
    warn("I can't find #{target_dir}.")
    exit(false)
  end
end

def copy_file(orig_file, dist_path)
  file = File.new(orig_file)
  orig_file_name = file.basename(orig_file)                        
  print("#{orig_file_name} ... ")
  orig_file_ext = file.extname(orig_file_name)
  orig_file_no_ext = file.basename(orig_file_name, orig_file_ext)

  # コピー先のディレクトリを作成
  FileUtils.mkdir_p(dist_path)
  
  if File.exist?(dist_path + orig_file_name) == false
    # 何も考えずにコピーできる
    FileUtils.copy_file(orig_file, dist_path + "/" + orig_file_name)
    print("copy.\n")
  else
    # 同名のファイルがコピー先にある
    i = Dir.glob(dist_path + orig_file_no_ext + "*").length.to_s
    dist_path_file_name = orig_file_no_ext + "-" + i + orig_file_ext
    copy_flag = false
    # 既に同じファイルがあればコピーしない
    Dir.glob(dist_path + orig_file_no_ext + "*").each do |dist_exist_file|
      if FileUtils.cmp(orig_file, dist_exist_file)
        copy_flag = true
      end
    end
    # 同名で異なるファイルがあればコピーする
    if copy_flag == false
      FileUtils.copy_file(orig_file, dist_path + "/" + dist_path_file_name, true)
      print("copy.\n")
    else
      print("nothing to do.\n")
    end
  end
end

Dir.glob(target_dir + "/**/*.{jpg,JPG,nef,NEF}") do |file|
  file = File.new(file)
  file_name = file.basename(file)
  file_ext = file.extname(file_name)
  if file_ext == ".jpg" or file_ext == ".JPG"
    # jpegファイルの処理
    jpg_file = file
    jpg = EXIFR::JPEG.new(jpg_file)
    if jpg.exif? == false
      # EXIFデータがない -> コピーしない
      warn("#{jpg_file} does not have exif data.")
    else
      t = jpg.exif.date_time_original
      shoot_time = {:year => t.strftime("%Y"), :month => t.strftime("%m"), :day => t.strftime("%d")}
      dist_jpg_dir = DIST_PREFIX + "/" + shoot_time[:year] + "/" + shoot_time[:month] + "/" + shoot_time[:day] + "/"
      copy_file(jpg_file, dist_jpg_dir)
    end
  elsif file_ext == ".nef" or file_ext == ".NEF"
    # rawファイルの処理
    raw_file = file
    raw = EXIFR::TIFF.new(raw_file)
    t = raw.date_time_original
    shoot_time = {:year => t.strftime("%Y"), :month => t.strftime("%m"), :day => t.strftime("%d")}
    dist_raw_dir = DIST_PREFIX + "/raw/" + shoot_time[:year] + "/" + shoot_time[:month] + "/" + shoot_time[:day] + "/"
    copy_file(raw_file, dist_raw_dir)
  end
end
