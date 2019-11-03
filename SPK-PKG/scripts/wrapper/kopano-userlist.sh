#!/bin/sh
# (c) 2018-19 vbettag - wraper script  to collect users via kopano-adminin Docker container
# admins and docker members only otherwise set sudo for DSM 6 as root login is no longer possible
LOGIN=$(whoami)
if [ "$LOGIN" != "root" ] && ! (grep administrators /etc/group | grep -q "$LOGIN") && ! (grep docker /etc/group | grep -q "$LOGIN")
then 
	echo "you have to run as root or $LOGIN be a member of administrators and docker group; alternatively run with sudo prefix; exiting.."
	exit 1
fi
echo "k-user, name, email, active, admin, features, store-size, groups, send-as"
# send enter and skip -t as it messes up when called from perl ui
# run kopano-cl command and strip of unneccessary characters, tabs etc
if grep -q Migration /var/packages/Kopano4s/etc/package.cfg
then
	# run kopano-admin inmigration version as kopano-cli sometimes does not work
	USRLST=$(echo -e "\n" | $SUDO docker exec -i kopano4s kopano-admin --list-users 2>&1 | grep -v SYSTEM | grep -v Homeserver | grep -v "User list for Default" | grep -v "\-\-\-" | sed "s~^[ \t]*~~" | cut -d "	" -f1)
	if $(echo $USRLST | grep -q "Error") || $(echo $USRLST | grep -q "[crit")
	then
		echo "error pls check kopano-admin --list-users on cmd-line"
		exit 1
	fi
	for USR in $USRLST; do
		echo -e "\n" | $SUDO docker exec -i kopano4s kopano-admin --details $USR >/tmp/kusr
		NAME=$(grep Fullname /tmp/kusr | cut -d ":" -f2- | sed "s~^[\t]*~~")
		MAIL=$(grep Emailaddress /tmp/kusr | cut -d ":" -f2- | sed "s~^[\t]*~~")
		ACTIVE=$(grep Active /tmp/kusr | cut -d ":" -f2- | sed "s~^[\t]*~~")
		ADMIN=$(grep Administrator /tmp/kusr | cut -d ":" -f2- | sed "s~^[\t]*~~")
		SIZE=$(grep size /tmp/kusr | cut -d ":" -f2- | sed "s~^[\t]*~~")
		FON=$(grep ENABLED_FEATURES /tmp/kusr | sed "s~^[\t]*~~" | sed "s~[\t]~:~" | sed "s~[\t]~~g" | sed "s~ ~~g" | cut -d ":" -f2-)
		FOFF=$(grep DISABLED_FEATURES /tmp/kusr | sed "s~^[\t]*~~" | sed "s~[\t]~:~" | sed "s~[\t]~~g" | sed "s~ ~~g" | cut -d ":" -f2-)
		GLINES=$(grep Groups /tmp/kusr | grep -o '(.*)' | sed 's/[()]//g')
		GROUPS=""
		SENDAS=""
		if [ "_$GLINES" != "_" ] && [ $GLINES -gt 0 ]
		then 
			GROUPS=$(grep Groups -A $GLINES /tmp/kusr | grep -v Groups | sed "s~^[\t]*~~g" | tr '\n' ';')
		fi
		echo -e "\n" | docker exec -i kopano4s kopano-admin --list-sendas $USR >/tmp/kusr
		SLINES=$(grep Send-as /tmp/kusr | grep -o '(.*)' | sed 's/[()]//g')
		if [ "_$SLINES" != "_" ] && [ $SLINES -gt 0 ]
		then
			LINES=$(expr $SLINES + "2")
			# grep nlines for username and fullname then split by 1st tab to keep username and remove last ;
			SENDAS=$(grep Send-as -A $LINES /tmp/kusr | grep -v Send-as | grep -v Username | grep -v "\-\-\-" | sed "s~^[\t]*~~g" | cut -d "	" -f1 | tr '\n' ';')
			SENDAS=${SENDAS%?}
		fi
		echo "$USR,$NAME,$MAIL,$ACTIVE,$ADMIN,on:$FON;off:$FOFF,$SIZE,${GROUPS%?},$SENDAS"
	done
else
	USRLST=$(echo -e "\n" | docker exec -i kopano4s kopano-cli --list-users 2>&1 | grep -v SYSTEM | grep -v Homeserver | grep -v "User list for Default" | grep -v "\-\-\-" | sed "s~^[ \t]*~~" | cut -d " " -f1)	
	if $(echo $USRLST | grep -q "Error") || $(echo $USRLST | grep -q "[crit")
	then
		echo "error pls check kopano-cli --list-users on cmd-line"
		exit 1
	fi
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
fi
if [ -e /tmp/kusr ] ; then rm /tmp/kusr ; fi
