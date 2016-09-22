#!/bin/bash

# Run this file to convert Sakai wiki articles to Redmine Wiki. 
# Images need to have be logged into Sakai to view them. 

function usage() {
	echo "$0"
	echo ""
	echo " Run this file to convert Sakai wiki articles to Redmine Wiki." 
	echo " Images need to have be logged into Sakai to view them. "
	echo ""
	echo " /bin/bash $0 ./path/to/file_with_sakai_wiki_text.tmp"
	echo ""	
}

TEXTFILE=$1
if [ "$TEXTFILE" == "" ]; then
	usage
	exit
fi
# add a line break after heading lines that don't have one
# Grep out the heading and following line to a temp file
cat $TEXTFILE | grep -E '^h[1-4] ' -A1 | grep -v '\-\-' > /tmp/tt
cat $TEXTFILE | grep -E '^h[1-4]. ' -A1 | grep -v '\-\-' >> /tmp/tt
cp /tmp/tt /tmp/tt_

# Read the tmp file to determine if there are blank lines or not. If not, grep the h line
# text in the original file and replace the h line with an extra new line.
while read line1 && read line2; do 
	HLINE=$line1; 
	if [[ "$line2" == "" ]]; then 
		continue; 
	else 
		# found a line too close. Replacing it with new line
		cat $TEXTFILE | awk '{sub(/'"$HLINE"'/,"'"$HLINE"'""\n"); print }' > /tmp/ttt
		cp /tmp/ttt $TEXTFILE
	fi 
done < /tmp/tt;
 
# the newlines in sakai wiki are inject by \\ replace them with <br>
sed -i '.sed.bak' 's|\\\\|\
|g' $TEXTFILE


# Change header declarations "hx" to "hx." 
sed -i '.sed.bak' 's/h\([1-4]\) /h\1\. /g' $TEXTFILE

# Replace bolds syntax __ with *
sed -i '.sed.bak' 's/ __/ */g' $TEXTFILE
sed -i '.sed.bak' 's/__ /* /g' $TEXTFILE
sed -i '.sed.bak' 's/^__/*/g' $TEXTFILE

# Redmine only supports bare http://link or "link text":http://link for external stuff.
# Write all Sakai {link:link text:http://link ...} links to a tmp file
sed -n "s/.*{link:\(.*\)}.*/\1/p"  "$TEXTFILE"  | sed -e "s/\(.*\)/{link:\1}/" > /tmp/links

# Read each one and recreate a redmine link
while read SLINK; do 
	LINKTEXT=$(echo $SLINK | sed -n "s/.*{link:\(.*\)|http.*/\1/p"); 
	#echo "replace:$SLINK"; 
	LINK=$(echo $SLINK | sed -n "s/.*|http\(.*\)|img.*/\1/p"); 
	#echo "link: \"$LINKTEXT\":http$LINK"; 
	sed -i '.sed.bak' "s^$SLINK^\"$LINKTEXT\":http$LINK^" $TEXTFILE; 
done < /tmp/links

# Redmine page links have two brace, compared to Sakai one brace.
sed -i '.sed.bak' 's/\[/\[\[/g' $TEXTFILE
sed -i '.sed.bak' 's/\]/\]\]/g' $TEXTFILE



# Redmine only supports bare img http://link for external pictures.
# Write all Sakai {image:sakai links ...} links to a tmp file
sed "s/.*{image:\(.*\)}.*/\1/g" $TEXTFILE | sed -e "s/\(.*\)/{image:\1}/" > /tmp/links

# Read each one and recreate a redmine link
while read SLINK; do 
	if [[ "$SLINK" == *"|"* ]]; then 
		# complex link includes alt text and size manipulation
		# extract the parts as listed. 
		#echo "complex: $SLINK"
		SIZE=
		# Seems there are two types of image link around.
		TMP=$(echo $SLINK  |awk -F'style="width:' '{print $2}')
		if [ "$TMP" == "" ]; then
			TMP=$(echo $SLINK  |awk -F'|' '{print $4}' | sed 's/img//' | sed 's/}/px}/')
		fi
		
		if [ "$TMP" != "" ]; then
		
			SIZE="{width:$TMP"
		fi
		#echo "img size: $SIZE"
		# Get the image url	
		echo "$SLINK" | grep -q 'image:sakai'
		if [ $? -eq 0 ]; then 	
			TMP=$(echo $SLINK | awk -F'|' '{print $1}' | sed 's^{image:sakai:/^https://content.sakai.rutgers.edu/access/content/group/^')
		else 
			TMP=$(echo $SLINK | awk -F'|' '{print $1}' | sed 's^{image:worksite:/^https://content.sakai.rutgers.edu/access/content/group/2c931bd8-291c-46bf-b196-24ce8329528a^')
		fi
		URL=$(echo "$TMP" | sed 's^ ^%20^g')	
		
		# Image alt text
		ALT=$(echo $SLINK | awk -F'|' '{print $2}')
		RLINK="!${SIZE}${URL}(${ALT})!:$URL"
		#echo "r-complex: $RLINK"
		
	else
		# Link with out special format
		# Replace {image:sakai:/ with the real url
		#echo "simple: $SLINK"
		TMP=$(echo "$SLINK" | sed 's^{image:sakai:/^!https://content.sakai.rutgers.edu/access/content/group/^')
		RLINK=$(echo "$TMP" | sed 's^}^!^' | sed 's^ ^%20^g')
		URL=$(echo "$RLINK"	| sed 's^!^^')	
		RLINK+=":$URL"
		#echo "r-simple: $RLINK:$URL"
	fi
	
	# Replace the image url texts in the original file
	sed  -i '.sed.bak' "s^$SLINK^$RLINK^" $TEXTFILE; 
done < /tmp/links


# Occaisional {code} tags
sed -i '.sed.bak' "s/{code}\([aA-zZ]\)/<pre><code>\1/g" "$TEXTFILE"
sed -i '.sed.bak' "s/{code}/<\/code><\/pre>/g" "$TEXTFILE"
	
# Hand out some converted text to be copied and pasted into redmine.
echo Paste below into Redmine
echo
echo
cat $TEXTFILE
echo
echo
echo Past text above into Redmine


#cat $TEXTFILE | sed 's/h1 /h1\. /g' > /tmp/wt1
#cat /tmp/wt1 | sed 's/h2 /h2\. /g' > /tmp/wt2
#cat /tmp/wt2 | sed 's/h/h3\. /g' > /tmp/wt1
#cat /tmp/wt2
#cat /tmp/wt1
