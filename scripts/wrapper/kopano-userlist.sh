#!/bin/sh
# (c) 2018 vbettag - wraper script  to collect users via kopano-adminin Docker container
# admins only plus set sudo for DSM 6 as root login is no longer possible
LOGIN=`whoami`
MAJOR_VERSION=`grep majorversion /etc.defaults/VERSION | grep -o [0-9]`
if [ $LOGIN != "root" ]
then 
	echo "you have to run as root! alternatively as admin run with sudo prefix! exiting.."
	exit 1
fi
echo "k-user, name, email, active, admin, features, store-size, groups, send-as"
# send enter and skip -t as it messes up when called from perl ui
# run kopano admin command and strip of unneccessary tabs etc
USRLST=`echo -e "\n" | docker exec -i kopano4s kopano-admin -l | grep -v SYSTEM | grep -v Homeserver | grep -v "User list for Default" | grep -v "\-\-\-" | sed "s~^[ \t]*~~" | cut -d "	" -f1`
for USR in $USRLST; do
	echo -e "\n" | docker exec -i kopano4s kopano-admin --details $USR >/tmp/kusr
	NAME=`grep Fullname /tmp/kusr | cut -d ":" -f2- | sed "s~^[\t]*~~"`
	MAIL=`grep Emailaddress /tmp/kusr | cut -d ":" -f2- | sed "s~^[\t]*~~"`
	ACTIVE=`grep Active /tmp/kusr | cut -d ":" -f2- | sed "s~^[\t]*~~"`
	ADMIN=`grep Administrator /tmp/kusr | cut -d ":" -f2- | sed "s~^[\t]*~~"`
	SIZE=`grep size /tmp/kusr | cut -d ":" -f2- | sed "s~^[\t]*~~"`
	FON=`grep ENABLED_FEATURES /tmp/kusr | sed "s~^[\t]*~~" | sed "s~[\t]~:~" | sed "s~[\t]~~g" | sed "s~ ~~g" | cut -d ":" -f2- | sed "s~;~; ~g"`
	FOFF=`grep DISABLED_FEATURES /tmp/kusr | sed "s~^[\t]*~~" | sed "s~[\t]~:~" | sed "s~[\t]~~g" | sed "s~ ~~g" | cut -d ":" -f2- | sed "s~;~; ~g"`
	GLINES=`grep Groups /tmp/kusr | grep -o '(.*)' | sed 's/[()]//g'`
	GROUPS=""
	SENDAS=""
	if [ "_$GLINES" != "_" ] && [ $GLINES -gt 0 ]
	then 
		GROUPS=`grep Groups -A $GLINES /tmp/kusr | grep -v Groups | sed "s~^[\t]*~~g" | tr '\n' ';'`
	fi
	echo -e "\n" | docker exec -i kopano4s kopano-admin --list-sendas $USR >/tmp/kusr
	SLINES=`grep Send-as /tmp/kusr | grep -o '(.*)' | sed 's/[()]//g'`
	if [ "_$SLINES" != "_" ] && [ $SLINES -gt 0 ]
	then
		LINES=$(expr $SLINES + "2")
		# grep nlines for username and fullname then split by 1st tab to keep username and remove last ;
		SENDAS=`grep Send-as -A $LINES /tmp/kusr | grep -v Send-as | grep -v Username | grep -v "\-\-\-" | sed "s~^[\t]*~~g" | cut -d "	" -f1 | tr '\n' ';'`
		SENDAS=${SENDAS%?}
	fi
	echo "$USR,$NAME,$MAIL,$ACTIVE,$ADMIN,on:$FON; off:$FOFF,$SIZE,${GROUPS%?},$SENDAS"
done
if [ -e /tmp/kusr ] ; then rm /tmp/kusr ; fi
