#!/bin/sh
LOGIN=`whoami`
MAJOR_VERSION=`grep majorversion /etc.defaults/VERSION | grep -o [0-9]`
if [ $LOGIN != "root" ]
then 
	echo "you have to run as root! alternatively as admin run with sudo prefix! exiting.."
	exit 1
fi
KDUMP_PATH="/volume1/kopano/backup"
ZDUMP_PATH="/volume1/zarafa/backup"
ZBUPS_PATH="/volume2/backup/mySqlDump"
KATTC_PATH="/volume1/kopano/attachments"
KEEP_BACKUPS=2
INCREMENTAL="OFF"
STARTTIME=$(date +%s)

if ! /var/packages/MariaDB/scripts/start-stop-status status ; then /var/packages/MariaDB/scripts/start-stop-status start ; fi
if ! /var/packages/MariaDB10/scripts/start-stop-status status ; then /var/packages/MariaDB10/scripts/start-stop-status start ; fi
if [ "$1" == "live" ]
then
	# take a live snapshot from replicated z4h
	zarafa-backup legacy
	TS=`ls -t1 $ZDUMP_PATH/dump-zarafa-*.sql.gz | head -n 1 | grep -o [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]`
else
	# take copy from mySqlDum backup
	TS=`ls -t1 $ZBUPS_PATH/dump-zarafa-*.sql.gz | head -n 1 | grep -o [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]`
	echo "$(date "+%Y.%m.%d-%H.%M.%S") copy over dump-zarafa-${TS}.sql.gz..."
	echo "$(date "+%Y.%m.%d-%H.%M.%S") copy over dump-zarafa-${TS}.sql.gz..." >> $KDUMP_PATH/migrate-steps.log
	if [ ! -e $ZDUMP_PATH/dump-zarafa-${TS}.sql.gz ] ; then cp -f $ZBUPS_PATH/dump-zarafa-${TS}.sql.gz $ZDUMP_PATH ; fi
fi
# delete old dump files dependent on keep versions / retention
echo "$(date "+%Y.%m.%d-%H.%M.%S") delete old backups.."
echo "$(date "+%Y.%m.%d-%H.%M.%S") delete old backups.." >> $KDUMP_PATH/migrate-steps.log
DBDUMPS=`find $ZDUMP_PATH -name "dump-zarafa-*.sql.gz" | wc -l | sed 's/\ //g'`
if [ "$DBDUMPS" == "" ]
then
	DBDUMPS=0
fi
while [ $DBDUMPS -ge $KEEP_BACKUPS ]
do
	ls -tr1 $ZDUMP_PATH/dump-zarafa-*.sql.gz | head -n 1 | xargs rm -f 
	DBDUMPS=`expr $DBDUMPS - 1` 
done
echo "$(date "+%Y.%m.%d-%H.%M.%S") restore to z4h dump-zarafa-${TS}.sql.gz..."
echo "$(date "+%Y.%m.%d-%H.%M.%S") restore to z4h dump-zarafa-${TS}.sql.gz..." >> $KDUMP_PATH/migrate-steps.log
zarafa-backup restore $TS
/var/packages/Kopano4s/scripts/start-stop-status stop
/var/packages/Zarafa4home/scripts/start-stop-status start
echo "$(date "+%Y.%m.%d-%H.%M.%S") running z4h backup plus brick-level (k4s is stopped).."
echo "$(date "+%Y.%m.%d-%H.%M.%S") running z4h backup plus brick-level (k4s is stopped).." >> $KDUMP_PATH/migrate-steps.log
kdir -p /volume1/zarafa/attachments/backup
zarafa-backup-plus -O /var/lib/zarafa/attachments/backup --skip-junk --skip-deleted >$KDUMP_PATH/migrate-bup.log
echo "$(date "+%Y.%m.%d-%H.%M.%S") Stopping z4h, starting k4s migration.."
echo "$(date "+%Y.%m.%d-%H.%M.%S") Stopping z4h, starting k4s migration.." >> $KDUMP_PATH/migrate-steps.log
/var/packages/Zarafa4home/scripts/start-stop-status stop
/var/packages/Kopano4s/scripts/start-stop-status start

if [ ! -e $KDUMP_PATH/dump-kopano-*.sql.gz ] ; then cp -f $ZBUPS_PATH/dump-kopano-*.sql.gz $KDUMP_PATH ; fi
if [ "$INCREMENTAL" != "ON" ]
then
	echo "$(date "+%Y.%m.%d-%H.%M.%S") restore baseline to k4s: dump-kopano-${TS}.sql.gz..."
	echo "$(date "+%Y.%m.%d-%H.%M.%S") restore baseline to k4s: dump-kopano-${TS}.sql.gz..." >> $KDUMP_PATH/migrate-steps.log
	TS=`ls -t1 $KDUMP_PATH/dump-kopano-*.sql.gz | head -n 1 | grep -o [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]`
	/var/packages/Kopano4s/scripts/start-stop-status stop
	kopano4s-backup restore $TS
	rm -R $KATTC_PATH
	mkdir -p $KATTC_PATH
	chown kopano.kopano $KATTC_PATH
	chmod 770 $KATTC_PATH
	/var/packages/Kopano4s/scripts/start-stop-status start
	sleep 20
fi
# run restore for users with fax going to admin post rename
USRLST="admin user1"
# remove user dirs from last time and copy over from z4h backup
echo "$(date "+%Y.%m.%d-%H.%M.%S") copy over backup of users from z4h to k4s.."
for USR in $USRLST; do
	if [ -e $KDUMP_PATH/$USR ] ; then rm -R $KDUMP_PATH/$USR ; fi
done
if [ -e $KDUMP_PATH/public ] ; then rm -R $KDUMP_PATH/public ; fi
cp -R /volume1/zarafa/attachments/backup /volume1/kopano
chown -R kopano.kopano $KATTC_PATH

if [ -e $KDUMP_PATH/fax ] ; then mv $KDUMP_PATH/fax $KDUMP_PATH/admin ; fi
if [ -e $KDUMP_PATH/migrate-rest.log ] ; then rm $KDUMP_PATH/migrate-rest.log ; fi
for USR in $USRLST; do
	echo "$(date "+%Y.%m.%d-%H.%M.%S") restore to k4s for $USR.."
	echo "$(date "+%Y.%m.%d-%H.%M.%S") restore to k4s for $USR.." >> $KDUMP_PATH/migrate-steps.log
	kopano-backup --restore $USR -U admin -P 'secret' -u $USR -l INFO >> $KDUMP_PATH/migrate-rest.log
	kopano-backup --restore $USR --only-meta -U admin -P 'secret' -u $USR -l INFO >> $KDUMP_PATH/migrate-rest.log
done
ENDTIME=$(date +%s)
DIFFTIME=$(( $ENDTIME - $STARTTIME ))
TASKTIME="$(($DIFFTIME / 60)) : $(($DIFFTIME % 60)) min:sec."
echo "$(date "+%Y.%m.%d-%H.%M.%S") migration to k4s completed in $TASKTIME.."
echo "$(date "+%Y.%m.%d-%H.%M.%S") migration to k4s completed in $TASKTIME.." >> $KDUMP_PATH/migrate-steps.log
