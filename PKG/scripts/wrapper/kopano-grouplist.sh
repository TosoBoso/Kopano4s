#!/bin/sh
# (c) 2017 vbettag - wraper script collecting kopano-groups in Docker container
LOGIN=`whoami`
MAJOR_VERSION=`grep majorversion /etc.defaults/VERSION | grep -o [0-9]`
if [ $LOGIN != "root" ]
then 
	echo "you have to run as root! alternatively as admin run with sudo prefix! exiting.."
	exit 1
fi
echo "k-group, email, send-as"
# send enter and skip -t as it messes up when called from perl ui
# run kopano admin command and strip of unneccessary tabs etc
GRPLST=`echo -e "\n" | docker exec -i kopano4s kopano-admin -L | grep -v groupname | grep -v "Group list for Default" | grep -v "\-\-\-" | sed "s~^[ \t]*~~" | cut -d "	" -f1`
for GRP in $GRPLST; do
	echo -e "\n" | docker exec -i zarafa4h zarafa-admin --type group --details $GRP >/tmp/kgrp
	MAIL=`grep Emailaddress /tmp/kgrp | cut -d ":" -f2- | sed "s~^[ \t]*~~"`
	SENDAS=""
	echo -e "\n" | docker exec -i zarafa4h zarafa-admin --type group --list-sendas $GRP >/tmp/kgrp
	SLINES=`grep Send-as /tmp/kgrp | grep -o '(.*)' | sed 's/[()]//g'`
	if [ "_$SLINES" != "_" ] && [ $SLINES -gt 0 ]
	then
		LINES=$(expr $SLINES + "2")
		# grep nlines for username and fullname then split by 1st tab to keep username and remove last ;
		SENDAS=`grep Send-as -A $LINES /tmp/kgrp | grep -v Send-as | grep -v Username | grep -v "\-\-\-" | sed "s~^[ \t]*~~g" | cut -d "	" -f1 | tr '\n' ';'`
		SENDAS=${SENDAS%?}
	fi
	echo "$GRP,$MAIL,$SENDAS"
done
if [ -e /tmp/kgrp ] ; then rm /tmp/kgrp ; fi
