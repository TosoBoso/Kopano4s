#!/bin/sh
# (c) 2018 vbettag - mysql backup for Kopano  script inspired by synology-wiki.de mods mysql backup section
# admins only plus set sudo for DSM 6 as root login is no longer possible
LOGIN=`whoami`
MAJOR_VERSION=`grep majorversion /etc.defaults/VERSION | grep -o [0-9]`
if [ $LOGIN != "root" ]
then 
	echo "you have to run as root! alternatively as admin run with sudo prefix! exiting.."
	exit 1
fi

# backup from legacy into dump-zarafa is via 1st argument, restore of legacy dump to legacy db is via 2x legacy aka 4th argument
if [ -e /var/packages/Kopano4s/etc/package.cfg ] && [ "$1" != "legacy" ] && [ "$4" != "legacy" ]
then
	. /var/packages/Kopano4s/etc/package.cfg
	MYSQL="/var/packages/MariaDB10/target/usr/local/mariadb10/bin/mysql"
	MYSQLDUMP="/var/packages/MariaDB10/target/usr/local/mariadb10/bin/mysqldump"
	if [ "$2" == "legacy" ] || [ "$3" == "legacy" ]
	then
		# resore of zarafa-dump into kopano-migration edition only
		if [ "$K_EDITION" != "Migration" ]
		then
			echo "restore of legacy Zarafa dump into Kopano is only possible via Migration edition. Exiting.."
			exit 1
		fi
		DPREFIX="dump-zarafa"
	else
		DPREFIX="dump-kopano"
	fi
	LEGACY=0
else
	# legacy zarafa package assuming use of MariaDB-5 unless not present adn replica in MariaDB-10
	if [ -e /var/packages/MariaDB/target/usr/bin/mysql ]
	then
		MYSQL="/var/packages/MariaDB/target/usr/bin/mysql"
		MYSQLDUMP="/var/packages/MariaDB/target/usr/bin/mysqldump"
	else
		MYSQL="/var/packages/MariaDB10/target/usr/local/mariadb10/bin/mysql"
		MYSQLDUMP="/var/packages/MariaDB10/target/usr/local/mariadb10/bin/mysqldump"
	fi
	if [ -e /etc/zarafa4h/server.cfg ] || [ -e /etc/zarafa/server.cfg ]
	then
		if [ -e /etc/zarafa4h/server.cfg ]
		then
			ETC=/etc/zarafa4h
		else
			ETC=/etc/zarafa
		fi
		DPREFIX="dump-zarafa"
		LEGACY=1
		if [ -e /var/packages/Kopano4s/etc/package.cfg ]
		then
			. /var/packages/Kopano4s/etc/package.cfg
		else
			NOTIFYTARGET=$SYNOPKG_USERNAME
			if [ "_$NOTIFYTARGET" == "_" ] ; then NOTIFYTARGET=$SYNO_WEBAPI_USERNAME ; fi
			if [ "_$NOTIFYTARGET" == "_" ] ; then NOTIFYTARGET=$USERNAME ; fi
			if [ "_$NOTIFYTARGET" == "_" ] ; then NOTIFYTARGET=$USER ; fi
			if [ "_$NOTIFYTARGET" == "_" ] ||  [ "$NOTIFYTARGET" == "root" ] ; then NOTIFYTARGET="@administrators" ; fi
			KEEP_BACKUPS=4
			K_SHARE="/volume1/kopano"
		fi
		DB_NAME=`grep ^mysql_database $ETC/server.cfg | cut -f2 -d'=' | grep -o '[^\t ].*'`
		DB_USER=`grep ^mysql_user $ETC/server.cfg | cut -f2 -d'=' | grep -o '[^\t ].*'`
		DB_PASS=`grep ^mysql_password $ETC/server.cfg | cut -f2 -d'=' | grep -o '[^\t ].*'`
		# create directories if not exist (better have shared folder backup created first)
		test -e $K_SHARE || mkdir -p $K_SHARE 
		test -e $K_SHARE/backup || mkdir -p $K_SHARE/backup
	else
		echo "Kopano or legacy Zarafa not present to backup (no /etc/kopano or /etc/zarafa(4h) with server.cfg) exit now"
		exit 1
	fi
fi
if [ "_$NOTIFY" != "_ON" ]
then 
	NOTIFY=0
else
	NOTIFY=1
fi
if [ "_$BACKUP_PATH" != "_" ] && [ -e $BACKUP_PATH ]
then
	DUMP_PATH=$BACKUP_PATH
else
	DUMP_PATH="$K_SHARE/backup"
fi
ATTM_PATH="$K_SHARE/attachments"
DUMP_LOG="$DUMP_PATH/mySqlDump.log"
SQL_ERR="$DUMP_PATH/mySql.err"
DUMP_ARGS="--hex-blob --skip-lock-tables --single-transaction --log-error=$SQL_ERR"

if [ "$1" == "help" ]
then
	echo "kopano4s-backup (c) TosoBoso: script using mysqldump inspired by synology and zarafa wiki"
	echo "script will work with transaction locks as opposed to full table locks"
	echo "to restore provide the keyword and timestamp e.g. <kopano4s-backup.sh restore 201805151230"
	echo "to prevent failed restore due to big blobs (attachments) we set max_allowed_packet = 16M or more in </etc/mysql/my.cnf>"
	exit 0
fi

if [ "$1" == "restore" ]
then
	# DPREFIX=dump-kopano / zarafa dependent on legacy switch"
	if [ "$2" == "" ] || !(test -e $DUMP_PATH/$DPREFIX-${2}.sql.gz)
	then
		TS=`ls -t1 $DUMP_PATH/$DPREFIX-*.sql.gz | head -n 1 | grep -o [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]`
		if [ "$TS" == "" ]
		then
			TS="no files exist"
		fi
		echo "no valid restore argument was provided. Latest timestamp would be <$TS>"
		exit 1
	fi
	TSTAMP=$2
	test -e /var/packages/MariaDB10/etc/my.cnf || touch /var/packages/MariaDB10/etc/my.cnf
	if !(grep -q "max_allowed_packet" /var/packages/MariaDB10/etc/my.cnf)
	then
		if !(grep -q "[mysqld]" /var/packages/MariaDB10/etc/my.cnf)
		then
			echo -e "[mysqld]" >> /var/packages/MariaDB10/etc/my.cnf
		fi
		echo -e "max_allowed_packet = 16M" >> /var/packages/MariaDB10/etc/my.cnf
		echo "mysql max_allowed_packet had to be increased to prevent failed restore of big blobs; retry post restarting mysql.."
		/var/packages/MariaDB10/scripts/start-stop-status restart
		exit 1
	fi
	# do not restore in active slave mode as it breaks replication and stop if mysql read-only
	if [ "$K_REPLICATION" == "SLAVE" ] && ( (kopano-replication | grep -q "running") || (grep -q "^read-only" /var/packages/MariaDB10/etc/my.cnf))
	then
		MSG="refuse restore: replication running or mysql read-only do kopano-replication reset first"
		echo $MSG
		if [ $NOTIFY -gt 0 ]
		then
			/usr/syno/bin/synodsmnotify $NOTIFYTARGET Kopano4s "$MSG"
		fi
		exit 1
	fi
	TS=$(date "+%Y.%m.%d-%H.%M.%S")
	MSG="stoping kopano and starting restore of $DB_NAME from $DPREFIX-${TSTAMP}.sql.gz..."
	echo -e "$TS $MSG" >> $DUMP_LOG
	echo "$MSG"
	K_START=0
	if [ $LEGACY -gt 0 ]
	then
		if [ -e /var/packages/Zarafa/scripts/start-stop-status ] && /var/packages/Zarafa/scripts/start-stop-status status
		then
			/var/packages/Zarafa/scripts/start-stop-status stop
			K_START=1
		fi
		if [ -e /var/packages/Zarafa4home/scripts/start-stop-status ] && /var/packages/Zarafa4home/scripts/start-stop-status status
		then
			/var/packages/Zarafa4home/scripts/start-stop-status stop
			K_START=1
		fi
	else
		if /var/packages/Kopano4s/scripts/start-stop-status status
		then
			/var/packages/Kopano4s/scripts/start-stop-status stop
			K_START=1
		fi
	fi
	gunzip $DUMP_PATH/$DPREFIX-${TSTAMP}.sql.gz
	STARTTIME=$(date +%s)
	$MYSQL $DB_NAME -u$DB_USER -p$DB_PASS < $DUMP_PATH/$DPREFIX-${TSTAMP}.sql >$SQL_ERR 2>&1
	# collect if available master-log-positon in in sql-dump
	ML=`head $DUMP_PATH/$DPREFIX-${TSTAMP}.sql -n50 | grep "MASTER_LOG_POS" | cut -c 4-`
	gzip -9 $DUMP_PATH/$DPREFIX-${TSTAMP}.sql
	ENDTIME=$(date +%s)
	DIFFTIME=$(( $ENDTIME - $STARTTIME ))
	TASKTIME="$(($DIFFTIME / 60)) : $(($DIFFTIME % 60)) min:sec."
	TS=$(date "+%Y.%m.%d-%H.%M.%S")
	MSG="restore for $DB_NAME completed in $TASKTIME"
	echo -e "$TS $MSG" >> $DUMP_LOG
	echo "$MSG"
	if [ $NOTIFY -gt 0 ]
	then
		/usr/syno/bin/synodsmnotify $NOTIFYTARGET Kopano4s-Backup "$MSG"
	fi
	RET=`cat $SQL_ERR`
	if [ "$RET" != "" ]
	then
		echo -e "MySQL returned error: $RET"
	fi
	# add if string is not empty
	if [ ! -z "$ML" ]
	then
		echo -e "for replication or point in time recovery $ML"
		echo -e "for replication or point in time recovery $ML" >> $DUMP_LOG
		if [ -e $DUMP_PATH/master-logpos-* ] ; then rm $DUMP_PATH/master-logpos-* ; fi
		echo "$ML" > $DUMP_PATH/master-logpos-${TSTAMP}
	fi
	if [ -e $DUMP_PATH/master-logpos-${TSTAMP} ]
	then 
		chown root.kopano $DUMP_PATH/master-logpos-${TSTAMP}
		chmod 640 $DUMP_PATH/master-logpos-${TSTAMP}
	fi
	# backup attachements if they exist
	if [ "$ATTACHMENT_ON_FS" == "ON" ] && [ -e $DUMP_PATH/attachments-${TSTAMP}.tgz ] 
	then
		MSG="restoring attachments linked to $DB_NAME..."
		TS=$(date "+%Y.%m.%d-%H.%M.%S")
		echo -e "$TS $MSG" >> $DUMP_LOG
		echo -e "$MSG"
		CUR_PATH=`pwd`
		cd $K_SHARE
		if [ -e attachments.old ] ; then rm .R attachments.old ; fi
		mv attachments attachments.old
		tar -zxvf $DUMP_PATH/attachments-${TSTAMP}.tgz attachments/
		chown -R kopano.kopano attachments
		chmod 770 attachments
		cd $CUR_PATH
	fi
	if [ $K_START -gt 0 ]
	then
		if [ $LEGACY -gt 0 ]
		then
			if [ -e /var/packages/Zarafa/scripts/start-stop-status ]
			then
				/var/packages/Zarafa/scripts/start-stop-status start
			fi
			if [ -e /var/packages/Zarafa4home/scripts/start-stop-status ]
			then
				/var/packages/Zarafa4home/scripts/start-stop-status start
			fi
		else
			/var/packages/Kopano4s/scripts/start-stop-status start	
		fi
	fi
	exit 0
fi

MSG="starting mysql-dump of $DB_NAME to $DUMP_PATH..."
if [ "$1" == "master" ]
then
	# if "log-bin" found add master-date switch for point in time recovery / building
	if grep -q ^log-bin /var/packages/MariaDB10/etc/my.cnf
	then
		MSG="$MSG incl. master-log mode for replication"
		DUMP_ARGS="$DUMP_ARGS --master-data=2"
	else
		echo "warning: binary logging has to be enabled (my.cf with <log-bin> section)"
	fi
fi
TS=$(date "+%Y.%m.%d-%H.%M.%S")
echo -e "$TS $MSG" >> $DUMP_LOG
if [ "$1" == "" ]
then
	MSG="$MSG use help for details e.g. on restore"
fi
echo -e "$MSG"

# prevent unnoticed backup error when pipe is failing
set -o pipefail
# delete old dump files dependent on keep versions / retention
DBDUMPS=`find $DUMP_PATH -name "$DPREFIX-*.sql.gz" | wc -l | sed 's/\ //g'`
if [ "$DBDUMPS" == "" ]
then
	DBDUMPS=0
fi
while [ $DBDUMPS -ge $KEEP_BACKUPS ]
do
	ls -tr1 $DUMP_PATH/$DPREFIX-*.sql.gz | head -n 1 | xargs rm -f 
	DBDUMPS=`expr $DBDUMPS - 1` 
done

TSTAMP=`date +%Y%m%d%H%M`
DUMP_FILE_RUN="$DUMP_PATH/.$DPREFIX-${TSTAMP}.sql.gK_RUNNING"

# check for previous files and remove (2 grep lines) or stop processing (>2 processes)
if [ -e $DUMP_PATH/.$DPREFIX-*.sql.gK_RUNNING ]
then
	RET=`ps -f | grep kopano-backup.sh | wc -l`
	if [ $RET -le 2 ]
	then
		rm -f $DUMP_PATH/.$DPREFIX-*.sql.gK_RUNNING
	else
		echo -e "terminating due to already running mysql dump process"
		echo -e "terminating due to already running mysql dump process"  >> $DUMP_LOG
		exit 1
	fi
fi
STARTTIME=$(date +%s)
# ** start mysql-dump logging to $SQL_ERR to compressed file during run time use suffix RUNNING
$MYSQLDUMP $DUMP_ARGS $DB_NAME -u$DB_USER -p$DB_PASS | gzip -c -9 > $DUMP_FILE_RUN

ENDTIME=$(date +%s)
DIFFTIME=$(( $ENDTIME - $STARTTIME ))
TASKTIME="$(($DIFFTIME / 60)) : $(($DIFFTIME % 60)) min:sec."

RET=`cat $SQL_ERR`
if [ "$RET" != "" ]
then
	echo -e $RET
	echo -e $RET >> $DUMP_LOG
	if [ $NOTIFY -gt 0 ]
	then
		/usr/syno/bin/synodsmnotify $NOTIFYTARGET Kopano4s-Backup-Error "$RET"
	fi
fi
mv -f $DUMP_FILE_RUN $DUMP_PATH/$DPREFIX-${TSTAMP}.sql.gz

TS=$(date "+%Y.%m.%d-%H.%M.%S")
MSG="dump for $DB_NAME completed in $TASKTIME"
echo -e "$TS $MSG" >> $DUMP_LOG
echo "$MSG"
if [ $NOTIFY -gt 0 ]
then
	/usr/syno/bin/synodsmnotify $NOTIFYTARGET Kopano4s-Backup "$MSG"
fi
# backup attachements if they exist
if [ "$ATTACHMENT_ON_FS" == "ON" ] && [ ! -d "ls -A $ATTM_PATH" ] 
then
	MSG="saving attachments linked to $DB_NAME..."
	TS=$(date "+%Y.%m.%d-%H.%M.%S")
	echo -e "$TS $MSG" >> $DUMP_LOG
	echo -e "$MSG"
	CUR_PATH=`pwd`
	cd $K_SHARE
	tar cfz $DUMP_PATH/attachments-${TSTAMP}.tgz attachments/
	cd $CUR_PATH
fi
exit 0