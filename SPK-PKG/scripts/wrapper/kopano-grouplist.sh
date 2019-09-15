#!/bin/sh
# (c) 2017 vbettag - wraper script collecting kopano-groups in Docker container
LOGIN=$(whoami)
if [ "$LOGIN" != "root" ]
then 
	echo "you have to run as root! alternatively as admin run with sudo prefix! exiting.."
	exit 1
fi
echo "k-group, email, send-as"
# send enter and skip -t as it messes up when called from perl ui
# run kopano admin command and strip of unneccessary tabs etc
GRPLST=$(echo -e "\n" | docker exec -i kopano4s kopano-cli --list-groups | grep -v Groupname | grep -v "Group list for Default" | grep -v "\-\-\-" | sed "s~^[ \t]*~~" | cut -d "	" -f1)
for GRP in $GRPLST; do
	echo -e "\n" | docker exec -i kopano4s kopano-cli --group $GRP >/tmp/kgrp
	MAIL=$(grep "Email address:" /tmp/kgrp | cut -d ":" -f2- | sed "s~^[ \t]*~~")
	SENDAS=$(grep "Send-as:" /tmp/kgrp | cut -d ":" -f2- | sed "s~^[\t]*~~" | sed "s~ ~~g" | sed "s~,~; ~g")
	echo "$GRP,$MAIL,$SENDAS"
done
if [ -e /tmp/kgrp ] ; then rm /tmp/kgrp ; fi
