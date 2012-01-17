#!/usr/bin/env ruby193
# -*- coding: utf-8 -*-

require 'optparse'
require 'tmpdir'

# installed by rubygems
require 'sqlite3'               # sqlite3-ruby

# 変数関係の初期化
# target tag_id
tagIds = []

# target photo_id
photoIds = []

# photo data
photos = []

# プログラム引数からわたされる変数の初期化
fspotDB = ENV["HOME"] + "/.config/f-spot/photos.db"
tagsArray = []
ignoreTagsArray = []
outputDir = ""
startUnixtime = 0
endUnixtime = DateTime.strptime(DateTime.now.to_s).strftime("%s").to_i
dryRunFlag = FALSE

# 引数の処理
OptionParser.new do |opts|
  opts.banner = "Usage : import_photo.rb [options]"
  # f-spotのphotos.dbを指定する
  opts.on("-c", "--config file",
          "path to f-spot db file") do |f|
    if File.exists?(f) != true
      puts "[WARN] can\'t find f-spot photos.db : #{f}"
      if File.exists(fspotDB) != true
        puts "[ERROR] can\'t find f-spot photos.db : #{fspotDB}"
        puts "[ERROR] Don\'t you use f-spot ?"
        exit
      end
    end
    fspotDB = f
  end

  # 写真をコピー先の指定
  opts.on("-o", "--output dir",
          "path to output directory") do |d|
    outputDir = d
  end

  # 抽出する写真のtagを指定する (コンマ区切り)
  opts.on("-t", "--tags tag_names",
          "export target tag names with comma separated") do |s|
    tagsArray = s.split(",")
  end

  # 抽出しない写真のtagを指定する (コンマ区切り)
  opts.on("-T", "--ignore-tags tag_names",
          "ignore tag names with comma separated") do |s|
    ignoreTagsArray = s.split(",")
  end
  # 抽出する写真の範囲 (開始日)
  opts.on("-s", "--start day",
          "start day (YYYYMMDD)") do |s|
    startUnixtime = DateTime.strptime(DateTime.strptime(s,"%Y%m%d").to_s).strftime("%s").to_i
  end

  # 抽出する写真の範囲 (終了日)
  opts.on("-e", "--end day",
          "end day (YYYYMMDD)") do |s|
    endUnixtime = DateTime.strptime(DateTime.strptime(s,"%Y%m%d").to_s).strftime("%s").to_i
  end

  # 実際に処理は行わない (dry-run)
  opts.on("-d", "--dry-run") do
    dryRunFlag = TRUE
  end
  opts.parse!(ARGV)
end # end of OptionParser

# 出力先の処理
if outputDir == "" && dryRunFlag == FALSE
  outputDir = Dir.mktmpdir("import_photo","/tmp")
end
if Dir.exists?(outputDir) != TRUE
  puts "[WARN] can\'t find output directory : #{outputDir}"
  if dryRunFlag == FALSE
    puts "[INFO] mkdir : #{outputDir}"
    FileUtils.mkdir_p(outputDir)
  end
end

# 起動情報の出力
if dryRunFlag == FALSE
  require 'RMagick'               # rmagick
else
  puts "[INFO] switch dry run mode"
end
puts "[INFO] f-spot\'s photos.db : #{fspotDB}"
puts "[INFO] output directory : #{outputDir}"
startDay = DateTime.strptime(startUnixtime.to_s, "%s").strftime("%Y/%m/%d")
endDay = DateTime.strptime(endUnixtime.to_s, "%s").strftime("%Y/%m/%d")
puts "[INFO] export scope : #{startDay} - #{endDay}"

db = SQLite3::Database.new(fspotDB)

# タグIDの抽出
tmpTagName = ""
if tagsArray.length == 0
  sqlStr = "SELECT `id` FROM tags"
  tmpTagName = "ALL"
else
  tmpStr = ""
  sqlStr = "SELECT `id` FROM tags WHERE ( "
  # 抽出対象のタグ
  tagsArray.each do |i|
    tmpTagName = tmpTagName + "#{i}, "
    tmpStr = tmpStr + "`name` = '#{i}' or "
  end
  # ゴミ掃除
  tmpTagName = tmpTagName.gsub(/, $/,"")
  sqlStr = sqlStr +  tmpStr.gsub(/or $/,"")
  # 抽出対象外のタグ
  if ignoreTagsArray.length > 0
    sqlStr = sqlStr + " and "
    tmpStr = ""
    ignoreTagsArray.each do |i|
      tmpStr = tmpStr + "`name` != '#{i}' and "
    end
    sqlStr = sqlStr + tmpStr.gsub(/and $/,"")
  end
  sqlStr = sqlStr + ")"
end
db.execute(sqlStr).each do |i|
  tagIds << i[0]
end
puts "[INFO] target tags : #{tmpTagName}"

# tagIdsが登録されているphoto_idの抽出
sqlStr = "SELECT `photo_id` FROM photo_tags WHERE ( `tag_id` = :tag_id )"
tagIds.each do |i|
  db.execute(sqlStr, { :tag_id => i }).each do |j|
    photoIds << j[0]
  end
end
photoIds = photoIds.uniq

# 写真データ(photos)の抽出
sqlStr = "SELECT `filename`,`base_uri`,`time` FROM photos WHERE ( `id` = :photo_id and `time` >= #{startUnixtime} and `time` <= #{endUnixtime} ) LIMIT 1"
photoIds.each do |photo_id|
  db.execute(sqlStr, { :photo_id => photo_id }).each do |photo|
    tmp = { :filename => photo[0], :path => photo[1], :time => photo[2] }
    tmp[:filename] = tmp[:filename].force_encoding('UTF-8')
    tmp[:path] = tmp[:path].force_encoding('UTF-8').gsub(/^file:\/\//, "")
    tmp[:time] = DateTime.strptime(tmp[:time].to_s, '%s').new_offset('+09:00')
    photos << tmp
  end
end
puts "[INFO] target photo data : #{photos.length}"
# f-spotのDBを使うのはここまで
db.close
if dryRunFlag == TRUE
  exit
end

# 写真データのコピー
photos.each do |photo|
  # format YYYY_MM_DD_orig-filename
  tmpDateHash = DateTime._strptime(photo[:time].to_s)
  tmpOutputFilename = tmpDateHash[:year].to_s + "_" + tmpDateHash[:mon].to_s + "_" + tmpDateHash[:mday].to_s + "_" + photo[:filename].downcase
  tmpOutputPath = outputDir + "/" + tmpOutputFilename
  if File.exist?(tmpOutputPath) == FALSE
    tmpInputPath = photo[:path] + "/" + photo[:filename]
    tmpImgObj = Magick::Image.read(tmpInputPath).first
    tmpImgObj.resize_to_fit!(2048,2048)
    tmpImgObj.write(tmpOutputPath)
  end
end
