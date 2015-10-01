#!/bin/bash

# author:	Marcel Petrick (mail@marcelpetrick.it)
#
# about:	script to rescale and combine and negative-convert all HDR-TIFF-files in one directory
#			into a fixed-layout-overview which resembles an old "contact sheet"
#
# license:	GNU General Public License v3.0 (see attached gpl-3.0.txt)
# version:	0.4 (add original filename in the bottom right corner; modified data-flow (now negfix8 on each thumbnail instead of the combined one); no filling of the last row anymore; added help, version and the parameter for "no negative conversion"; added the current base-directory as footer to the final "contactSheet.png")
# date:		20150614
#
# history:
#			0.3 (solved the issue with filenames with spaces; some other minor code improvements)
#			0.2 (added "just extract the first layer"; minor code-structure-improvements)
#			0.1 (initial release; basic workflow implemented)

VERSION=0.4

if [ $1 = "-version" ]; then
	echo "running version $VERSION"
	exit 1
fi

if [ $1 = "-help" ]; then
	echo "0. navigate into the directory which contains the TIFF-negative-files"
	echo "1. execute the shellscript"
	echo "2. check for the result file \"combinedSheet.png\""
	echo ""
	echo "available parameters are -version; -help and -p (no negative conversion). They are NOT combineable!"
	exit 1
fi

#check if a negative conversion was wanted or not
DONEGATIVECONVERSION=1
if [ $1 = "-p" ]; then
	DONEGATIVECONVERSION=0
fi

echo "############################ start of the script ############################"

#handle the issue with filenames with spaces
SAVEIFS=$IFS
IFS=$(echo -en "\n\b")

#needed for the call of negfix8
SKRIPTDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

########################################################################################################################
############## create thumbnails first - currently with fixed size of 400px for the longer side
printf "\nCreate all thumbnails first - currently with fixed size of 400px for the longer side\n"

#disable the following line to skip the first step for faster debugging
ALLFILES=`ls *.tif` #get all files inside the current folder which fit by suffix
#printf "\nALLFILES for conversion:\n$ALLFILES\n"

WORKINGDIR="0workingDir" #pre-fixed with 0 to make it appear on top of the file-view
mkdir $WORKINGDIR

for FILE in $ALLFILES
do
	CLEANEDNAME="${FILE// /_}" #also alter the original-input-name by replacing all spaces, because convert does not like this for the apppend-operation
	echo "will work now on #$FILE# and save as #$CLEANEDNAME#" #print current file name
	convert -resize "400x400>" $FILE"[0]" $WORKINGDIR"/"$CLEANEDNAME".png" #create all thumbnails: works just on the first layer

if [ $DONEGATIVECONVERSION = 1 ]; then
	#convert negative
	echo "negative conversion"
	FULLPATH=$WORKINGDIR"/"$CLEANEDNAME"_n8.png"
	/bin/bash $SKRIPTDIR/negfix8.sh -cs $WORKINGDIR"/"$CLEANEDNAME".png" $FULLPATH
	rm $WORKINGDIR"/"$CLEANEDNAME".png"  #delete afterwards
else
	echo "no negative conversion"
	FULLPATH=$WORKINGDIR"/"$CLEANEDNAME".png"
fi

	#annotate with original filename
	echo "annotate with original filename now ..."
	convert $FULLPATH -gravity SouthEast -pointsize 22 -fill yellow -annotate +10+10  $FILE $FULLPATH
done

IFS=$SAVEIFS #recover the original state (means: separate on space)

########################################################################################################################
############### Append first rows all rows
ROWSIZE=6 #number of pictures per row! #is a constant ... open for discussion
printf "\nAppend first the thumbnails to rows with size $ROWSIZE \n"

ALLFILES=`ls $WORKINGDIR/*.png` #make it png
#printf "\nALLFILES is for horizontal apppending:\n$ALLFILES\n"

APPENDDIR="1appendendStripsDir" #pre-fixed with 1 to make it appear on top of the file-view
mkdir $APPENDDIR

TOADD="" #contain the working set of files for appending
APPENDEDSTRIPS="" #contain the intermediate strips
COUNTER=0
FILECOUNTER=0
LASTFILE=""

for FILE in $ALLFILES
do
#	echo "COUNTER == $COUNTER"
	LASTFILE=$FILE

	if (($COUNTER == $ROWSIZE)); then
		echo "combine now! content: $TOADD"		
  		convert $TOADD +append $APPENDDIR/"combined"$FILECOUNTER".png" #combine it into one long column
		((FILECOUNTER+=1))
		COUNTER=0 #reset
		TOADD=""
	fi

	#the regular append of the filename
	TOADD=$TOADD" $FILE"
	((COUNTER+=1))
done

########################################################################################################################
############### if TOADD not empty, then add another strip
printf "\nCheck now if the last row has to be forcefully ejected\n"

if [ -n "$TOADD" ]; then
    echo "TOADD not empty ..."
    convert $TOADD +append $APPENDDIR/"combined"$FILECOUNTER".png"
fi

########################################################################################################################
############### combine now the strips to the whole thing
printf "\nCombine now the horizontal strips into the complete contact sheet\n"

ALLFILES=`ls $APPENDDIR/*.png`
#printf "\nALLFILES is for vertical apppending:\n$ALLFILES\n"
TOADD=""

echo "$ALLFILES"

for FILE in $ALLFILES
do
	TOADD=$TOADD" $FILE"
done

#make the final apppend of all rows
printf "\nDo now the final combine into a single sheet..\n"
OUTPUTNAME="contactSheet.png"
convert $TOADD -append $OUTPUTNAME

########################################################################################################################
############### append a footer-text with the current base-dir-name (which is for my workflow also the film-info)
printf "\nAppend a footer-text with the current base-dir-name (which is for my workflow also the film-info)\n"

#get the current base directory
BASEDIR=${PWD##*/}
#echo "basedir: $BASEDIR"
convert $OUTPUTNAME -gravity South -pointsize 22 -splice 0x18 -annotate +0+2 "$BASEDIR" $OUTPUTNAME

########################################################################################################################
############### clean the output - maybe add this as a switch to the call-params
printf "\nClean the output..\n"

DELME=1 #set to 0 for debugging reasons
if [ $DELME = 1 ]; then
	printf "\nClean now the temporary working files\n"
	rm -R $WORKINGDIR
	rm -R $APPENDDIR
fi

printf "### Everything is finished: check for the \"contactSheet.png\". If missing, check for errors ;) ###\n"

printf "############################ end of the script ############################\n"

