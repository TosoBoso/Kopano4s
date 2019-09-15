#!/bin/sh
LOGIN=$(whoami)
# get common and config
. /var/packages/Kopano4s/scripts/common
. "$ETC_PATH"/package.cfg

if [ $# -gt 0 ] && [ "$1" = "help" ]
then
	echo "Usage: kopano4s-migration-zarafa plus start | help."
	echo "Migrating Synology Zarafa(4h) to Kopano4s in 5 steps based on Zarafa database dump (which can take hours for larger setup..)." 
	echo "If legacy Zarafa database exists on same host the backup / dump will be taken as part of this script."
	echo "Step 1: baseline backup is taken from current setup e.g. of empty database from kopano-core-8.6.9.x or 8.7.x install"
	echo "Step 2: create zarafa-db-dump for local database or you run zarafa-backup on other host and copy over dump to backup directory"
	echo "Step 3: restore zarafa-db-dump into kopano datatabase and start it with k4s-migration version which still supports zarafa upgrade"
	echo "Step 4: use mapi brick-level method kopano-backup instead of database backup to be able importing into newer database versions."
	echo "Step 5: restore baseline db-dump backup from step 1 and import on top of it the mapi export from step 4 user by exported user"
	echo "This is an all-in one scripted solution taking away the pain of loading different k4s version and running backup / migration utilities."
	echo "This way it is also easy to convert from attachments in database which was legacy Zarafa default into attachments on file system."
	echo "Users will be created with default pwd 'M1gr@t1on' it is however reccomended to create them incl. acl in the baseline before starting."
	echo "It is also reccomended to run this sript via Synology task scheduler to avoid time-out before completion when running via terminal"
	exit 0
fi
if [ $# -eq 0 ] || [ "$1" != "start" ]
then
	echo "Usage: kopano4s-migration-zarafa plus start | help."
	echo "To avoid accidential usage you have to provide start as parameter"
	exit 0
fi
if [ "$LOGIN" != "root" ]
then 
	echo "you have to run as root! alternatively as admin run with sudo prefix! exiting.."
	exit 1
fi
MSG="Starting migration steps: 1) kopano baseline backup 2) zarafa db-backup. 3) restore to kopano-db. 4) user export from kopano migration version 5) restore users to kopano baseline" 
echo "$MSG"
echo "$MSG" > "$K_BACKUP_PATH"/migrate-steps.log
if [ "$NOTIFY" = "ON" ]
then
	/usr/syno/bin/synodsmnotify $NOTIFYTARGET Kopano4s-Migration-Zarafa "$MSG"
fi
STARTTIME=$(date +%s)
# get day time stamp to skip backup of same day
TSD=$(date +%Y%m%d)
DBDUMPS=$(find "$K_BACKUP_PATH" -name "dump-kopano-${TSD}*" | wc -l | sed 's/\ //g')
if [ $DBDUMPS -gt 0 ]
then
	MSG="step 1: skipped as kopano dump exists for today..."
	echo "$(date "+%Y.%m.%d-%H.%M.%S") $MSG"
	echo "$(date "+%Y.%m.%d-%H.%M.%S") $MSG" >> "$K_BACKUP_PATH"/migrate-steps.log
else
	MSG="step 1: create baseline dump from kopano..."
	echo "$(date "+%Y.%m.%d-%H.%M.%S") $MSG"
	echo "$(date "+%Y.%m.%d-%H.%M.%S") $MSG" >> "$K_BACKUP_PATH"/migrate-steps.log
	kopano4s-backup
fi
DBDUMPS=$(find "$K_BACKUP_PATH" -name "dump-zarafa-${TSD}*" | wc -l | sed 's/\ //g')
if [ $DBDUMPS -gt 0 ]
then
	MSG="step 2: skipped as zarafa dump exists for today..."
	echo "$(date "+%Y.%m.%d-%H.%M.%S") $MSG"
	echo "$(date "+%Y.%m.%d-%H.%M.%S") $MSG" >> "$K_BACKUP_PATH"/migrate-steps.log
else
	if [ -e /etc/zarafa4h/server.cfg ] || [ -e /etc/zarafa/server.cfg ]
	then
		MSG="step 2: create dump from legacy zarafa..."
		echo "$(date "+%Y.%m.%d-%H.%M.%S") $MSG"
		echo "$(date "+%Y.%m.%d-%H.%M.%S") $MSG" >> "$K_BACKUP_PATH"/migrate-steps.log
		kopano4s-backup legacy
		sleep 10
	else
		MSG="ERROR no /etc/zarafa(4h)/server.cfg found: cannot run legacy backup. Add cfg or copy over zarafa dump of today"
		echo "$(date "+%Y.%m.%d-%H.%M.%S") $MSG"
		echo "$(date "+%Y.%m.%d-%H.%M.%S") $MSG" >> "$K_BACKUP_PATH"/migrate-steps.log		
		exit 1
	fi
fi
# stopping kopano and preparing for migration edition incl. ATTACHMENT_ON_FS="OFF"
if /var/packages/Kopano4s/scripts/start-stop-status status ; then /var/packages/Kopano4s/scripts/start-stop-status stop ; fi
ATTACHMENT_STATE="$ATTACHMENT_ON_FS"
K_EDITION_STATE="$K_EDITION"
sed -i -e "s~K_EDITION=.*~K_EDITION=\"Migration\""~ $ETC_PATH/package.cfg
if [ "$ATTACHMENT_ON_FS" = "ON" ]
then
	sed -i -e "s~ATTACHMENT_ON_FS=.*~ATTACHMENT_ON_FS=\"OFF\""~ "$ETC_PATH"/package.cfg
	sed -i -e "s~attachment_storage.*~attachment_storage	= database~" "$ETC_PATH"/kopano/server.cfg
fi
# set back server.cfg mode at migration version; it will not sstart with new settings
if [ -e $ETC_PATH/kopano/server.cfg ] && grep -q server_listen "$ETC_PATH"/kopano/server.cfg
then
	# in server.cfg swith from new server entry to migration versionstyle
	if ! grep -q server_tcp_enabled "$ETC_PATH"/kopano/server.cfg
	then
		sed -i -e "s~server_listen = \*:236~server_listen = \*:236\nserver_tcp_enabled = yes\nserver_tcp_port = 236~" "$ETC_PATH"/kopano/server.cfg
	fi
	sed -i -e "s~^server_listen~#server_listen~" "$ETC_PATH"/kopano/server.cfg
	sed -i -e "s~^server_listen_tls~#server_listen_tls~" "$ETC_PATH"/kopano/server.cfg
fi
# get timestamp of zarafa dump and then start restore
# shellcheck disable=SC2012
# need to rewrite SC2012: Use find instead of ls to better handle non-alpha
TS=$(ls -t1 "$K_BACKUP_PATH"/dump-zarafa-*.sql.gz | head -n 1 | grep -o "[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]")
MSG="step 3: restore zarafa dump of $TS into kopano..."
echo "$(date "+%Y.%m.%d-%H.%M.%S") $MSG"
echo "$(date "+%Y.%m.%d-%H.%M.%S") $MSG" >> "$K_BACKUP_PATH"/migrate-steps.log
kopano4s-backup restore $TS legacy
MSG="step 4: starting kopano migration (8.4.5) to run user export..."
echo "$(date "+%Y.%m.%d-%H.%M.%S") $MSG"
echo "$(date "+%Y.%m.%d-%H.%M.%S") $MSG" >> "$K_BACKUP_PATH"/migrate-steps.log
echo "$(date "+%Y.%m.%d-%H.%M.%S") Truncated log b4 starting migration version.." > /var/log/kopano/server.log
kopano4s-init refresh
# wait 3m to have to have zarafa databse upgraded in migration version then start kopano-backup aka mapi export per uer
echo "$(date "+%Y.%m.%d-%H.%M.%S") sleep 5 min to have migration version running smoothly with zarafa database import.."
sleep 300
# no point to continue if kopano migration version stopped for any reason
if /var/packages/Kopano4s/scripts/start-stop-status status
then
	ROLLB=0
else
	MSG="ERROR running imported data (see migrate-server.log); rolling back.."
	echo "$(date "+%Y.%m.%d-%H.%M.%S") $MSG"
	echo "$(date "+%Y.%m.%d-%H.%M.%S") $MSG" >> "$K_BACKUP_PATH"/migrate-steps.log
	ROLLB=1
fi
if [ $ROLLB -eq 0 ]
then
	echo "$(date "+%Y.%m.%d-%H.%M.%S") running kopano-backup with 4 streams (see backup-user.log).."
	kopano-backup -w 4 -l INFO > "$K_BACKUP_PATH"/backup-user.log 2>&1
fi
cp /var/log/kopano/server.log "$K_BACKUP_PATH"/migrate-server.log
# shellcheck disable=SC2012
# need to rewrite SC2012: Use find instead of ls to better handle non-alpha
TS=$(ls -t1 "$K_BACKUP_PATH"/dump-kopano-*.sql.gz | head -n 1 | grep -o "[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]")
if [ $ROLLB -eq 0 ]
then
	echo "$(date "+%Y.%m.%d-%H.%M.%S") Truncated log b4 starting user import.." > /var/log/kopano/server.log
	MSG="step 5: restore kopano baseline dump of $TS and import users..."
else
	MSG="rollback restore kopano baseline dump of $TS ..."
fi
echo "$(date "+%Y.%m.%d-%H.%M.%S") $MSG"
echo "$(date "+%Y.%m.%d-%H.%M.%S") $MSG" >> "$K_BACKUP_PATH"/migrate-steps.log
if /var/packages/Kopano4s/scripts/start-stop-status status ; then /var/packages/Kopano4s/scripts/start-stop-status stop ; fi
sed -i -e "s~K_EDITION=.*~K_EDITION=\"${K_EDITION_STATE}\""~ $ETC_PATH/package.cfg
if [ "$ATTACHMENT_STATE" = "ON" ]
then
	sed -i -e "s~ATTACHMENT_ON_FS=.*~ATTACHMENT_ON_FS=\"ON\""~ "$ETC_PATH"/package.cfg
	sed -i -e "s~attachment_storage.*~attachment_storage	= files~" "$ETC_PATH"/kopano/server.cfg
fi
# set back server.cfg mode post migration version
if [ -e $ETC_PATH/kopano/server.cfg ] && grep -q server_listen "$ETC_PATH"/kopano/server.cfg
then
	sed -i -e "s~^#server_listen~server_listen~" "$ETC_PATH"/kopano/server.cfg
	sed -i -e "s~^#server_listen_tls~server_listen_tls~" "$ETC_PATH"/kopano/server.cfg
	sed -i -e "s~^server_tcp_enabled.*~~" "$ETC_PATH"/kopano/server.cfg
	sed -i -e "s~^server_tcp_port.*~~" "$ETC_PATH"/kopano/server.cfg
fi
kopano4s-backup restore $TS
kopano4s-init refresh
/var/packages/Kopano4s/scripts/start-stop-status start
if [ $ROLLB -eq 0 ]
then
	kopano4s-restore-user all
	ENDTIME=$(date +%s)
	DIFFTIME=$(( $ENDTIME - $STARTTIME ))
	TASKTIME="$(($DIFFTIME / 60)) : $(($DIFFTIME % 60)) min:sec."
	MSG="Migration zarafa to kopano4s completed in $TASKTIME.."
	echo "$(date "+%Y.%m.%d-%H.%M.%S") $MSG"
	echo "$(date "+%Y.%m.%d-%H.%M.%S") $MSG" >> "$K_BACKUP_PATH"/migrate-steps.log
	cp /var/log/kopano/server.log "$K_BACKUP_PATH"/import-server.log
	head -4 "$K_BACKUP_PATH"/import-server.log
else
	MSG="Migration zarafa to kopano4s rolled back.."
fi
if [ "$NOTIFY" = "ON" ]
then
	/usr/syno/bin/synodsmnotify $NOTIFYTARGET Kopano4s-Migration-Zarafa "$MSG"
fi
