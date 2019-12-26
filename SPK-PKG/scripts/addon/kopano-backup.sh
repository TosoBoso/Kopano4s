#!/bin/sh
# (c) 2018-19 vbettag - wraper script for kopano-backup in Docker container
# admins and docker members only otherwise set sudo for DSM 6 as root login is no longer possible
LOGIN=$(whoami)
if [ "$LOGIN" != "root" ] && ! (grep administrators /etc/group | grep -q "$LOGIN") && ! (grep docker /etc/group | grep -q "$LOGIN")
then 
	echo "you have to run as root or $LOGIN be a member of administrators and docker group; alternatively run with sudo prefix; exiting.."
	exit 1
fi
# get the K_NOTIFY and K_BACKUP_PATH to list directories in backup folder which are linked to users
. /var/packages/Kopano4s/etc/package.cfg
if [ -e /usr/local/mariadb10/bin/mysql ]
then
	MYSQL="/usr/local/mariadb10/bin/mysql"
else 
	MYSQL="/bin/mysql"
fi
if ( (! echo "$@" | grep -q "\-U") || (! echo "$@" | grep -q "\-P") && echo "$@" | grep -q "\-s")
then 
	echo "when using socket -s provide an admin user and pwd via -U -P; see --help"
fi
STARTTIME=$(date +%s)
# send enter and skip -t as it messes up when called from perl ui plus collect stderror on stdout
echo -e "\n" | docker exec -i kopano4s  kopano-backup "$@" 2>&1
if (! echo "$@" | grep -q "\-h" )
then
	ENDTIME=$(date +%s)
	DIFFTIME=$(( $ENDTIME - $STARTTIME ))
	TASKTIME="$(($DIFFTIME / 60)) : $(($DIFFTIME % 60)) min:sec."
	if (! echo "$@" | grep -q "\-\-restore" )
	then
		MSG="Kopano brick level backup completed in $TASKTIME.."
	else
		if (! echo "$@" | grep -q "\-\-only-meta" )
		then		
			MSG="Kopano backup-restore completed in $TASKTIME.."
		else
			MSG="Kopano backup-restore meta completed in $TASKTIME.."		
		fi
	fi
	echo "$MSG"
	if [ -n "$NOTIFY" ] && [ "$NOTIFY" = "ON" ]
	then
		/usr/syno/bin/synodsmnotify $NOTIFYTARGET Kopano-Backup "$MSG"
	fi
fi
if (! echo "$@" | grep -q "\-\-restore" && !  echo "$@" | grep -q "\-h" )
then
	USRLIST=$(find $K_BACKUP_PATH -maxdepth 1 -mindepth 1 -type d -exec basename {} \;)
	BUP_USRS=""
	for USR in $USRLIST; do
	# is it a real backup directory then user control file has to exist
	if [ -e "$K_BACKUP_PATH/$USR/user" ] && echo -e "\n" | docker exec -i kopano4s kopano-cli --list-users | grep -v SYSTEM | grep -v Homeserver | grep -v "User list for Default" | grep -v "\-\-\-" | grep -q $USR
	then
		# creating the files as root in container and giving 666 and later 644
		echo -e "\n" | docker exec -i kopano4s touch "$USR"/user-details
		echo -e "\n" | docker exec -i kopano4s touch "$USR"/user-ph
		echo -e "\n" | docker exec -i kopano4s chmod 666 "$USR"/user-details
		echo -e "\n" | docker exec -i kopano4s chmod 666 "$USR"/user-ph
		# collecting user-details and gropp-details beyon Everybody plus hased pwd
		echo -e "\n" | docker exec -i kopano4s kopano-cli --user $USR > "$K_BACKUP_PATH/$USR/user-details"
		GLINES=0
		if grep -q "Groups" "$K_BACKUP_PATH/$USR/user-details" ; then GLINES=$(grep "Groups" "$K_BACKUP_PATH/$USR/user-details" | grep -o '(.*)' | sed 's/[()]//g') ; fi
		if [ $GLINES -gt 1 ]
		then 
			GLINES=$(($GLINES  + 2))
			GRPLIST=$(grep "Groups" -A $GLINES "$K_BACKUP_PATH/$USR/user-details" | grep -v Groups | grep -v Groupname | grep -v Everyone | grep -v "\-\-\-" | sed "s~[\t]~~g" | sed "s~ ~~g")
			for GRP in $GRPLIST; do
				echo -e "\n" | docker exec -i kopano4s touch "$USR/grp-${GRP}-details"
				echo -e "\n" | docker exec -i kopano4s chmod 666 "$USR/grp-${GRP}-details"
				echo -e "\n" | docker exec -i kopano4s kopano-cli --group $GRP > "$K_BACKUP_PATH/$USR/grp-${GRP}-details"
				echo -e "\n" | docker exec -i kopano4s chmod 644 "$USR/grp-${GRP}-details"
			done
		fi
		SQL="select value from objectproperty where propname='password' and objectid = (select objectid from objectproperty where propname='loginname' and value='$USR')\G;"
		$MYSQL $DB_NAME -u$DB_USER -p$DB_PASS -e "$SQL" | tail -1 > "$K_BACKUP_PATH/$USR/user-ph"
		echo -e "\n" | docker exec -i kopano4s chmod 644 "$USR"/user-details
		echo -e "\n" | docker exec -i kopano4s chmod 644 "$USR"/user-ph
		BUP_USRS="${BUP_USRS}${USR} "
	fi
	done
	echo "Per user kopano created in backup share (container: /var/lib/kopano/backup): $BUP_USRS"
fi