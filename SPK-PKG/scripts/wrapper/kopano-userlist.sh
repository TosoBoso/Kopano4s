#!/bin/sh
# (c) 2018 vbettag - wraper script  to collect users via kopano-adminin Docker container
# admins only plus set sudo for DSM 6 as root login is no longer possible
LOGIN=$(whoami)
if [ "$LOGIN" != "root" ]
then 
	echo "you have to run as root! alternatively as admin run with sudo prefix! exiting.."
	exit 1
fi
echo "k-user, name, email, active, admin, features, store-size, groups, send-as"
# send enter and skip -t as it messes up when called from perl ui
# run kopano-cl command and strip of unneccessary characters, tabs etc
USRLST=$(echo -e "\n" | docker exec -i kopano4s kopano-cli --list-users | grep -v SYSTEM | grep -v Homeserver | grep -v "User list for Default" | grep -v "\-\-\-" | sed "s~^[ \t]*~~" | cut -d " " -f1)

for USR in $USRLST; do
	echo -e "\n" | docker exec -i kopano4s kopano-cli --user $USR >/tmp/kusr
	NAME=$(grep "Full name:" /tmp/kusr | cut -d ":" -f2- | sed "s~^[\t]*~~" | sed "s~^ *~~")
	MAIL=$(grep "Email address:" /tmp/kusr | cut -d ":" -f2- | sed "s~^[\t]*~~" | sed "s~ ~~g")
	ACTIVE=$(grep "Active:" /tmp/kusr | cut -d ":" -f2- | sed "s~^[\t]*~~" | sed "s~ ~~g")
	ADMIN=$(grep "Administrator:" /tmp/kusr | cut -d ":" -f2- | sed "s~^[\t]*~~" | sed "s~ ~~g")
	FEATURES=$(grep "Features:" /tmp/kusr | sed "s~^[\t]*~~" | sed "s~[\t]~:~" | sed "s~[\t]~~g" | sed "s~ ~~g" | cut -d ":" -f2- | sed "s~;~; ~g")
	SENDAS=$(grep "Send-as:" /tmp/kusr | cut -d ":" -f2- | sed "s~^[\t]*~~" | sed "s~ ~~g" | sed "s~,~; ~g")
	SIZE=$(grep "Store size:" /tmp/kusr | cut -d ":" -f2- | sed "s~^[\t]*~~" | sed "s~ ~~g")
	# number of lines for group are indicated in brakets e.g. (2) but we have to add 2 more lines for header, sometimes groups is broken
	GLINES=0
	if grep -q "Groups" /tmp/kusr ; then GLINES=$(grep "Groups" /tmp/kusr | grep -o '(.*)' | sed 's/[()]//g') ; fi
	if [ $GLINES -gt 1 ]
	then 
		GLINES=$(($GLINES  + 2))
		GRPS=$(grep "Groups" -A $GLINES /tmp/kusr | grep -v Groups | grep -v Groupname | grep -v Everyone | grep -v "\-\-\-" | sed "s~[\t]~~g" | sed "s~ ~~g" | tr "\n" ";" | sed "s~;~; ~g")
		# cut of last 2 chars: "; "
		GRPS=${GRPS%?}
		GRPS=${GRPS%?}
	else
		GRPS=""
	fi
	echo "$USR,$NAME,$MAIL,$ACTIVE,$ADMIN,$FEATURES,$SIZE,$GRPS,$SENDAS"
done
if [ -e /tmp/kusr ] ; then rm /tmp/kusr ; fi
