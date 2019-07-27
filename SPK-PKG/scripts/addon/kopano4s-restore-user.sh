#!/bin/sh
LOGIN=`whoami`
# get common and config
. /var/packages/Kopano4s/scripts/common
. "$ETC_PATH"/package.cfg

if [ $# -eq 0 ] 
then
	echo "Usage: kopano4s-restore-user plus user-name | all | help."
	exit 0
fi
if [ "$1" = "help" ]
then
	echo "Usage: kopano4s-restore-user plus user-name | all | help."
	echo "When restoring all users the sub-dirs in backup directory are used validated by info-file user" 
	echo "Users will be created with default pwd 'M1gr@t1on' it is however reccomended to create them before"
	exit 0
fi
if [ $LOGIN != "root" ]
then 
	echo "you have to run as root! alternatively as admin run with sudo prefix! exiting.."
	exit 1
fi
if [ "$1" = "all" ]
then
	USRLIST=$(find "$K_BACKUP_PATH" -maxdepth 1 -type d -exec basename "{}" ";")
else
	USRLIST="$1"
fi
STARTTIME=$(date +%s)
if [ -e "$K_BACKUP_PATH/restore-user.log" ] ; then rm "$K_BACKUP_PATH"/restore-user.log ; fi
# main restore loop per user incl. creating if it does not exist with default pwd
for USR in $USRLIST; do
	# is it a real backup directory then user control file has to exist
	if [ -e "$K_BACKUP_PATH/$USR/user" ]
	then
		MSG="Resoring user $USR"
		if ! kopano-admin -l | grep -v SYSTEM | grep -v Homeserver | grep -v "User list for Default" | grep -v "\-\-\-" | grep -q $USR
		then
			MSG="$MSG incl. creation with default pwd"
			VSMTP=$(cat "$K_BACKUP_PATH"/"$USR"/user | grep ^VSMTP | cut -d ":" -f2- )
			VNAME=$(cat "$K_BACKUP_PATH"/"$USR"/user | grep -v "/" | grep -v "mobile" | grep -v "imap" | grep ^V | head -1 | cut -d "V" -f2- )
			kopano-admin -c ${USR} -p'M1gr@t1on' -e ${VSMTP} -f "${VNAME}"
		fi	
		echo "$(date "+%Y.%m.%d-%H.%M.%S") $MSG.."
		echo "$(date "+%Y.%m.%d-%H.%M.%S") $MSG.." >> "$K_BACKUP_PATH"/restore-user.log
		if [ "$NOTIFY" = "ON" ]
		then
			/usr/syno/bin/synodsmnotify $NOTIFYTARGET Kopano4s-Restore-User "$MSG"
		fi		
		kopano-backup --restore $USR -l INFO >> "$K_BACKUP_PATH"/restore-user.log 2>&1
	fi
done
# 2nd round with meta data to get ACLs is when all users exist
for USR in $USRLIST; do
	# is it a real backup directory then user control file has to exist
	if [ -e "$K_BACKUP_PATH/$USR/user" ]
	then
		kopano-backup --restore $USR --only-meta >> "$K_BACKUP_PATH"/restore-user.log 2>&1
	fi
done
ENDTIME=$(date +%s)
DIFFTIME=$(( $ENDTIME - $STARTTIME ))
TASKTIME="$(($DIFFTIME / 60)) : $(($DIFFTIME % 60)) min:sec."
MSG="Restore of $1 user completed in $TASKTIME"
echo "$(date "+%Y.%m.%d-%H.%M.%S") $MSG"
if [ "$NOTIFY" = "ON" ]
then
	/usr/syno/bin/synodsmnotify $NOTIFYTARGET Kopano4s-Restore-User "$MSG"
fi