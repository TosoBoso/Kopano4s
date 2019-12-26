#!/bin/sh
# (c) 2018-19 vbettag - wraper script collecting kopano-groups in Docker container
# admins and docker members only otherwise set sudo for DSM 6 as root login is no longer possible
LOGIN=$(whoami)
if [ "$LOGIN" != "root" ] && ! (grep administrators /etc/group | grep -q "$LOGIN") && ! (grep docker /etc/group | grep -q "$LOGIN")
then 
	echo "you have to run as root or $LOGIN be a member of administrators and docker group; alternatively run with sudo prefix; exiting.."
	exit 1
fi
echo "k-group, email, send-as"
# send enter and skip -t as it messes up when called from perl ui
# run kopano admin command and strip of unneccessary tabs etc
GRPLST=$(echo -e "\n" | docker exec -i kopano4s kopano-cli --list-groups 2>&1 | grep -v Groupname | grep -v "Group list for Default" | grep -v "\-\-\-" | sed "s~^[ \t]*~~" | cut -d "	" -f1)
if $(echo $GRPLST | grep -q "Error") || $(echo $USRLST | grep -q "[crit")
then
	echo "error pls check kopano-cli --list-groups on cmd-line"
	exit 1
fi
for GRP in $GRPLST; do
	echo -e "\n" | docker exec -i kopano4s kopano-cli --group $GRP >/tmp/kgrp
	MAIL=$(grep "Email address:" /tmp/kgrp | cut -d ":" -f2- | sed "s~^[ \t]*~~")
	SENDAS=$(grep "Send-as:" /tmp/kgrp | cut -d ":" -f2- | sed "s~^[\t]*~~" | sed "s~ ~~g" | sed "s~,~; ~g")
	echo "$GRP,$MAIL,$SENDAS"
done
if [ -e /tmp/kgrp ] ; then rm /tmp/kgrp ; fi
