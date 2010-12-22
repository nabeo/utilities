#!/bin/sh
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/X11R6/bin:/usr/local/bin:/usr/local/sbin

displayError() {
	echo "\$DISPLAY: parameter not set."
	echo "I can't open display."
	exit 1
}
displayDetect() {
	if [ ! "$DISPLAY" ]; then
		if [ "$SSH_CONNECTION" ]; then
			remoteHost=`echo $SSH_CONNECTION | awk '{print $1}'`
			echo "Do you use remote host's display ?"
			echo "use remote host's display (X11 forwarding): 1"
			echo "try without remote host's display (html file only): 2"
			echo "exit program : 3"
			echo -n "[1, 2, 3]: "
			read useFlag
			case $useFlag in
				1)
					DISPLAY=$remoteHost:0.0
				;;
				3)
				displayError
				;;
			esac
		else
			displayError
		fi
	fi
}

textFileDetect() {
	textFile="$1"
	lineNum="`wc -l $textFile | awk -F\   '{print $1}'`"
	if [ $lineNum -lt 15 ]; then
		exec cat $textFile
	else
		exec cat $textFile | lv
	fi
}

archiveFileDetect() {
	archiveFile="$1"
	unset flag
	echo "detect archive file"
	echo "please selct from follow"
	echo "1 : decmopress"
	echo "2 : list files"
	echo "3 : do nothing (default)"
	echo -n "[1, 2, 3]: "
	read flag
	case $archiveFile in
		*.tar.bz2)
			case $flag in
				1)
					tar xjf $archiveFile
				;;
				2)
					tar jvtf $archiveFile | lv 
				;;
				*)
				;;
			esac
		;;
		*.tar.gz)
			case $flag in
				1)
					tar xzf $archiveFile
				;;
				2)
					tar zvtf $archiveFile | lv 
				;;
				*)
				;;
			esac
		;;
		*.bz2)
			echo $archiveFile
		;;
		*.gz)
			echo $archiveFile
		;;
		*.lha)
			echo $archiveFile
		;;
		*)
			echo "unknown archive file type."
		;;
	esac
}

fileType="`file $1 | awk -F:\   '{print $2}'`"
case "$fileType" in
	"Microsoft ASF"|"RIFF"*|*"XviD"*|"ISO Media"|"MPEG sequence, v1, system multiplex")
		displayDetect
		DISPLAY=$DISPLAY exec gxine "$1"
	;;
	"directory")
		displayDetect
		exec nautilus --no-desktop --no-default-window --browser --display=$DISPLAY "$1"
	;;
	"ELF 32-bit LSB executable"*)
		exec "$1"
	;;
	"JPEG image data"*|"GIF image data"*|"PNG image data"*|"PNG image"*)
		displayDetect
		exec gthumb --display=$DISPLAY --new-window "$1"
	;;
	"RPM"*)
		exec rpm -qpli "$1" | lv
	;;
	*"compressed"*)
		archiveFileDetect "$1"
	;;
	"HTML document text")
		displayDetect
		if [ "$DISPLAY" ]; then
			DISPLAY=$DISPLAY exec w3m "$1"
		else
			exec w3m "$1"
		fi
	;;
	*"text"*|"XML")
		textFileDetect "$1"
	;;
	"PDF document"*)
		displayDetect
		which gv > /dev/null 2>& 1
		if [ $? -eq 0 ]; then
			DISPLAY=$DISPLAY exec gv "$1"
		else
			DISPLAY=$DISPLAY exec acroread "$1"
		fi
	;;
	"TrueType font data")
		gnome-font-viewer "$1"
	;;
	"GIMP XCF image data"*)
		gimp "$1"
	;;
	*)
		echo "I can't process this file."
		echo "$fileType"
	;;
esac

