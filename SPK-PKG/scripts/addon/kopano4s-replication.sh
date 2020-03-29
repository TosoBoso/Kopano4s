#!/bin/sh
# (c) 2018 vbettag - msql replication for Kopano script for setup and monitoring
# admins only plus set sudo for DSM 6 as root login is no longer possible
LOGIN=$(whoami)
if [ "$LOGIN" != "root" ]
then 
	echo "you have to run as root! alternatively as admin run with sudo prefix! exiting.."
	exit 1
fi

if [ -e /var/packages/Kopano4s/etc/package.cfg ] && [ "$1" != "legacy" ] && [ "$2" != "legacy" ] && 
	[ "$3" != "legacy" ] && [ "$4" != "legacy" ] && [ "$5" != "legacy" ] && [ "$6" != "legacy" ]
then
	CFG="/var/packages/Kopano4s/etc/package.cfg"
	MYSQL="/var/packages/MariaDB10/target/usr/local/mariadb10/bin/mysql"
	MYETC="/var/packages/MariaDB10/etc"
else
	# legacy zarafa package assuming use of MariaDB-5 unless not present and replica in MariaDB-10
	if [ -e /var/packages/MariaDB/target/usr/bin/mysql ]
	then
		MYSQL="/var/packages/MariaDB/target/usr/bin/mysql"
		MYETC="/var/packages/MariaDB/etc"
	else
		MYSQL="/var/packages/MariaDB10/target/usr/local/mariadb10/bin/mysql"
		MYETC="/var/packages/MariaDB10/etc"
	fi
	CFG="/etc/zarafa/replication.cfg"
	if [ -e /etc/zarafa/server.cfg ]
	then
		DB_NAME=$(grep ^mysql_database /etc/zarafa/server.cfg | cut -f2 -d'=' | grep -o '[^\t ].*')
		DB_USER=$(grep ^mysql_user /etc/zarafa/server.cfg | cut -f2 -d'=' | grep -o '[^\t ].*')
		DB_PASS=$(grep ^mysql_password /etc/zarafa/server.cfg | cut -f2 -d'=' | grep -o '[^\t ].*')
	else
		echo "no Zarafa present to replicate (no /etc/zarafa/server.cfg); exit now"
		exit 1
	fi
	if [ ! -e "$CFG" ]
	then
		# not considering using { cmd1; cmd2}
		# shellcheck disable=SC2129
		echo "NOTIFY=ON" > "$CFG"
		# shellcheck disable=SC2129
		echo "NOTIFYTARGET=\"@administrators\"" >> "$CFG"
		# shellcheck disable=SC2129
		echo "K_REPLICATION=\"OFF\"" >> "$CFG"
		# shellcheck disable=SC2129
		echo "K_REPLICATION_PWD=\"\"" >> "$CFG"
		# shellcheck disable=SC2129
		echo "K_SHARE=\"/volume1/kopano\"" >> "$CFG"
		echo "K_BACKUP_PATH=\"/volume1/kopano/backup\"" >> "$CFG"
	fi
fi
# read config and add sql dump path
. "$CFG"
if [ -z "$NOTIFY" ] ; then NOTIFY= "ON" ; fi
if [ -n "$K_BACKUP_PATH" ] && [ -e "$K_BACKUP_PATH" ]
then
	DUMP_PATH="$K_BACKUP_PATH"
else
	DUMP_PATH="$K_SHARE/backup"
fi

if [ $# -gt 0 ] && [ "$1" = "help" ]
then
	echo "kopano-replication (c) TosoBoso: script for kopano replication via mysql."
	echo "Usage: kopano-replication [action] with status as default."
	echo "[status] or no action as argument shows setup per master or slave configuration and mysql replication state."
	echo "[health] checks replication state bi-directional for master and slave including error notification."
	echo "[master mypwd shost rpwd id] set master with id and replication user rslave connecting from slave-host."
	echo "[slave-add mypwd shost] add to running master next slave-host to connect with replication user rslave."
	echo "[slave mypwd mhost rpwd id] set and connect slave to the master-host with user rslave; run syncin afterwards."
	echo "[start/stop/syncin/skip/resync/remove mypwd] applicable for slave; syncin=start with master log-pos post restore;"
	echo "to resolve issues: skip=skip last error; remove=replication removal; resync=initialized sync from reset master log-pos."
	echo "[rw/ro] by default slave is set to read-only (ro) which can be changed to write-enabled (rw: carefull it can break replication)" 
	echo "[reset mypwd] applicable for master / slave; sometimes master needs a reset; restart / reset and resync slave as next step.."
	echo "mypwd is the mysql-root-pwd, rpwd is the replication pwd which has to be the same on master / slave side."
	echo "mysql id is optional and will not be changed if it already exists; by default master: 101, slave: 111."
	echo "when setting up master the remote slaves to allow connect can also be a subnet like '192.168.%'."
	echo "when syncig slave a restore done on slave side is a prerequisite indicated by a master-logpos-* file"
	exit 0
fi

if [ $# -gt 0 ] && [ "$1" = "master" ]
then
	if [ $# -lt 4 ]
	then
		echo "please all parameters for master: mysql-root-pwd, slave-host allowed to connect, replication pwd and optionally the mysql-id"
		exit 1
	fi
	MPWD="$2"
	SHOST="$3"
	RPWD="$4"
	if [ $# -eq 5 ]
	then
		ID=$5
	else
		ID=101
	fi
	SQL="DELETE FROM mysql.user WHERE User='rslave'; FLUSH PRIVILEGES; CREATE USER 'rslave'@'${SHOST}' IDENTIFIED BY '$RPWD'; CREATE USER 'rslave'@'localhost' IDENTIFIED BY '$RPWD'; GRANT REPLICATION SLAVE, REPLICATION CLIENT ON *.* TO 'rslave'@'${SHOST}'; GRANT REPLICATION SLAVE, REPLICATION CLIENT ON *.* TO 'rslave'@'localhost'; FLUSH PRIVILEGES; RESET MASTER;"
	$MYSQL -uroot -p$MPWD -e "$SQL" >/tmp/out.sql 2>&1
	ERR=$?
	if [ "$ERR" -eq 1 ]
	then
		echo "error setting up master and replication user"
		cat /tmp/out.sql
		exit 1
	fi
	# modify mysql configuration section followed by restart if needed
	test -e "$MYETC"/my.cnf || touch "$MYETC"/my.cnf
	if ! grep -q "server-id" "$MYETC"/my.cnf || ! grep -q "log-bin" "$MYETC"/my.cnf
	then
		if ! grep -q "[mysqld]" "$MYETC"/my.cnf
		then
			echo -e "[mysqld]" >> "$MYETC"/my.cnf
		fi
		if ! grep -q "server-id" "$MYETC"/my.cnf
		then
			echo -e "server-id = $ID" >> "$MYETC"/my.cnf
		fi
		if ! grep -q "report-host" "$MYETC"/my.cnf
		then
			RHOST=$(hostname)
			echo -e "report-host = $RHOST" >> "$MYETC"/my.cnf
		fi
		if ! grep -q "log-bin" "$MYETC"/my.cnf
		then
			echo -e "log-bin" >> "$MYETC"/my.cnf
		fi
		if ! grep -q "log_error" "$MYETC"/my.cnf
		then
			echo -e "log_error = mysqld-bin-log.err" >> "$MYETC"/my.cnf
		fi
		if ! grep -q "binlog-format" "$MYETC"/my.cnf
		then
			echo -e "binlog-format = mixed" >> "$MYETC"/my.cnf
		fi
		if ! grep -q "binlog-format" "$MYETC"/my.cnf
		then
			echo -e "binlog-format = mixed" >> "$MYETC"/my.cnf
		fi
		if ! grep -q "binlog_do_db" "$MYETC"/my.cnf || ! grep -q "$DB_NAME" "$MYETC"/my.cnf
		then
			echo -e "binlog_do_db = $DB_NAME" >> "$MYETC"/my.cnf
		fi
		if ! grep -q "sync_binlog" "$MYETC"/my.cnf
		then
			echo -e "sync_binlog = 1" >> "$MYETC"/my.cnf
		fi
		if ! grep -q "expire_logs_days" "$MYETC"/my.cnf
		then
			echo -e "expire_logs_days = 5" >> "$MYETC"/my.cnf
		fi
		if ! grep -q "innodb_flush_log_at_trx_commit" "$MYETC"/my.cnf
		then
			echo -e "innodb_flush_log_at_trx_commit = 1" >> "$MYETC"/my.cnf
		fi		
		echo "restarting mysql post configuration changes for master..."
		chmod 600 "$MYETC"/my.cnf
		if [ "$MYETC" = "/var/packages/MariaDB10/etc" ]
		then
			/var/packages/MariaDB10/scripts/start-stop-status restart
		else
			/var/packages/MariaDB/scripts/start-stop-status restart		
		fi
	fi
	sed -i -e "s~K_REPLICATION=\"$K_REPLICATION\"~K_REPLICATION=\"MASTER\"~" "$CFG"
	sed -i -e "s~K_REPLICATION_PWD=\"$K_REPLICATION_PWD\"~K_REPLICATION_PWD=\"$RPWD\"~" "$CFG"
	echo "replication master set up including slave users to allow connection.."
	exit 0
fi
if [ $# -gt 0 ] && [ "$1" = "slave" ]
then
	if [ $# -lt 4 ]
	then
		echo "please all parameters for slave: mysql-root-pwd, master-host to connect to, replication pwd and optionally the mysql-id"
		exit 1
	fi
	MPWD="$2"
	MHOST="$3"
	RPWD="$4"
	if [ $# -eq 5 ]
	then
		ID=$5
	else
		ID=111
	fi
	SQL="DELETE FROM mysql.user WHERE User='rslave'; FLUSH PRIVILEGES; CREATE USER 'rslave'@'${MHOST}' IDENTIFIED BY '$RPWD'; CREATE USER 'rslave'@'localhost' IDENTIFIED BY '$RPWD'; GRANT REPLICATION SLAVE, REPLICATION CLIENT ON *.* TO 'rslave'@'${MHOST}'; GRANT REPLICATION SLAVE, REPLICATION CLIENT ON *.* TO 'rslave'@'localhost'; FLUSH PRIVILEGES;"
	$MYSQL -uroot -p$MPWD -e "$SQL" >/tmp/out.sql 2>&1
	ERR=$?
	if [ "$ERR" -eq 1 ]
	then
		echo "error setting up replication user"
		cat /tmp/out.sql
		exit 1
	fi	
	# modify mysql configuration section followed by restart if needed
	test -e "$MYETC"/my.cnf || touch "$MYETC"/my.cnf
	# key entry to identify slave combined with server-id
	if ! grep -q "server-id" "$MYETC"/my.cnf || ! grep -q "log-slave-updates" "$MYETC"/my.cnf
	then
		if ! grep -q "[mysqld]" "$MYETC"/my.cnf
		then
			echo -e "[mysqld]" >> "$MYETC"/my.cnf
		fi
		if ! grep -q "server-id" "$MYETC"/my.cnf
		then
			echo -e "server-id = $ID" >> "$MYETC"/my.cnf
		fi
		if ! grep -q "report-host" "$MYETC"/my.cnf
		then
			RHOST=$(hostname)
			echo -e "report-host = $RHOST" >> "$MYETC"/my.cnf
		fi
		if ! grep -q "relay-log" "$MYETC"/my.cnf
		then 
			echo -e "relay-log = mysql-relay-bin" >> "$MYETC"/my.cnf
		fi
		if ! grep -q "log-slave-updates" "$MYETC"/my.cnf
		then
			echo -e "log-slave-updates = 1" >> "$MYETC"/my.cnf
		fi
		if ! grep -q "read-only" "$MYETC"/my.cnf
		then
			echo -e "read-only = 1" >> "$MYETC"/my.cnf
		fi
		# remove empty lines
		sed -i '/^$/d' "$MYETC"/my.cnf
		echo "restarting mysql post configuration changes for slave..."
		chmod 600 "$MYETC"/my.cnf
		if [ "$MYETC" = "/var/packages/MariaDB10/etc" ]
		then
			/var/packages/MariaDB10/scripts/start-stop-status restart
		else
			/var/packages/MariaDB/scripts/start-stop-status restart		
		fi
	fi
	# now conenct the slave to master by replication user but do not sync in
	SQL="STOP SLAVE; CHANGE MASTER TO MASTER_HOST='$MHOST', MASTER_USER='rslave', MASTER_PASSWORD='$RPWD';"
	$MYSQL -uroot -p$MPWD -e "$SQL" >/tmp/out.sql 2>&1
	ERR=$?
	if [ "$ERR" -eq 1 ]
	then
		echo "error setting up replication user"
		cat /tmp/out.sql
		exit 1
	fi
	sed -i -e "s~K_REPLICATION=\"$K_REPLICATION\"~K_REPLICATION=\"SLAVE\"~" "$CFG"
	sed -i -e "s~K_REPLICATION_PWD=\"$K_REPLICATION_PWD\"~K_REPLICATION_PWD=\"$RPWD\"~" "$CFG"
	echo "replication slave set up and connected; run full resync or syncin action to start with master-log-pos from restore.."
	exit 0
fi
if [ $# -gt 0 ] && [ "$1" = "slave-add" ]
then
	if [ "$K_REPLICATION" != "MASTER" ]
	then
		echo "pleae run this on configured replication master host"
		exit 1	
	fi
	if [ $# -lt 3 ]
	then
		echo "please all parameters for adding slave to master: mysql-root-pwd, slave-host allowed to connect"
		exit 1
	fi
	MPWD="$2"
	SHOST="$3"
	RPWD="$K_REPLICATION_PWD"
	SQL="CREATE USER 'rslave'@'${SHOST}' IDENTIFIED BY '$RPWD'; GRANT REPLICATION SLAVE, REPLICATION CLIENT ON *.* TO 'rslave'@'${SHOST}'; FLUSH PRIVILEGES;"
	$MYSQL -uroot -p$MPWD -e "$SQL" >/tmp/out.sql 2>&1
	ERR=$?
	if [ "$ERR" -eq 1 ]
	then
		echo "error setting up additional replication user"
		cat /tmp/out.sql
		exit 1
	fi
	echo "added slave $SHOST to connect to this master"
	exit 0
fi
if [ $# -gt 0 ] && [ "$1" = "syncin" ]
then
	if [ "$K_REPLICATION" != "SLAVE" ]
	then
		echo "pleae run this on configured replication slave host"
		exit 1	
	fi
	if [ $# -lt 2 ]
	then
		echo "pleae provide myqsl root pwd for this operation"
		exit 1
	fi
	if [ -e "$DUMP_PATH"/master-logpos-* ]
	then 
			LOGSYNC=$(cat "$DUMP_PATH"/master-logpos-*)
			echo "running: $LOGSYNC"
	else
		echo "no $DUMP_PATH/master-logpos-* found; run restore first using dump with master-log information; exiting.."
		exit 1
	fi
	SQL="STOP SLAVE; RESET SLAVE; $LOGSYNC; START SLAVE;"
	$MYSQL -uroot -p$2 -e "$SQL" >/tmp/out.sql 2>&1
	ERR=$?
	if [ $ERR -eq 1 ]
	then
		echo "syncing slave error"
		cat /tmp/out.sql
		exit 1
	fi
	if grep -q ";read-only" "$MYETC"/my.cnf
	then
		sed -i -e "s~;read-only = 1~read-only = 1~" "$MYETC"/my.cnf
		echo "restarting mysql to make slave read-only enabled"
		if [ "$MYETC" = "/var/packages/MariaDB10/etc" ]
		then
			/var/packages/MariaDB10/scripts/start-stop-status restart
		else
			/var/packages/MariaDB/scripts/start-stop-status restart		
		fi
	fi
fi
if [ $# -gt 0 ] && [ "$1" = "resync" ]
then
	if [ "$K_REPLICATION" != "SLAVE" ]
	then
		echo "pleae run this on configured replication slave host"
		exit 1	
	fi
	if [ $# -lt 2 ]
	then
		echo "pleae provide myqsl root pwd for this operation"
		exit 1
	fi
	SQL="SHOW SLAVE STATUS\G"
	$MYSQL -urslave -p$K_REPLICATION_PWD -e "$SQL" >/tmp/out.sql 2>&1
	ERR=$?
	if [ $ERR -eq 1 ]
	then
		echo "error collecting mysl slave status"
		cat /tmp/out.sql
		exit 1
	fi
	MSVR=$(grep -a Master_Host /tmp/out.sql | cut -d':' -f2-)	
	MUSR=$(grep -a Master_User /tmp/out.sql | cut -d':' -f2-)
	SQL="SHOW MASTER STATUS\G;"
	$MYSQL -u$MUSR -p$K_REPLICATION_PWD -h$MSVR -e "$SQL" >/tmp/out.sql 2>&1
	ERR=$?
	if [ $ERR -eq 1 ]
	then
		echo "error collecting mysl master status"
		cat /tmp/out.sql
		exit 1
	fi
	LFNO=$(grep -a File /tmp/out.sql | cut -d':' -f2- | cut -c 2-)
	LPOS=$(grep -a Position /tmp/out.sql | cut -d':' -f2- | cut -c 2-)
	LOGSYNC="CHANGE MASTER TO MASTER_LOG_FILE='${LFNO}', MASTER_LOG_POS=${LPOS}"
	SQL="STOP SLAVE; RESET SLAVE; $LOGSYNC; START SLAVE;"
	$MYSQL -uroot -p$2 -e "$SQL" >/tmp/out.sql 2>&1
	ERR=$?
	if [ $ERR -eq 1 ]
	then
		echo "syncing slave error"
		cat /tmp/out.sql
		exit 1
	fi
	if grep -q ";read-only" "$MYETC"/my.cnf
	then
		sed -i -e "s~;read-only = 1~read-only = 1~" "$MYETC"/my.cnf
		echo "restarting mysql to make slave read-only enabled"
		if [ "$MYETC" = "/var/packages/MariaDB10/etc" ]
		then
			/var/packages/MariaDB10/scripts/start-stop-status restart
		else
			/var/packages/MariaDB/scripts/start-stop-status restart		
		fi
	fi
fi
if [ $# -gt 0 ] && [ "$1" = "start" ]
then
	if [ "$K_REPLICATION" != "SLAVE" ]
	then
		echo "pleae run this on configured replication slave host"
		exit 1	
	fi
	if [ $# -lt 2 ]
	then
		echo "pleae provide myqsl root pwd for this operation"
		exit 1
	fi
	SQL="START SLAVE;"
	$MYSQL -uroot -p$2 -e "$SQL" >/tmp/out.sql 2>&1
	ERR=$?
	if [ $ERR -eq 1 ]
	then
		echo "starting slave error"
		cat /tmp/out.sql
		exit 1
	fi
fi
if [ $# -gt 0 ] && [ "$1" = "stop" ]
then
	if [ "$K_REPLICATION" != "SLAVE" ]
	then
		echo "pleae run this on configured replication slave host"
		exit 1	
	fi
	if [ $# -lt 2 ]
	then
		echo "pleae provide myqsl root pwd for this operation"
		exit 1
	fi
	SQL="STOP SLAVE;"
	$MYSQL -uroot -p$2 -e "$SQL" >/tmp/out.sql 2>&1
	ERR=$?
	if [ $ERR -eq 1 ]
	then
		echo "stoping slave error"
		cat /tmp/out.sql
		exit 1
	fi
fi
if [ $# -gt 0 ] && [ "$1" = "skip" ]
then
	if [ "$K_REPLICATION" != "SLAVE" ]
	then
		echo "pleae run this on configured replication slave host"
		exit 1	
	fi
	if [ $# -lt 2 ]
	then
		echo "pleae provide myqsl root pwd for this operation"
		exit 1
	fi
	SQL="STOP SLAVE; SET GLOBAL SQL_SLAVE_SKIP_COUNTER = 1; START SLAVE;"
	$MYSQL -uroot -p$2 -e "$SQL" >/tmp/out.sql 2>&1
	ERR=$?
	if [ $ERR -eq 1 ]
	then
		echo "skiping mysl slave error"
		cat /tmp/out.sql
		exit 1
	fi
fi
if [ $# -gt 0 ] && [ "$1" = "remove" ]
then
	if [ "$K_REPLICATION" != "SLAVE" ]
	then
		echo "pleae run this on configured replication slave host"
		exit 1	
	fi
	if [ $# -lt 2 ]
	then
		echo "pleae provide myqsl root pwd for this operation"
		exit 1
	fi
	# since mysql 5.5 use reset slave all to avoid reconnect
	SQL="STOP SLAVE; RESET SLAVE ALL;"
	$MYSQL -uroot -p$2 -e "$SQL" >/tmp/out.sql 2>&1
	ERR=$?
	if [ $ERR -eq 1 ]
	then
		echo "remove / reset mysl slave error"
		cat /tmp/out.sql
		exit 1
	fi
	# remove slave entries from config then empty lines and restart
	sed -i -e "s~relay-log = mysql-relay-bin~~" "$MYETC"/my.cnf
	sed -i -e "s~log-slave-updates = 1~~" "$MYETC"/my.cnf
	sed -i -e "s~log-slave-updates = 1~~" "$MYETC"/my.cnf
	sed -i -e "s~;read-only = 1~~" "$MYETC"/my.cnf
	sed -i '/^$/d' "$MYETC"/my.cnf
	sed -i -e "s~K_REPLICATION=\"$K_REPLICATION\"~K_REPLICATION=\"OFF\"~" "$CFG"
	echo "removal and reset all for slave done restarting mysql"
	if [ "$MYETC" = "/var/packages/MariaDB10/etc" ]
	then
		/var/packages/MariaDB10/scripts/start-stop-status restart
	else
		/var/packages/MariaDB/scripts/start-stop-status restart		
	fi
	exit 0
fi
if [ $# -gt 0 ] && [ $1 = "rw" ]
then
	if [ "$K_REPLICATION" != "SLAVE" ]
	then
		echo "pleae run this on configured replication slave host"
		exit 1	
	fi
	sed -i -e "s~^read-only = 1~;read-only = 1~" "$MYETC"/my.cnf
	echo "restarting mysql to make slave write-enabled (careful: rw can break replication)"
	if [ "$MYETC" = "/var/packages/MariaDB10/etc" ]
	then
		/var/packages/MariaDB10/scripts/start-stop-status restart
	else
		/var/packages/MariaDB/scripts/start-stop-status restart		
	fi
	exit 0
fi
if [ $# -gt 0 ] && [ "$1" = "ro" ]
then
	if [ "$K_REPLICATION" != "SLAVE" ]
	then
		echo "pleae run this on configured replication slave host"
		exit 1	
	fi
	sed -i -e "s~;read-only = 1~read-only = 1~" "$MYETC"/my.cnf
	echo "restarting mysql to make slave read-only (default to protect replication)"
	if [ "$MYETC" = "/var/packages/MariaDB10/etc" ]
	then
		/var/packages/MariaDB10/scripts/start-stop-status restart
	else
		/var/packages/MariaDB/scripts/start-stop-status restart		
	fi
	exit 0
fi
if [ $# -gt 0 ] && [ "$1" = "reset" ]
then
	if [ "$K_REPLICATION" != "MASTER" ] && [ $K_REPLICATION != "SLAVE" ]
	then
		echo "pleae run this on configured replication master or slave host"
		exit 1	
	fi
	if [ $# -lt 2 ]
	then
		echo "pleae provide myqsl root pwd for this operation"
		exit 1
	fi
	if [ "$K_REPLICATION" = "MASTER" ]
	then
		SQL="RESET MASTER;"
	else
		SQL="STOP SLAVE; RESET SLAVE;"	
	fi
	$MYSQL -uroot -p$2 -e "$SQL" >/tmp/out.sql 2>&1
	ERR=$?
	if [ $ERR -eq 1 ]
	then
		echo "reset mysl error"
		cat /tmp/out.sql
		exit 1
	fi
	echo "reset done incl. write-enabled; restart on slave side or restore slave and syncin again.."
	if grep -q "^read-only" "$MYETC"/my.cnf
	then
		sed -i -e "s~read-only = 1~;read-only = 1~" "$MYETC"/my.cnf
		echo "restarting mysql to make slave write enabled"
		if [ "$MYETC" = "/var/packages/MariaDB10/etc" ]
		then
			/var/packages/MariaDB10/scripts/start-stop-status restart
		else
			/var/packages/MariaDB/scripts/start-stop-status restart		
		fi
	fi
fi
# default status mode
if [ "$K_REPLICATION" = "OFF" ]
then
	echo "kopano mysql replication is disabled; select action 'master' or 'slave'; see help for details"
	exit 1
fi
# default if no parameters or status is given
if [ "$K_REPLICATION" = "SLAVE" ]
then
	SQL="SHOW SLAVE STATUS\G"
	$MYSQL -urslave -p$K_REPLICATION_PWD -e "$SQL" >/tmp/out.sql 2>&1
	ERR=$?
	if [ $ERR -eq 1 ]
	then
		echo "error collecting mysl slave status"
		cat /tmp/out.sql
		exit 1
	fi
	# using grep -a to deal with pseudo binary file
	SLIO=$(grep Slave_IO_Running /tmp/out.sql | cut -d':' -f2-)
	# skip Slave_SQL_Running_State so only 1stl line via head -1
	SLSQL=$(grep -a Slave_SQL_Running /tmp/out.sql | head -1 | cut -d':' -f2-)
	SLSEC=$(grep -a Seconds_Behind_Master /tmp/out.sql | cut -d':' -f2- | cut -c 2-)
	MSVR=$(grep -a Master_Host /tmp/out.sql | cut -d':' -f2-)
	MUSR=$(grep -a Master_User /tmp/out.sql | cut -d':' -f2-)
	SERR=$(grep -a Last_Error /tmp/out.sql | cut -d':' -f2-)
	MSG=""
	RERR=0
	if [ "$SLIO" != " Yes" ] && [ "$SLSQL" != " Yes" ]
	then
		MSG="io&sql replication stopped"
		RERR=1
	else
		if [ "$SLIO" != " Yes" ]
		then
			MSG="io replication stopped"
			RERR=1
		fi
		if [ "$SLSQL" != " Yes" ]
		then
			MSG="sql replication stopped"
			RERR=1
		fi
		if [ "$SLIO" = " Yes" ] && [ "$SLSQL" = " Yes" ]
		then
			MSG="io&sql replication running"
		fi
	fi
	if [ "$SERR" != " " ]
	then
		RERR=1
		MSG="${MSG}${SERR}"
	fi
	if [ $RERR -eq 0 ] && [ $SLSEC != "NULL" ]
	then
		MSG="$MSG $SLSEC sec behind master"
		if [ $SLSEC -gt 100 ]
		then
			RERR=1	
		fi
	fi
	if [ $# -gt 0 ] && [ $1 = "health" ] && [ $RERR -eq 0 ]
	then
		SQL="SHOW MASTER STATUS\G; SHOW SLAVE HOSTS\G"
		$MYSQL -u$MUSR -p$K_REPLICATION_PWD -h$MSVR -e "$SQL" >/tmp/out.sql 2>&1
		ERR=$?
		if [ $ERR -eq 1 ]
		then
			echo "error collecting mysl master status"
			cat /tmp/out.sql
			exit 1
		fi
		LFNO=$(grep -a File /tmp/out.sql | cut -d':' -f2-)
		LPOS=$(grep -a Position /tmp/out.sql | cut -d':' -f2-)
		SSVR=$(grep -a Host /tmp/out.sql | cut -d':' -f2- | cut -c 2-)
		MSG="${MSG}:${LFNO} at${LPOS}"
	else
		if [ $RERR -eq 0 ]
		then
			MSG="${MSG}:${MSVR}"
		fi
	fi
	echo "$MSG"
	if [ $RERR -gt 0 ] && [ "$NOTIFY" = "ON" ]
	then
		/usr/syno/bin/synodsmnotify "$NOTIFYTARGET" kopano-replication "$MSG"
		exit 1
	fi
	exit 0
fi
if [ "$K_REPLICATION" = "MASTER" ]
then
	SQL="SHOW MASTER STATUS\G; SHOW SLAVE HOSTS\G"
	$MYSQL -urslave -p$K_REPLICATION_PWD -e "$SQL" >/tmp/out.sql 2>&1
	ERR=$?
	if [ $ERR -eq 1 ]
	then
		echo "error collecting mysl master status"
		cat /tmp/out.sql
		exit 1
	fi	
	LFNO=$(grep -a File /tmp/out.sql | cut -d':' -f2-)
	LPOS=$(grep -a Position /tmp/out.sql | cut -d':' -f2-)
	SSVRS=$(grep -a Host /tmp/out.sql | cut -d':' -f2- | cut -c 2-)
	MSG=""
	RERR=0
	if [ $# -gt 0 ] && [ "$1" = "health" ]
	then
		if [ "$SSVRS" = "" ]
		then
			MSG="error: no connected replication slave(s)"
			RERR=1
		else
			# can be one or many slave servers with spaves in the greped string
			for SSVR in $SSVRS
			do
				RERR=0
				SQL="SHOW SLAVE STATUS\G; select @@hostname\G;"
				$MYSQL -urslave -p$K_REPLICATION_PWD -h$SSVR -e "$SQL" >/tmp/out.sql 2>&1
				ERR=$?
				if [ $ERR -eq 1 ]
				then
					echo "error collecting mysl slave status"
					cat /tmp/out.sql
					exit 1
				fi
				SLIO=$(grep Slave_IO_Running /tmp/out.sql | cut -d':' -f2-)
				# skip Slave_SQL_Running_State so only 1stl line via head -1
				SLSQL=$(grep -a Slave_SQL_Running /tmp/out.sql | head -1 | cut -d':' -f2-)
				SLSEC=$(grep -a Seconds_Behind_Master /tmp/out.sql | cut -d':' -f2- | cut -c 2-)
				MSVR=$(grep -a Master_Host /tmp/out.sql | cut -d':' -f2-)
				MUSR=$(grep -a Master_User /tmp/out.sql | cut -d':' -f2-)
				SERR=$(grep -a Last_Error /tmp/out.sql | cut -d':' -f2-)
				SHST=$(grep -a hostname /tmp/out.sql | cut -d':' -f2- | cut -c 2-)
				if [ "$SLIO" != " Yes" ] && [ "$SLSQL" != " Yes" ]
				then
					MSG="io&sql replication $SSVR stopped"
					RERR=1
				else
					if [ "$SLIO" != " Yes" ]
					then
						MSG="io replication $SSVR stopped"
						RERR=1
					fi
					if [ "$SLSQL" != " Yes" ]
					then
						MSG="sql replication $SSVR stopped"
						RERR=1
					fi
					if [ "$SLIO" = " Yes" ] && [ "$SLSQL" = " Yes" ]
					then
						MSG="io&sql replication $SSVR running"	
					fi
				fi
				if [ "$SHST" != "$SSVR" ]
				then
					RERR=1
					MSG="${MSG} Missmatch connected slave $SSVR vs. SQL-host: $SHST"
				fi
				if [ "$SERR" != " " ]
				then
					RERR=1
					MSG="${MSG}${SERR}"
				fi
				if [ $RERR -eq 0 ] && [ $SLSEC != "NULL" ]
				then
					MSG="$MSG $SLSEC sec behind master:${LFNO} at${LPOS}"
					if [ $SLSEC -gt 100 ]
					then
						RERR=1
					fi
				fi
				echo "$MSG"
				if [ $RERR -gt 0 ] && [ "$NOTIFY" = "ON" ]
				then
					/usr/syno/bin/synodsmnotify "$NOTIFYTARGET" kopano-replication "$MSG"
				fi
			done
		fi
	else
		# without health and multible slave loop
		MSG="replication running to slave $SSVRS by ${MSVR}${LFNO} at${LPOS}"
		echo "$MSG"
		if [ $RERR -gt 0 ] && [ "$NOTIFY" = "ON" ]
		then
			/usr/syno/bin/synodsmnotify "$NOTIFYTARGET" kopano-replication "$MSG"
			exit 1
		fi
	fi
	exit 0
fi

