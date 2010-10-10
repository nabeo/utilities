#!/usr/bin/env ruby192
# -*- coding: utf-8 -*-

require "fileutils"
require "yaml"
require "time"
require "logger"

require "rubygems"
require "exifr"

home_path = File.expand_path("~")
config = { "dist_dir" => "#{home_path}/Pictures"}

FileUtils.mkdir_p("#{home_path}/.mk_photo_catalog")
log_file = home_path + "/.mk_photo_catalog/log-" + Time.now().strftime("%Y%m%d-%H%M") + ".txt"
log = Logger.new(log_file)
log.level = Logger::INFO
print("log file : #{log_file}\n")

# 設定ファイル(config.yaml)の読み込み
# 設定ファイルの記述例
# dist_dir: /path/to/dist_dir
config_file = "config.yaml"
if File.exist?(config_file)
  print("load from : ./#{config_file}\n")
  config = YAML.load_file(config_file)
elsif File.exist?("#{home_path}/.mk_photo_catalog/#{config_file}")
  print("load from : #{home_path}/.mk_photo_catalog/#{config_file}\n")
  config = YAML.load_file("#{home_path}/.mk_photo_catalog/#{config_file}")
else
  warn("I can't find #{config_file}.\n")
end

DIST_PREFIX = config["dist_dir"]
if Dir.exist?(DIST_PREFIX) == false
  log.error("I can't find #{DIST_PREFIX}. Please check `DIST_PREFIX`.")
  exit(false)
end

target_dir = ARGV.shift
if target_dir == nil
  target_dir = FileUtils.pwd()
else
  if Dir.exist?(target_dir) == false
    log.error("I can't find #{target_dir}.")
    exit(false)
  end
end

def my_copy_file(orig_file, dist_path)
  orig_file_name = File.basename(orig_file)                        
  print("#{orig_file_name} ... ")
  orig_file_ext = File.extname(orig_file_name)
  orig_file_no_ext = File.basename(orig_file_name, orig_file_ext)

  # コピー先のディレクトリを作成
  FileUtils.mkdir_p(dist_path)

  if File.exist?(dist_path + "/" + orig_file_name) == false
    # 何も考えずにコピーできる
    FileUtils.copy_file(orig_file, dist_path + "/" + orig_file_name)
    print("copy.\n")
    retval = dist_path + "/" + orig_file_name
  else
    # 同名のファイルがコピー先にある
    i = Dir.glob(dist_path + "/" + orig_file_no_ext + "*").length.to_s
    dist_path_file_name = orig_file_no_ext + "-" + i + orig_file_ext
    copy_flag = false
    # 既に同じファイルがあればコピーしない
    Dir.glob(dist_path + "/" + orig_file_no_ext + "*").each do |dist_exist_file|
      if FileUtils.cmp(orig_file, dist_exist_file)
        copy_flag = true
      end
    end

    # 同名で異なるファイルがあればコピーする
    if copy_flag == false
      FileUtils.copy_file(orig_file, dist_path + "/" + dist_path_file_name, true)
      print("copy.\n")
      retval = dist_path + "/" + dist_path_file_name
    else
      print("nothing to do.\n")
      retval = false
    end
  end
  return retval
end

Dir.glob(target_dir + "/**/*.{jpg,JPG,nef,NEF}") do |file|
  file_name = File.basename(file)
  file_ext = File.extname(file_name)
  if file_ext == ".jpg" or file_ext == ".JPG"
    # jpegファイルの処理
    jpg_file = file
    jpg = EXIFR::JPEG.new(jpg_file)
    if jpg.exif? != false
      t = jpg.exif.date_time_original
      shoot_time = {:year => t.strftime("%Y"), :month => t.strftime("%m"), :day => t.strftime("%d")}
      dist_jpg_dir = DIST_PREFIX + "/" + shoot_time[:year] + "/" + shoot_time[:month] + "/" + shoot_time[:day]
      copy_result = my_copy_file(jpg_file, dist_jpg_dir)
      if copy_result == false
        copy_result = "nothing to do."
      end
      log.info("#{jpg_file} -> #{copy_result}")
    else
      # EXIFデータがない -> コピーしない
      warn("#{jpg_file} does not have exif data.")
      log.info("#{file} -> does not have exif data.")
    end
  elsif file_ext == ".nef" or file_ext == ".NEF"
    # rawファイルの処理
    raw_file = file
    raw = EXIFR::TIFF.new(raw_file)
    t = raw.date_time_original
    if t != nil
      shoot_time = {:year => t.strftime("%Y"), :month => t.strftime("%m"), :day => t.strftime("%d")}
      dist_raw_dir = DIST_PREFIX + "/raw/" + shoot_time[:year] + "/" + shoot_time[:month] + "/" + shoot_time[:day]
      copy_result = my_copy_file(raw_file, dist_raw_dir)
      if copy_result == false
        copy_result = "nothing to do."
      end
      log.info("#{raw_file} -> #{copy_result}")
    else
      # EXIFデータがない -> コピーしない
      warn("#{raw_file} does not have exif data.")
      log.info("#{file} -> does not have exif data.")
    end
  end
end
