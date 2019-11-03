#!/bin/sh
LOGIN=$(whoami)
# get config
. /var/packages/Kopano4s/etc/package.cfg
MYSQL="/var/packages/MariaDB10/target/usr/local/mariadb10/bin/mysql"

if [ $# -eq 0 ] 
then
	echo "Usage: kopano4s-restore-user plus user-name | all | help."
	exit 0
fi
if [ "$1" = "help" ]
then
	echo "Usage: kopano4s-restore-user plus user-name | all | help."
	echo "When restoring all users the sub-dirs in backup directory are used validated by info-file user" 
	echo "Users will be created with old pwd if possible otherwise with default pwd 'M1gr@t1on' and it is reccomended to create them before"
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
CREATE_K_USER()
{
	local GRPLIST
	local NAME
	local MAIL
	local ACTIVE
	local ADMIN
	local FEATURES
	local GLINES
	local USRPH
	local FEAT
	local FEATLIST
	local ADMFLAG
	local SQL
	GRPLIST=""
	if [ -e "$K_BACKUP_PATH/$USR/user-details" ]
	then
		NAME=$(grep "Full name:" "$K_BACKUP_PATH/$USR/user-details" | cut -d ":" -f2- | sed "s~^[\t]*~~" | sed "s~^ *~~")
		MAIL=$(grep "Email address:" "$K_BACKUP_PATH/$USR/user-details" | cut -d ":" -f2- | sed "s~^[\t]*~~" | sed "s~ ~~g")
		ACTIVE=$(grep "Active:" "$K_BACKUP_PATH/$USR/user-details" | cut -d ":" -f2- | sed "s~^[\t]*~~" | sed "s~ ~~g")
		ADMIN=$(grep "Administrator:" "$K_BACKUP_PATH/$USR/user-details" | cut -d ":" -f2- | sed "s~^[\t]*~~" | sed "s~ ~~g")
		FEATURES=$(grep "Features:" "$K_BACKUP_PATH/$USR/user-details" | sed "s~^[\t]*~~" | sed "s~[\t]~:~" | sed "s~[\t]~~g" | sed "s~ ~~g" | cut -d ":" -f2- | sed "s~;~; ~g")
		# number of lines for group are indicated in brakets e.g. (2) but we have to add 2 more lines for header
		GLINES=0
		if grep -q "Groups" "$K_BACKUP_PATH/$USR/user-details" ; then GLINES=$(grep "Groups" "$K_BACKUP_PATH/$USR/user-details" | grep -o '(.*)' | sed 's/[()]//g') ; fi
		if [ $GLINES -gt 1 ]
		then 
			GLINES=$(($GLINES  + 2))
			GRPLIST=$(grep "Groups" -A $GLINES "$K_BACKUP_PATH/$USR/user-details" | grep -v Groups | grep -v Groupname | grep -v Everyone | grep -v "\-\-\-" | sed "s~[\t]~~g" | sed "s~ ~~g")
		fi
		if [ -e "$K_BACKUP_PATH/$USR/user-ph" ]
		then
			USRPH=$(grep "value:" "$K_BACKUP_PATH/$USR/user-ph" | cut -d ":" -f2- | sed "s~ ~~g")
		else
			USRPH=""
		fi
	else
		# cutting off name does not always work but this is a fallback if the user-details do not exist
		if grep -a -q VSMTP "$K_BACKUP_PATH"/"$USR"/user
		# old style before K 8.7x
		then
			# shellcheck disable=SC2002
			NAME=$(cat "$K_BACKUP_PATH"/"$USR"/user | grep -v "/" | grep -v "mobile" | grep -v "imap" | grep ^V | head -1 | cut -d "V" -f2- )
			# shellcheck disable=SC2002
			MAIL=$(cat "$K_BACKUP_PATH"/"$USR"/user | grep ^VSMTP | cut -d ":" -f2- )
		else
			# shellcheck disable=SC2002
			MAIL=$(cat "$K_BACKUP_PATH"/"$USR"/user | grep -a SMTP | cut -d ":" -f2- )
		fi
		ACTIVE="yes"
		ADMIN="no"
		FEATURES="mobile; outlook; webapp"
		USRPH=""		
	fi
	# distill away defaults from features
	FEATLIST=$(echo $FEATURES | sed "s~; ~\n~g" | grep -v mobile | grep -v outlook | grep -v webapp)
	if [ "$ADMIN" = "yes" ]
	then
		ADMFLAG=1
	else
		ADMFLAG=0			
	fi
	#echo "kopano-cli --create --create-store --user ${USR} --fullname ${NAME} --email ${MAIL} --admin-level ${ADMFLAG} --password 'M1gr@t1on'"
	if [ "$K_EDITION" = "Migration" ]
	then
		kopano-cli --create --user "$USR" --fullname="${NAME}" --email ${MAIL} --admin-level ${ADMFLAG} --password 'M1gr@t1on'
	else
		kopano-cli --create --create-store --user "$USR" --fullname="${NAME}" --email ${MAIL} --admin-level ${ADMFLAG} --password 'M1gr@t1on'	
	fi
	kopano-localize-folders -u "${USR}" --lang "${LOCALE}"
	if [ -n "$USRPH" ]
	then
		SQL="update objectproperty set value='$USRPH' where propname='password' and objectid = (select objectid from objectproperty where propname='loginname' and value='$USR')\G;"
		$MYSQL $DB_NAME -u$DB_USER -p$DB_PASS -e "$SQL"
	fi
	for FEAT in $FEATLIST ; do
		kopano-cli --user "${USR}" --add-feature "${FEAT}"
	done
	for GRP in $GRPLIST; do
		# create group if not yet exists
		if ! kopano-cli --list-groups | grep -v Groupname | grep -v "Group list for" | grep -v "\-\-\-" | grep -q ${GRP}
		then
			MAIL=$(grep "Email address:" "$K_BACKUP_PATH/$USR/grp-${GRP}-details" | cut -d ":" -f2- | sed "s~^[ \t]*~~")
			SENDAS=$(grep "Send-as:" "$K_BACKUP_PATH/$USR/grp-${GRP}-details" | cut -d ":" -f2- | sed "s~^[\t]*~~" | sed "s~ ~~g")
			kopano-cli --create --group "${GRP}" --email "${MAIL}"
			for SND in $SENDAS; do
				kopano-cli --add-sendas "${SND}" --group "${GRP}"
			done
		fi
		kopano-cli --group "${GRP}" --add-user "${USR}"
	done
}
STARTTIME=$(date +%s)
echo "Starting restore-user $1 .." > "$K_BACKUP_PATH"/restore-user.log
# main restore loop per user incl. creating if it does not exist which is in all user mode done via 1st loop to avoid cross acl errors
for USR in $USRLIST; do
	# is it a real backup directory then user control file has to exist now check if to create user
	if [ -e "$K_BACKUP_PATH/$USR/user" ] && ! kopano-cli --list-users | grep -v SYSTEM | grep -v Homeserver | grep -v "User list for Default" | grep -v "\-\-\-" | grep -q ^$USR
	then
		MSG="Creating user $USR"
		if [ ! -e "$K_BACKUP_PATH/$USR/user-ph" ]
		then
			MSG="$MSG with default pwd"
		fi
		echo "$(date "+%Y.%m.%d-%H.%M.%S") $MSG.."
		echo "$(date "+%Y.%m.%d-%H.%M.%S") $MSG.." >> "$K_BACKUP_PATH"/restore-user.log
		if [ "$NOTIFY" = "ON" ]
		then
			/usr/syno/bin/synodsmnotify $NOTIFYTARGET Kopano4s-Restore-User "$MSG"
		fi		
		CREATE_K_USER
	fi
done
for USR in $USRLIST; do
	# is it a real backup directory then user control file has to exist
	if [ -e "$K_BACKUP_PATH/$USR/user" ]
	then
		MSG="Restoring user $USR"
		echo "$(date "+%Y.%m.%d-%H.%M.%S") $MSG.."
		echo "$(date "+%Y.%m.%d-%H.%M.%S") $MSG.." >> "$K_BACKUP_PATH"/restore-user.log
		# log also to log if running as part of k4s-downgrade or kopano4s-migration-zarafa
		# shellcheck disable=SC2009
		if ps -ef | grep -v grep | grep kopano4s-downgrade | tail -1 | grep -q kopano4s-downgrade
		then
			echo "$(date "+%Y.%m.%d-%H.%M.%S") $MSG.." >> "$K_BACKUP_PATH"/downgrade-steps.log
		fi
		# shellcheck disable=SC2009
		if ps -ef | grep -v grep | grep kopano4s-migration-zarafa | tail -1 | grep -q kopano4s-migration-zarafa
		then
			echo "$(date "+%Y.%m.%d-%H.%M.%S") $MSG.." >> "$K_BACKUP_PATH"/migrate-steps.log
		fi
		if [ "$NOTIFY" = "ON" ]
		then
			/usr/syno/bin/synodsmnotify $NOTIFYTARGET Kopano4s-Restore-User "$MSG"
		fi		
		kopano-backup --restore $USR -l INFO >> "$K_BACKUP_PATH"/restore-user.log 2>&1
		# restore meta just in case as in older (migration) versions the mail rules had been missing otherwise
		kopano-backup --restore $USR --only-meta >> "$K_BACKUP_PATH"/restore-user.log 2>&1
		# add send-as delegation of other users now that all users exist 
		SENDAS=$(grep "Send-as:" "$K_BACKUP_PATH/$USR/user-details" | cut -d ":" -f2- | sed "s~^[\t]*~~" | sed "s~ ~~g" | sed "s~,~ ~g")
		for SND in $SENDAS; do
			kopano-cli --add-sendas "${SND}" --user "${USR}"
		done
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