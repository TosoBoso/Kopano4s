#!/bin/sh
LOGIN=$(whoami)
# get config
. /var/packages/Kopano4s/etc/package.cfg
MYSQL="/var/packages/MariaDB10/target/usr/local/mariadb10/bin/mysql"
ROLLB=0
K_EDITION_STATE="$K_EDITION"
if [ $# -gt 0 ] && [ "$1" = "help" ]
then
	echo "Usage: kopano4s-downgrade plus start | help."
	echo "Migrating Kopano Editions Community or Supported with higher release number by means of downgrade in 4 steps"
	echo "Step 1: database backup as a fallback. Use kopano4a-backup restore timestamp to recover if this job fails."
	echo "Step 2: mapi brick-level method kopano-backup for importing users into older database version later."
	echo "Step 3: truncate kopano database, restart with default edition which will recreate database ready for import"
	echo "Step 4: import of users via kopnao4s-restore-user all setting old password."
	echo "This is an all-in one scripted solution taking away the pain of loading different k4s version and running backup utilities."
	echo "It reccomended to run this sript via Synology task scheduler to avoid time-out before completion when running via terminal"
	echo "It is required to have an initial brick level kopano-backup run to allow shorter total runtime of this script."	
	exit 0
fi
if [ $# -eq 0 ] || ( [ $# -gt 0 ] && [ "$1" != "start" ] )
then
	echo "Usage: kopano4s-downgrade plus start | help."
	echo "To avoid accidential usage you have to provide start as parameter"
	exit 1
fi
if ! find $K_BACKUP_PATH -name user -type f | head -1 | grep -q user
then 
	MSG="you have to run at least one initial kopano-backup as baseline first to reduce the run-time of this script"
	echo "$MSG"
	echo "$(date "+%Y.%m.%d-%H.%M.%S") $MSG" > "$K_BACKUP_PATH"/downgrade-steps.log
	exit 1
fi
if [ "$LOGIN" != "root" ]
then 
	echo "you have to run as root! alternatively as admin run with sudo prefix! exiting.."
	exit 1
fi
MSG="Starting dowgrade steps: 1) kopano database backup as fallback 2) kopano user backup 3) truncate kopano database, restart with default edition 4) import of user" 
echo "$MSG"
if [ "$NOTIFY" = "ON" ]
then
	/usr/syno/bin/synodsmnotify $NOTIFYTARGET Kopano4s-Downgrade "$MSG"
fi
STARTTIME=$(date +%s)
echo "$(date "+%Y.%m.%d-%H.%M.%S") $MSG" >> "$K_BACKUP_PATH"/downgrade-steps.log
TSD=$(date +%Y%m%d)
DBDUMPS=$(find "$K_BACKUP_PATH" -name "dump-kopano-${TSD}*" | wc -l | sed 's/\ //g')
if [ $DBDUMPS -gt 0 ]
then
	MSG="step 1: skipped as kopano dump exists for today..."
	echo "$(date "+%Y.%m.%d-%H.%M.%S") $MSG"
	echo "$(date "+%Y.%m.%d-%H.%M.%S") $MSG" >> "$K_BACKUP_PATH"/downgrade-steps.log
else
	MSG="step 1: create baseline database dump from kopano as fallback..."
	echo "$(date "+%Y.%m.%d-%H.%M.%S") $MSG"
	echo "$(date "+%Y.%m.%d-%H.%M.%S") $MSG" >> "$K_BACKUP_PATH"/downgrade-steps.log
	kopano4s-backup
fi
MSG="step 2: run differential kopano user backup (backup-user.log)..."
echo "$(date "+%Y.%m.%d-%H.%M.%S") $MSG"
echo "$(date "+%Y.%m.%d-%H.%M.%S") $MSG" >> "$K_BACKUP_PATH"/downgrade-steps.log
echo "$(date "+%Y.%m.%d-%H.%M.%S") $MSG" > "$K_BACKUP_PATH"/backup-user.log
echo "$(date "+%Y.%m.%d-%H.%M.%S") running kopano-backup with 4 streams (see backup-user.log).."
kopano-backup -w 4 -l INFO >> "$K_BACKUP_PATH"/backup-user.log 2>&1
MSG="step 3: truncate kopano database and restart with default edition..."
echo "$(date "+%Y.%m.%d-%H.%M.%S") $MSG"
echo "$(date "+%Y.%m.%d-%H.%M.%S") $MSG" >> "$K_BACKUP_PATH"/downgrade-steps.log
# stopping kopano, truncate database and switch to default version
if /var/packages/Kopano4s/scripts/start-stop-status status ; then /var/packages/Kopano4s/scripts/start-stop-status stop ; fi
sed -i -e "s~K_EDITION=.*~K_EDITION=\"Default\""~ /var/packages/Kopano4s/etc/package.cfg
sed -i -e "s~K_RELEASE=.*~K_RELEASE=\"Stable\""~ /var/packages/Kopano4s/etc/package.cfg
sed -i -e "s~^report_url~#report_url"~ /var/packages/Kopano4s/INFO
# get all kopano tables to truncate with DB_NAME DB_USER DB_PASS
TABLES=$($MYSQL $DB_NAME -u$DB_USER -p$DB_PASS -e 'show tables' | awk '{ print $1}' | grep -v '^Tables' )
for t in $TABLES
do
	#echo "Deleting $t table from $DB_NAME database..."
	$MYSQL $DB_NAME -u$DB_USER -p$DB_PASS -e "drop table $t"
done
# also initialize attachments
rm -R "$K_SHARE"/attachments
mkdir -p "$K_SHARE"/attachments
chown kopano.kopano "$K_SHARE"/attachments
chmod 770 "$K_SHARE"/attachments
echo "$(date "+%Y.%m.%d-%H.%M.%S") Truncated log b4 starting default version.." > /var/log/kopano/server.log
kopano4s-init refresh
echo "$(date "+%Y.%m.%d-%H.%M.%S") sleep 3 min to have default version running smoothly and tables re-created.."
sleep 180
# no point to continue if kopano migration version stopped for any reason
if /var/packages/Kopano4s/scripts/start-stop-status status
then
	ROLLB=0
else
	ROLLB=1
	cp /var/log/kopano/server.log "$K_BACKUP_PATH"/downgrade-server.log
	sed -i -e "s~K_EDITION=.*~K_EDITION=\"${K_EDITION_STATE}\""~ /var/packages/Kopano4s/etc/package.cfg
	sed -i -e "s~K_RELEASE=.*~K_RELEASE=\"Stable\""~ /var/packages/Kopano4s/etc/package.cfg
	sed -i -e "s~^#report_url~report_url"~ /var/packages/Kopano4s/INFO
	kopano4s-init refresh
	head -4 "$K_BACKUP_PATH"/downgrade-server.log
fi
/var/packages/Kopano4s/scripts/start-stop-status start
if [ $ROLLB -eq 0 ]
then
	MSG="step 4: run kopano-restore-user (restore-user.log)..."
	echo "$(date "+%Y.%m.%d-%H.%M.%S") $MSG"
	echo "$(date "+%Y.%m.%d-%H.%M.%S") $MSG" >> "$K_BACKUP_PATH"/downgrade-steps.log
	echo "$(date "+%Y.%m.%d-%H.%M.%S") $MSG" > "$K_BACKUP_PATH"/restore-user.log
	kopano4s-restore-user all
	ENDTIME=$(date +%s)
	DIFFTIME=$(( $ENDTIME - $STARTTIME ))
	TASKTIME="$(($DIFFTIME / 60)) : $(($DIFFTIME % 60)) min:sec."
	MSG="Downgrading kopano4s to default edition completed in $TASKTIME. Reset user pwd and adjust full name where needed."
	echo "$(date "+%Y.%m.%d-%H.%M.%S") $MSG"
	echo "$(date "+%Y.%m.%d-%H.%M.%S") $MSG" >> "$K_BACKUP_PATH"/downgrade-steps.log
	cp /var/log/kopano/server.log "$K_BACKUP_PATH"/downgrade-server.log
	head -4 "$K_BACKUP_PATH"/downgrade-server.log
else
	MSG="Downgrading kopano4s rolled back.."
fi
if [ "$NOTIFY" = "ON" ]
then
	/usr/syno/bin/synodsmnotify $NOTIFYTARGET Kopano4s-Downgrade "$MSG"
fi
