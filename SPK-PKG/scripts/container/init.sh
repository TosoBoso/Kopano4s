#!/bin/sh
# (c) 2018 vbettag initialisation for Kopano4Syno in Docker container
# kopano-monitor, gateway, ical disabled by default and added if found in etc-default
if [ ! -e /etc/kopano/default ] && [ -e /etc/kopano/default.init ] ; then cp /etc/kopano/default.init /etc/kopano/default ; fi
# Community new feature remove -d(emonized) for dagent from default for community edition and do it reverse if downgraded
if [ "$EDITION" = "Community" ] && grep -q "^DAGENT_OPTS" /etc/kopano/default ; then sed -i -e 's~DAGENT_OPTS~#DAGENT_OPTS~' /etc/kopano/default ; fi
if [ "$EDITION" != "Community" ] && grep -q "^#DAGENT_OPTS" /etc/kopano/default ; then sed -i -e 's~#DAGENT_OPTS~DAGENT_OPTS~' /etc/kopano/default ; fi
K_SERVICES="kopano-server kopano-spooler kopano-dagent"
if grep -q ^SEARCH_ENABLED=yes /etc/kopano/default ; then K_SERVICES="$K_SERVICES kopano-search" ; fi
if grep -q ^MONITOR_ENABLED=yes /etc/kopano/default ; then K_SERVICES="$K_SERVICES kopano-monitor" ; fi
if grep -q ^GATEWAY_ENABLED=yes /etc/kopano/default ; then K_SERVICES="$K_SERVICES kopano-gateway" ; fi
if grep -q ^ICAL_ENABLED=yes /etc/kopano/default ; then K_SERVICES="$K_SERVICES kopano-ical" ; fi
W_SERVICES="nginx php${PHP_VER}-fpm"
if [ "$EDITION" != "Migration" ]
then
	if grep -q ^PRESENCE_ENABLED=yes /etc/kopano/default ; then W_SERVICES="$W_SERVICES kopano-presence" ; fi
fi
M_SERVICES="postfix"
if grep -q ^POSTGREY_ENABLED=yes /etc/kopano/default ; then M_SERVICES="$M_SERVICES postgrey" ; fi
if grep -q ^CLAMAVD_ENABLED=yes /etc/kopano/default ; then M_SERVICES="$M_SERVICES clamav-daemon" ; fi
if grep -q ^AMAVISD_ENABLED=yes /etc/kopano/default ; then M_SERVICES="$M_SERVICES amavis" ; fi
if grep -q ^SPAMD_ENABLED=yes /etc/kopano/default ; then M_SERVICES="$M_SERVICES kopano-spamd" ; fi
if grep -q ^FETCHMAIL_ENABLED=yes /etc/kopano/default ; then M_SERVICES="$M_SERVICES fetchmail" ; fi
if grep -q ^COURIER_IMAP_ENABLED=yes /etc/kopano/default ; then M_SERVICES="$M_SERVICES courier-imap" ; fi
S_SERVICES="rsyslog cron"
# run as user-id, group-id to access cfg and log files from synology: default=100=users changed at build time
if [ -e /etc/kopano/kuid ]
then
	RUN_UID=`cat /etc/kopano/kuid`
	AMA_UID=`cat /etc/kopano/auid`
	RUN_GID=`cat /etc/kopano/kgid`
else
	RUN_UID=1030
	AMA_UID=1031
	RUN_GID=65540
fi
RUN_GROUP="kopano"
KSVRPID="/var/run/kopano/server.pid"
KSPLPID="/var/run/kopano/spooler.pid"
KDAGPID="/var/run/kopano/dagent.pid"
KSEAPID="/var/run/kopano/search.pid"
KGWYPID="/var/run/kopano/gateway.pid"
KICLPID="/var/run/kopano/ical.pid"
KMONPID="/var/run/kopano/monitor.pid"
KPRESPID="/var/run/kopano/presence.pid"
AMAVPID="/var/run/amavis/amavis.pid"
CLAMPID="/var/run/clamav/clamd.pid"
CLAMPLD="/var/run/clamav/clamd.load"
CLAMCTL="/var/run/clamav/clamd.ctl"
PFIXPID="/var/spool/postfix/pid/master.pid"
PGRYPID="/var/run/postgrey.pid"
FEMLPID="/var/run/fetchmail/fetchmail.pid"
PHPFPMPID="/var/run/php/php${PHP_VER}-fpm.pid"
SYSLPID="/var/run/rsyslogd.pid"
NGINXPID="/var/run/nginx.pid"
IMAPDPID="/var/run/courier/imapd.pid"

mysql_sock_on()
{
	# if we have not initialized theremight be no server.cfg
	if [ -e /etc/init.done ]
	then
		SQL_SOCK=$(grep mysql_socket /etc/kopano/server.cfg | cut -d "=" -f2- | sed "s~^ *~~")
		if [ -z "$SQL_SOCK" ]
		then
			echo "missing mysql_socket definition in server.cfg (should be: /run/mysqld/mysqld10.sock); exiting..."
			return 1	
		fi
		# loop some time waiting fo mysql socket
		if [ ! -e "$SQL_SOCK" ] 
		then
			echo "waiting for mysql socket being available at $SQL_SOCK ..." 
		fi
		for i in 0 1 2 3 4 5 6 7 8 9
		do
			if [ -e "$SQL_SOCK" ]
			then
				return 0
			fi
			sleep 10
		done
		echo "giving up no MySQL found; restart package or run kopano-init reset to address mount issues"
		touch /etc/kopano/mount.issue
		return 1
	fi
}
# status for all kopano core daemons defined in K_SERVICES
k_srv_on()
{
	local DAEMON=$1
	# secial case restart or rest hit alive loop return running
	if [ -e /etc/kopano.restart ]
	then
		return 0
	fi
	# disabled daemon and not part of services then we would return ok
	if echo $K_SERVICES | grep -q "$DAEMON"
	then
		if service $DAEMON status | grep -q "is running"
		then
			return 0
		else
			return 1
		fi
	else
		return 0
	fi
}
# status for all kopano mail daemons defined in M_SERVICES
m_srv_on()
{
	local DAEMON=$1
	# secial case restart or rest hit alive loop return running
	if [ -e /etc/kopano.restart ]
	then
		return 0
	fi
	# disabled daemon and not part of services then we would return ok
	if echo $M_SERVICES | grep -q "$DAEMON"
	then
		if service $DAEMON status | grep -q "is running"
		then
			return 0
		else
			# special case fetchmail under buster init file not working
			if [ "$DAEMON" = "fetchmail" ]
			then
				local PIDFILE="/var/run/fetchmail/fetchmail.pid"
				if test -e $PIDFILE
				then
					local PID=$(ps -ef | grep -v grep | grep fetchmail | head -1 | awk '{print $2}')
					if [ -n "$PID" ] && grep -q $PID $PIDFILE
					then
						return 0
					else
						return 1
					fi
				else		
					return 1
				fi
			else
				return 1			
			fi
			return 1			
		fi
	else
		return 0
	fi
}
# status for all kopano web daemons defined in W_SERVICES
w_srv_on()
{
	local DAEMON=$1
	# secial case restart or rest hit alive loop return running
	if [ -e /etc/kopano.restart ]
	then
		return 0
	fi
	# disabled daemon and not part of services then we would return ok
	if echo $W_SERVICES | grep -q "$DAEMON"
	then
		if service $DAEMON status | grep -q "is running"
		then
			return 0
		else
			return 1
		fi
	else
		return 0
	fi
}
# status for all kopano system daemons defined in W_SERVICES
s_srv_on()
{
	local DAEMON=$1
	# secial case restart or rest hit alive loop return running
	if [ -e /etc/kopano.restart ]
	then
		return 0
	fi
	# disabled daemon and not part of services then we would return ok
	if echo $S_SERVICES | grep -q "$DAEMON"
	then
		if service $DAEMON status | grep -q "is running"
		then
			return 0
		else
			return 1
		fi
	else
		return 0
	fi
}
start_kopano()
{
	if [ -e /etc/init.done ]
	then
		TS=`cat /etc/kinit.done`
		echo "starting kopano4s-image initialised at $TS.."
	fi
	echo "Starting Kopano core ..."
	for S in $K_SERVICES; do
		service $S start
	done
	echo "Starting Kopano web ..."
	for S in $W_SERVICES; do
		service $S start
	done
	echo "Starting Kopano mail ..."
	for S in $M_SERVICES; do
		service $S start
	done
	echo "Starting Kopano sys ..."
	for S in $S_SERVICES; do
		service $S start >/tmp/service.out 2>/tmp/service.err
		# filter out warnings on non-priviledged access to imklog and /proc/kmsg
		cat /tmp/service.out && cat /tmp/service.err | grep -v imklog | grep -v kmsg
	done
	# special case clamav-daemon loading long in bg mode: restart amavisd after ~3-6 min..
	if grep -q ^CLAMAVD_ENABLED=yes /etc/kopano/default
	then
		echo "Started  clamav-daemon in bg mode restarting amavis once it is loaded.."
		echo "$(date "+%Y.%m.%d-%H:%M:%S") Started clamav-daemon in bg mode restarting amavis once it is loaded.." >/var/log/clamd-bgload.log
		if [ -e "$CLAMCTL" ] ; then rm "$CLAMCTL" ; fi
		# mark for this script clamd loading via clamd.load and fake running via PID file
		touch "$CLAMPLD"
		local PID=$(ps -ef | grep -v grep | grep clamd | head -1 | awk '{print $2}')
		echo "$PID" > "$CLAMPID"
		chown clamav.clamav "$CLAMPID"
	fi
	if [ -e /tmp/service.out ]
	then
		rm /tmp/service.out
	fi
	if [ -e /tmp/service.err ]
	then
		rm /tmp/service.err
	fi
	# remove flag for special case restart
	if [ -e /etc/kopano.restart ]
	then
		rm /etc/kopano.restart
	fi
}
stop_kopano()
{
	echo "Stopping Kopano core..."
	for S in $K_SERVICES; do
		if service $S status | grep -q "is running"
		then
			echo "stopping $S.."
			service $S stop >/dev/null
		fi
	done
	echo "Stopping Kopano web..."
	for S in $W_SERVICES; do
		if service $S status | grep -q "is running"
		then
			echo "stopping $S.."
			service $S stop >/dev/null
		fi
	done
	echo "Stopping Kopano mail..."
	for S in $M_SERVICES; do
		if service $S status | grep -q "is running"
		then
			echo "stopping $S.."
			service $S stop >/dev/null
		fi
	done
	echo "Stopping Kopano sys..."
	for S in $S_SERVICES; do
		if service $S status | grep -q "is running"
		then
			echo "stopping $S.."
			service $S stop >/dev/null
		fi
	done
}
kill_kopano()
{
	for S in $K_SERVICES; do
		killall -q -9 $S
	done
	for S in $W_SERVICES; do
		killall -q -9 $S
	done
	for S in $M_SERVICES; do
		killall -q -9 $S
	done
	for S in $S_SERVICES; do
		killall -q -9 $S
	done
	# remove stale pids
	if ls /var/run/kopano/*.pid >/dev/null 2>&1; then rm /var/run/kopano/*.pid ; fi
	if [ -e "$AMAVPID" ] ; then rm -f "$AMAVPID" ; fi
	if [ -e "$CLAMPID" ] ; then rm -f "$CLAMPID" ; fi
	if [ -e "$CLAMPLD" ] ; then rm -f "$CLAMPLD" ; fi
	if [ -e "$PGRYPID" ] ; then rm -f "$PGRYPID" ; fi
	if [ -e "$FEMLPID" ] ; then rm -f "$FEMLPID" ; fi
	if [ -e /var/run/fetchmail/fetchmail.pid ] ; then rm -f /var/run/fetchmail/fetchmail.pid ; fi
}
set_acl()
{
	# remove dangling softlink
	if [ -h /etc/kopano/kopano ] ; then rm /etc/kopano/kopano ; fi
	chown -R root.kopano /etc/kopano
	if [ -e /etc/kopano/postfix/sasl_passwd ] ; then chown -R root.root /etc/kopano/postfix/sasl_passwd ; fi
	# default mod 750 / 640 in etc-kopano 
	find /etc/kopano/ -type f -exec chmod 640 "{}" ";"
	find /etc/kopano/ -type d -exec chmod 750 "{}" ";"
	chown fetchmail.kopano /etc/kopano/fetchmailrc
	chmod 600 /etc/kopano/fetchmailrc
	# other chmod etc-kopano root, sasl_pwd, z-push, webapp, 
	chmod 751 /etc/kopano
	if [ -e /etc/kopano/postfix/sasl_passwd ] ; then chmod 600 /etc/kopano/postfix/sasl_passwd ; fi
	chmod 751 /etc/kopano/ssl
	chmod 640 /etc/kopano/ssl/*
	chmod 755 /etc/kopano/ssl/clients
	chmod 644 /etc/kopano/ssl/clients/*
	if [ -h /etc/z-push/z-push ] ; then rm /etc/z-push/z-push ; fi
	chown -R root.www-data /etc/z-push
	chmod 751 /etc/z-push
	chmod 640 /etc/z-push/*
	if [ -h /var/lib/z-push/z-push ] ; then rm /var/lib/z-push/z-push ; fi
	chown -R www-data.www-data /var/lib/z-push
	chmod 770 /var/lib/z-push
	if [ -e /var/lib/z-push/users ]
	then
		find /var/lib/z-push -type f -exec chmod 660 "{}" ";"
		find /var/lib/z-push -type d -exec chmod 770 "{}" ";"
	fi
	chmod 751 /etc/kopano/web
	chmod 751 /etc/kopano/webapp
	chown root.www-data /etc/kopano/webapp/*
	chmod 640 /etc/kopano/webapp/*	
	if [ -e /etc/kopano/webapp/dist ]
	then
		chmod 751 /etc/kopano/webapp/dist
		chmod 640 /etc/kopano/webapp/dist/*	
	fi
	# other than etc-kopano: /var/www/html /usr/share-web, /var-log
	chown -R root.www-data /var/www/html && chmod 750 /var/www/html && chmod 640 /var/www/html/*.html
	chown -R root.www-data /usr/share/kopano-webapp
	chown -R root.www-data /usr/share/z-push
	# remove recursive softlink in log-kopano
	if [ -h /var/log/kopano/kopano ] ; then rm /var/log/kopano/kopano ; fi
	chown -R kopano.kopano /var/log/kopano
	chown amavis.kopano /var/log/kopano/amavis.log
	chown amavis.kopano /var/log/kopano/razor-agent.log
	chown amavis.kopano /var/log/kopano/spamassassin.log
	chown root.kopano /var/log/kopano/fetchmail.log
	chown root.kopano /var/log/kopano/mail.*
	chown root.kopano /var/log/kopano/nginx*
	chown root.kopano /var/log/kopano/php-fpm*
	chown root.kopano /var/log/kopano/daemon*
	chown root.kopano /var/log/kopano/messages*
	chown root.kopano /var/log/kopano/syslog*
	chown www-data.kopano /var/log/kopano/webapp-usr.log
	chown -R www-data.kopano /var/log/kopano/z-push/
	find /usr/share/kopano-webapp -type f -exec chmod 640 "{}" ";"
	find /usr/share/kopano-webapp -type d -exec chmod 750 "{}" ";"
	find /usr/share/z-push -type f -exec chmod 640 "{}" ";"
	find /usr/share/z-push -type d -exec chmod 750 "{}" ";"
	# make z-push tools executable: listfolders, z-push-admin, z-push-top, gab-sync, gab2contacts
	chmod 750 /usr/share/z-push/backend/kopano/listfolders.php
	chmod 750 /usr/share/z-push/tools/gab-sync/gab-sync.php
	chmod 750 /usr/share/z-push/tools/gab2contacts/gab2contacts.php
	chmod 750 /usr/share/z-push/z-push-admin.php
	chmod 750 /usr/share/z-push/z-push-top.php
	chmod 771 /var/log/kopano
	chmod 660 /var/log/kopano/*.log
	chmod 660 /var/log/kopano/mail.*
	chmod 770 /var/log/kopano/z-push/
	chmod 660 /var/log/kopano/z-push/*.log
	chmod 660 /var/log/kopano/amavis.log
	chmod 660 /var/log/kopano/razor-agent.log
	chmod 660 /var/log/kopano/clamav.log
	chmod 660 /var/log/kopano/freshclam.log
	chmod 660 /var/log/kopano/spamassassin.log
	if [ -h /var/log/kopano/log ] ; then rm /var/log/kopano/log ; fi
	# all var-run, libs: attachments, postfix related
	if [ -e /var/run/kopano ] ; then chown -R kopano.kopano /var/run/kopano/ ; fi
	chown root.kopano /var/lib/kopano/
	chmod 770 /var/lib/kopano/
	# attachments need kopano.kopano
	chown -R kopano.kopano /var/lib/kopano/attachments
	chmod 770 /var/lib/kopano/attachments
	chown -R root.kopano /var/lib/kopano/backup
	chmod 770 /var/lib/kopano/backup
	# change recursive for attchements, search and other dirs
	find /var/lib/kopano/ -type f -exec chmod 660 "{}" ";"
	find /var/lib/kopano/ -type d -exec chmod 770 "{}" ";"
	chown -R amavis.amavis /run/amavis/
	chown -R amavis.kopano /var/lib/amavis/
	# amavis is also softlinked from clamav and spamassassin
	if [ -e /var/lib/amavis/daily.cvd ] ; then chown clamav.kopano /var/lib/amavis/*.cvd ; fi
	if [ -e /var/lib/amavis/mirrors.dat ] ; then chown clamav.kopano /var/lib/amavis/*.dat ; fi
	if [ -e /var/lib/amavis/daily.cvd ] ; then chmod 640 /var/lib/amavis/*.cvd ; fi
	chmod 771 /var/lib/amavis
	chown -R fetchmail /var/lib/fetchmail/
	chown -R postfix.postfix /var/lib/postfix/
	chown -R postgrey.postgrey /var/lib/postgrey/
	# set all to postfix.root and bring back owners root.root and postfix.postdrop
	chown -R postfix.root /var/spool/postfix/
	chown -R postfix.postdrop /var/spool/postfix/maildrop
	chown -R postfix.postdrop /var/spool/postfix/public
	chown -R root.root /var/spool/postfix/dev
	chown -R root.root /var/spool/postfix/etc
	chown -R root.root /var/spool/postfix/lib
	chown -R root.root /var/spool/postfix/pid
	chown -R root.root /var/spool/postfix/usr
	chmod 750 /etc/kopano/custom/cron.*
}
install_ssl()
{
	if [ -e /etc/kopano/ssl/server.key ] && [ -e /etc/kopano/ssl/server.crt ] && [ -e /etc/kopano/ssl/cacert.pem ]
	then
		# combine key and cert see https://github.com/zokradonh/kopano-docker/blob/master/ssl/start.sh
		cp /etc/kopano/ssl/server.key /etc/kopano/ssl/server.pem
		cat /etc/kopano/ssl/server.crt >> /etc/kopano/ssl/server.pem
		chown root.kopano /etc/kopano/ssl/server.pem
		openssl x509 -in /etc/kopano/ssl/server.crt -pubkey -noout >  /etc/kopano/ssl/clients/server-public.pem
		# soflinks in etc-ssl for nginx, replace of self-cert snakeoil by kopano and enable kopano-core ssl
		ln -sf /etc/kopano/ssl/svrcertbundle.pem /etc/ssl/certs/ssl-cert-kopano.pem
		ln -sf /etc/kopano/ssl/cacert.pem /etc/ssl/certs/ssl-cacert-kopano.pem
		ln -sf /etc/kopano/ssl/server.key /etc/ssl/private/ssl-cert-kopano.key
		mkdir -p /etc/kopano/ical
		ln -sf /etc/kopano/ssl/server.key /etc/kopano/ical/privkey.pem
		ln -sf /etc/kopano/ssl/server.crt /etc/kopano/ical/cert.pem
		mkdir -p /etc/kopano/gateway
		ln -sf /etc/kopano/ssl/server.key /etc/kopano/gateway/privkey.pem
		ln -sf /etc/kopano/ssl/server.crt /etc/kopano/gateway/cert.pem
		sed -i -e 's~cert-snakeoil~cert-kopano~g' /etc/kopano/web/kopano-web.conf
		sed -i -e 's~replace-with-server-cert-password~~' /etc/kopano/server.cfg
		sed -i -e 's~server_listen_tls.*~server_listen_tls = *:237~' /etc/kopano/server.cfg
		sed -i -e 's~^#server_ssl_key_file~server_ssl_key_file~' /etc/kopano/server.cfg
		sed -i -e 's~^#server_ssl_ca_file~server_ssl_ca_file~' /etc/kopano/server.cfg
		sed -i -e 's~^#ssl_private_key_file~ssl_private_key_file~' /etc/kopano/gateway.cfg
		sed -i -e 's~^#ssl_certificate_file~ssl_certificate_file~' /etc/kopano/gateway.cfg
		sed -i -e 's~^#imaps_listen~imaps_listen~' /etc/kopano/gateway.cfg
		sed -i -e 's~^imaps_listen.*~imaps_listen = *:993~' /etc/kopano/gateway.cfg
		sed -i -e 's~^#pop3s_listen~pop3s_listen~' /etc/kopano/gateway.cfg
		sed -i -e 's~^pop3s_listen.*~pop3s_listen = *:995~' /etc/kopano/gateway.cfg
		sed -i -e 's~^#ssl_private_key_file~ssl_private_key_file~' /etc/kopano/ical.cfg
		sed -i -e 's~^#ssl_certificate_file~ssl_certificate_file~' /etc/kopano/ical.cfg
		sed -i -e 's~^#icals_listen~icals_listen~' /etc/kopano/ical.cfg
		sed -i -e 's~^icals_listen.*~icals_listen = *:8443~' /etc/kopano/ical.cfg
	fi
}
disable_ssl()
{
	echo "kopano: disabling SLL for core components due to errors; check logs"
	echo "$(date "+%Y-%m-%d-%H:%M"): disabling SLL for core components due to errors; check logs" > /var/log/kopano/server.log
	sed -i -e 's~server_listen_tls.*~server_listen_tls =~' /etc/kopano/server.cfg
	sed -i -e 's~^server_ssl_key_file~#server_ssl_key_file~' /etc/kopano/server.cfg
	sed -i -e 's~^server_ssl_ca_file~#server_ssl_ca_file~' /etc/kopano/server.cfg
	sed -i -e 's~^ssl_private_key_file~#ssl_private_key_file~' /etc/kopano/gateway.cfg
	sed -i -e 's~^ssl_certificate_file~#ssl_certificate_file~' /etc/kopano/gateway.cfg
	sed -i -e 's~^imaps_listen.*~imaps_listen = ~' /etc/kopano/gateway.cfg
	sed -i -e 's~^imaps_listen~#imaps_listen~' /etc/kopano/gateway.cfg
	sed -i -e 's~^pop3s_listen.*~pop3s_listen = ~' /etc/kopano/gateway.cfg
	sed -i -e 's~^pop3s_listen~#pop3s_listen~' /etc/kopano/gateway.cfg
	sed -i -e 's~^ssl_private_key_file~#ssl_private_key_file~' /etc/kopano/ical.cfg
	sed -i -e 's~^ssl_certificate_file~#ssl_certificate_file~' /etc/kopano/ical.cfg
	sed -i -e 's~^icals_listen.*~icals_listen = ~' /etc/kopano/ical.cfg
	sed -i -e 's~^icals_listen~#icals_listen~' /etc/kopano/ical.cfg
}
default_ssl()
{
	echo "nginx: going back to default self signed SSL to deal with SSL errors"
	echo "$(date "+%Y-%m-%d-%H:%M") going back to default self signed SSL to deal with SSL errors" > /var/log/nginx/error.log
	sed -i -e 's,cert-kopano,cert-snakeoil,g' /etc/kopano/web/kopano-web.conf
}
# for supported version validate license against download portal
k_supported_license()
{
	if echo $EDITION | grep -q "Supported" || [ -e /etc/K_SUPPORTED ]
	then
		if [ ! -e /etc/kopano/license/base ]
		then
			echo "no valid license for kopano supported edition.."
			return 1
		fi
		local K_SNR=`cat /etc/kopano/license/base`
		local URL="https://serial:${K_SNR}@download.kopano.io/supported/core:/"
		if wget -q --no-check-certificate --spider $URL
		then
			echo "base license validated for kopano supported edition.."
			return 0
		else
			echo "no valid license for kopano supported edition.."
			return 1
		fi
	else
		# ok as n/a for community version
		return 0	
	fi
}
# service does not start properly disable it and change config to avoid msgs on hold
disable_amavis()
{
	sed -i -e "s~content_filter =~#content_filter =~" /etc/kopano/postfix/main.cf
	sed -i -e 's~AMAVISD_ENABLED.*~AMAVISD_ENABLED=no~' /etc/kopano/default
	sed -i -e 's~CLAMAVD_ENABLED.*~CLAMAVD_ENABLED=no~' /etc/kopano/default
	M_SERVICES="postfix"
	if grep -q ^POSTGREY_ENABLED=yes /etc/kopano/default ; then M_SERVICES="$M_SERVICES postgrey" ; fi
	if grep -q ^CLAMAVD_ENABLED=yes /etc/kopano/default ; then M_SERVICES="$M_SERVICES clamav-daemon" ; fi
	if grep -q ^FETCHMAIL_ENABLED=yes /etc/kopano/default ; then M_SERVICES="$M_SERVICES fetchmail" ; fi
	if grep -q ^COURIER_IMAP_ENABLED=yes /etc/kopano/default ; then M_SERVICES="$M_SERVICES courier-imap" ; fi
	echo "Failed to start amavis so content filter will be disabled and postfix release all messages.."
	echo "Failed to start amavis so content filter will be disabled. Check amavis.log for details and your mail queue" >>/etc/kopano/alert
	kopano-postfix requeue ALL
}
# service does not start properly disable it and change config to avoid msgs on hold
disable_postgrey()
{
	sed -i -e "s~check_policy_service ~#check_policy_service " /etc/kopano/postfix/main.cf
	sed -i -e 's~POSTGREY_ENABLED.*~POSTGREY_ENABLED=no~' /etc/kopano/default
	M_SERVICES="postfix"
	if grep -q ^CLAMAVD_ENABLED=yes /etc/kopano/default ; then M_SERVICES="$M_SERVICES clamav-daemon" ; fi
	if grep -q ^AMAVISD_ENABLED=yes /etc/kopano/default ; then M_SERVICES="$M_SERVICES amavis" ; fi
	if grep -q ^FETCHMAIL_ENABLED=yes /etc/kopano/default ; then M_SERVICES="$M_SERVICES fetchmail" ; fi
	if grep -q ^COURIER_IMAP_ENABLED=yes /etc/kopano/default ; then M_SERVICES="$M_SERVICES courier-imap" ; fi
	echo "Failed to start postgrey so policy service will be disabled and postfix release all messages.."
	echo "Failed to start postgrey so policy service will be disabled. Check amavis.log for details and your mail queue" >>/etc/kopano/alert
	kopano-postfix requeue ALL
}
init_kopano()
{
	# Init function to set database user, pwd, acl also if argument exists being reset
	# adjust postfix status in init-file for docker as even root does not have acl to read from /proc/$PPID/exe
	sed -i -e 's~dir=$(ls -l /proc/$pid/exe~pgrep -f /usr/lib/postfix -s "$pid" \&\& echo y || true \n\t#dir=$(ls -l /proc/$pid/exe~' /etc/init.d/postfix
	# set default index.html with redirect to webapp
	if [ ! -e /var/www/html/index.html ]
	then
		echo '<html><head><title>Got lost?</title>' > /var/www/html/index.html
		echo '<meta charset="utf-8" name="viewport" content="width=device-width, initial-scale=1">' >> /var/www/html/index.html
		echo '<style>body{text-align:center;vertical-align:middle;font-family:Verdana;font-size: 110%;}</style>' >> /var/www/html/index.html
		echo '<meta http-equiv="refresh" content="1; URL=/webapp/index.php"></head>' >> /var/www/html/index.html
		echo '<body><br><img src="robot.png"><br>If redirect fails goto <a href="/webapp/index.php">Webapp</a>,' >> /var/www/html/index.html
		echo '<a href="/Microsoft-Server-ActiveSync">Microsoft-Server-ActiveSync</a></body></html>' >> /var/www/html/index.html
	fi
	# sync amavis spam-bounce off from kopanos default to default-amavis as amavis bouncce is on initially
	if grep -q ^BOUNCE_SPAM_ENABLED=no /etc/kopano/default
	then 
		sed -i -e "s~\$final_spam_destiny.*~\$final_spam_destiny       = D_PASS;~" /etc/kopano/default-amavis
	fi
	# stopp all services to modify kopano users settings and have congig copied over
	kill_kopano
	if service kopano-monitor status | grep -q "is running" ; then service kopano-monitor stop ; fi
	if service kopano-gateway status | grep -q "is running" ; then service kopano-gateway stop ; fi
	if service kopano-ical status | grep -q "is running" ; then service kopano-ical stop ; fi
	# docker init only: copy over from etc and var during build if mounted dirs are empty a.g. no server.cfg
	if [ -e /etc/kopano2copy ]
	then
		if [ ! -e /etc/kopano/server.cfg ]
		then 
			cp -R /etc/kopano2copy/* /etc/kopano
			# enable pid and log_file in all config files 
			local KCF="backup.cfg gateway.cfg ical.cfg monitor.cfg search.cfg"
			if [ -e /etc/kopano/presence.cfg ] ; then KCF="$KCF presence.cfg" ; fi
			for C in $KCF; do
				sed -i -e "s~#pid_file~pid_file"~ /etc/kopano/$C
				sed -i -e "s~#log_file~log_file"~ /etc/kopano/$C
			done			
			cp -f /etc/kopano/server.cfg /etc/kopano/server.dist
			cp -f /etc/kopano/server.cfg.init /etc/kopano/server.cfg
			cp -f /etc/kopano/spooler.cfg.init /etc/kopano/spooler.cfg
			cp -f /etc/kopano/dagent.cfg.init /etc/kopano/dagent.cfg
			cp -f /etc/kopano/default.init /etc/kopano/default
			if [ -e /etc/kopano/spamd.cfg.init ] ; then cp -f /etc/kopano/spamd.cfg.init /etc/kopano/spamd.cfg ; fi
		fi
		if [ ! -e /etc/kopano/custom/cron.hourly ]
		then
			cp /etc/kopano2copy/custom/cron.* /etc/kopano/custom
			chown root.kopano /etc/kopano/custom/cron.*
			chmod 750 /etc/kopano/custom/cron.*
		fi
		# make a webapp-plugins dist directory then copy over cfgs that do not exist
		if [ -e /etc/kopano/webapp/dist ] ; then rm -R /etc/kopano/webapp/dist ; fi
		mkdir -p /etc/kopano/webapp/dist && cp /etc/kopano2copy/webapp/* /etc/kopano/webapp/dist
		CFGS=`find /etc/kopano2copy/webapp/config* -maxdepth 0 -type f -exec basename "{}" ";"`
		for C in $CFGS; do if [ ! -e /etc/kopano/webapp/$C ] ; then cp /etc/kopano2copy/webapp/$C /etc/kopano/webapp ; fi ; done
		rm -R /etc/kopano2copy
	fi
	if [ -e /etc/z-push2copy ]
	then
		if [ ! -e /etc/z-push/z-push.conf.php ]
		then
			cp -R /etc/z-push2copy/* /etc/z-push
			cp /etc/z-push/z-push.conf.php /etc/z-push/z-push.conf.dist
			cp /etc/z-push/z-push.conf.init /etc/z-push/z-push.conf.php
		fi
		rm -R /etc/z-push2copy
	fi
	if [ -e /var/spool/postfix2copy ]
	then
		if [ ! -e /var/spool/postfix/active ] ; then cp -R /var/spool/postfix2copy/* /var/spool/postfix ; fi
		rm -R /var/spool/postfix2copy
	fi
	if [ -e /var/lib/amavis2copy ]
	then
		if [ ! -e /var/lib/amavis/db ] && [ -e /var/lib/amavis2copy/db ] ; then cp -R /var/lib/amavis2copy/* /var/lib/amavis ; fi
		rm -R /var/lib/amavis2copy
	fi
	# we run clamav and spamassasin integrated into amavis hence same directory with softlink
	if [ -e /var/lib/spamassassin2copy ]
	then
		if [ ! -e /var/lib/amavis/sa-update-keys ] && [ -e /var/lib/spamassassin2copy/sa-update-keys ] ; then cp -R /var/lib/spamassassin2copy/* /var/lib/amavis ; fi
		rm -R /var/lib/spamassassin2copy
	fi
	if [ -e /var/lib/spamassassin ] ; then rm -R /var/lib/spamassassin ; fi
	ln -sf /var/lib/amavis /var/lib/spamassassin
	if [ -e /var/lib/clamav2copy ]
	then
		if [ ! -e /var/lib/amavis/daily.cvd ] && [ -e /var/lib/clamav2copy/daily.cvd ] ; then cp -R /var/lib/clamav2copy/* /var/lib/amavis ; fi
		rm -R /var/lib/clamav2copy
	fi
	if [ -e /var/lib/clamav ] ; then rm -R /var/lib/clamav ; fi
	ln -sf /var/lib/amavis /var/lib/clamav
	if [ -e /var/lib/postgrey2copy ]
	then
		if [ ! -e /var/lib/postgrey/postgrey.db ] && [ -e /var/lib/postgrey2copy/postgrey.db ] ; then cp -R /var/lib/postgrey2copy/* /var/lib/postgrey ; fi
		rm -R /var/lib/postgrey2copy
	fi
	# no more valid since latest versions: ensure the right php version for socket in kopanos nginx cfg file 
	# sed -i -e "s~fastcgi_pass.*~fastcgi_pass unix:/var/run/php/php${PHP_VER}-fpm.sock;~g" /etc/kopano/web/kopano-web.conf
	sed -i -e "s~php${PHP_VER}-fpm.sock~php7.0-fpm.sock~g" /etc/kopano/web/kopano-web.conf
	# tune php-fpm 3x max children knowing the hungry footprint of z-push; create tuning file if non exist
	if [ ! -e /etc/kopano/web/fpm-pool-target ]
	then
		echo "max_children=100" > /etc/kopano/web/fpm-pool-target
		echo "start_servers=25" >> /etc/kopano/web/fpm-pool-target
		echo "min_spare_servers=15" >> /etc/kopano/web/fpm-pool-target
		echo "max_spare_servers=35" >> /etc/kopano/web/fpm-pool-target
	fi
	. /etc/kopano/web/fpm-pool-target
	local MCH=`grep "pm.max_children =" /etc/php/$PHP_VER/fpm/pool.d/www.conf | cut -d'=' -f2- | cut -c 2-`
	sed -i -e "s~pm.max_children = $MCH~pm.max_children = $max_children~" /etc/php/$PHP_VER/fpm/pool.d/www.conf
	local SSV=`grep "pm.start_servers =" /etc/php/$PHP_VER/fpm/pool.d/www.conf | cut -d'=' -f2- | cut -c 2-`
	sed -i -e "s~pm.start_servers = $SSV~pm.start_servers = $start_servers~" /etc/php/$PHP_VER/fpm/pool.d/www.conf
	local MIS=`grep "pm.min_spare_servers =" /etc/php/$PHP_VER/fpm/pool.d/www.conf | cut -d'=' -f2- | cut -c 2-`
	sed -i -e "s~pm.min_spare_servers = $MIS~pm.min_spare_servers = $min_spare_servers~" /etc/php/$PHP_VER/fpm/pool.d/www.conf
	local MAS=`grep "pm.max_spare_servers =" /etc/php/$PHP_VER/fpm/pool.d/www.conf | cut -d'=' -f2- | cut -c 2-`
	sed -i -e "s~pm.max_spare_servers = $MAS~pm.max_spare_servers = $max_spare_servers~" /etc/php/$PHP_VER/fpm/pool.d/www.conf
	sed -i -e "s~;pm.max_requests = 500~pm.max_requests = 250~" /etc/php/$PHP_VER/fpm/pool.d/www.conf
	sed -i -e "s~;request_terminate_timeout = 0~request_terminate_timeout = 120s~" /etc/php/$PHP_VER/fpm/pool.d/www.conf
	sed -i -e "s~;rlimit_files = 1024~rlimit_files = 80000~" /etc/php/$PHP_VER/fpm/pool.d/www.conf
	sed -i -e "s~;catch_workers_output = yes~catch_workers_output = yes~" /etc/php/$PHP_VER/fpm/pool.d/www.conf
	# create logs and give kopano group writes
	touch /var/log/kopano/dagent.log
	touch /var/log/kopano/fetchmail.log
	touch /var/log/kopano/spamd.log
	touch /var/log/kopano/gateway.log
	touch /var/log/kopano/ical.log
	touch /var/log/kopano/nginx.log
	touch /var/log/kopano/presence.log
	touch /var/log/kopano/search.log
	touch /var/log/kopano/server.log
	touch /var/log/kopano/spooler.log
	touch /var/log/kopano/webapp-usr.log
	touch /var/log/kopano/z-push/z-push.log
	touch /var/log/kopano/z-push/z-push-error.log
	touch /var/log/kopano/mail.log
	touch /var/log/kopano/mail.info
	touch /var/log/kopano/mail.warn
	touch /var/log/kopano/mail.err
	touch /var/log/kopano/clamav.log
	touch /var/log/kopano/freshclam.log
	touch /var/log/kopano/razor-agent.log
	touch /var/log/kopano/spamassassin.log
	touch /var/log/kopano/messages
	touch /var/log/kopano/syslog
	touch /var/log/kopano/daemon.log
	touch /var/log/kopano/php-fpm.log
	# postfix: creating lookup tables: virtual alias and bcc
	if [ -e /etc/kopano/postfix/valiases ]
	then
		echo "initializing virtual aliases and pwd e.g. for proxy.. "
		postmap /etc/kopano/postfix/valiases
	fi
	if [ -e /etc/kopano/postfix/sender_access ]
	then
		postmap /etc/kopano/postfix/sender_access
	fi
	if [ -e /etc/kopano/postfix/recipient_access ]
	then
		postmap /etc/kopano/postfix/recipient_access
	fi
	if [ -e /etc/kopano/postfix/sender_bcc ]
	then
		postmap /etc/kopano/postfix/sender_bcc
	fi
	if [ -e /etc/kopano/postfix/recipient_bcc ]
	then
		postmap /etc/kopano/postfix/recipient_bcc
	fi
	# only for non default sender_dependent_authentication aka smarthost
	if [ -e /etc/kopano/postfix/sender_relay ]
	then
		postmap /etc/kopano/postfix/sender_relay
	fi	
	if [ -e /etc/kopano/postfix/sasl_passwd ]
	then
		postmap /etc/kopano/postfix/sasl_passwd
		chmod 600 /etc/kopano/postfix/sasl_passwd
	fi
	# keeping init copy for reset and set softlinks to kopano-etc
	if [ ! -e /etc/kopano/postfix/main.init ]
	then
		cp /etc/kopano/postfix/main.cf /etc/kopano/postfix/main.init
		cp /etc/kopano/postfix/master.cf /etc/kopano/postfix/master.init
	fi
	ln -sf /etc/kopano/postfix/main.cf /etc/postfix/main.cf
	ln -sf /etc/kopano/postfix/master.cf /etc/postfix/master.cf
	echo "modifying kopano user and group ids ($RUN_UID / $RUN_GID) plus file limits .."
	groupmod -g $RUN_GID kopano
	usermod -g $RUN_GID kopano
	usermod -u $RUN_UID kopano
	usermod -u $AMA_UID amavis
	# create file limits at large site for user kopano to run services via sockets
	if ! grep -q kopano /etc/security/limits.conf
	then
		echo "increasing file-limits for user kopano adn www-data running sockets.."
		sed -i -e "s~# End of file~~" /etc/security/limits.conf
		echo "kopano          soft    nofile          60000" >> /etc/security/limits.conf
		echo "kopano          hard    nofile          80000" >> /etc/security/limits.conf
		echo "www-data        soft    nofile          60000" >> /etc/security/limits.conf
		echo "www-data        hard    nofile          80000" >> /etc/security/limits.conf
		echo "# End of file" >> /etc/security/limits.conf
	fi
	# ensure php-fpms php.ini sits on soft links whci could have been overritten by apt init
	if [ ! -h /etc/php/$PHP_VER/fpm/php.ini ] ; then ln -sf /etc/kopano/web/php.ini /etc/php/$PHP_VER/fpm ; fi
	# add kopano settings to php.ini
	if ! grep -q Kopano /etc/kopano/web/php.ini
	then
		# adding kopano setting to php.ini..
		sed -i -e "s~expose_php.*~expose_php = Off\n; Kopano settings\nphp_flag magic_quotes_gpc = off\nphp_flag register_globals = off~" /etc/kopano/web/php.ini
		sed -i -e "s~php_flag register_globals.*~php_flag register_globals = off\nphp_flag magic_quotes_runtime = off\nphp_flag short_open_tag = on\n~" /etc/kopano/web/php.ini
	fi
	# adjust upload_max_filesize and post_max_size from 2M / 8M to size of mail attachments
	local MSG_SIZE=`grep message_size_limit /etc/kopano/postfix/main.cf | cut -d "=" -f2- | cut -d " " -f2-`
	MSG_SIZE=$(expr $MSG_SIZE / 1024 / 1024)
	if [ $MSG_SIZE -gt 2 ] 
	then
		echo "increasing php upload_max_filesize to ${MSG_SIZE}M.."
		sed -i -e "s~upload_max_filesize = 2M~upload_max_filesize = ${MSG_SIZE}M~" /etc/php/$PHP_VER/fpm/php.ini
		MSG_SIZE=$(expr $MSG_SIZE + 1)
		sed -i -e "s~post_max_size = 8M~post_max_size = ${MSG_SIZE}M~" /etc/php/$PHP_VER/fpm/php.ini
	fi
	# amavis adjustments to enable spamassasin and clamav (test via amavisd-new debug-sa)
	sed -i -e "s~\$DO_SYSLOG = 1;~\$logfile = \"/var/log/kopano/amavis.log\";\n\$DO_SYSLOG = 0;~" /etc/kopano/default-amavis
	sed -i -e "s~\$sa_spam_subject_tag =.*~\$sa_spam_subject_tag = '<-SPAM-> ';~" /etc/kopano/default-amavis
	sed -i -e "s~#@bypass_virus_checks_maps~@bypass_virus_checks_maps~" /etc/kopano/content_filter_mode
	sed -i -e "s~#   \\\%bypass_virus_checks~   \\\%bypass_virus_checks~" /etc/kopano/content_filter_mode
	sed -i -e "s~#@bypass_spam_checks_maps~@bypass_spam_checks_maps~" /etc/kopano/content_filter_mode
	sed -i -e "s~#   \\\%bypass_spam_checks~   \\\%bypass_spam_checks~" /etc/kopano/content_filter_mode
	# set logging to webapp users for errors
	sed -i -e "s~define('LOG_USER_LEVEL'.*~define('LOG_USER_LEVEL', LOGLEVEL_ERROR);~" /etc/kopano/webapp/config.php
	sed -i -e "s~define('LOG_FILE_DIR'.*~define('LOG_FILE_DIR', '/var/log/kopano/webapp-usr.log');~" /etc/kopano/webapp/config.php
	# change to non-drop spam mode if set in kopano-default
	if grep -q ^BOUNCE_SPAM_ENABLED=no /etc/kopano/default
	then
		sed -i -e "s~\$final_spam_destiny.*~\$final_spam_destiny       = D_PASS;~" /etc/kopano/default-amavis
	else
		sed -i -e "s~\$final_spam_destiny.*~\$final_spam_destiny       = D_BOUNCE;~" /etc/kopano/default-amavis	
	fi
	local DOM=`grep ^mydomain /etc/postfix/main.cf | cut -d "=" -f2- | cut -d " " -f2-`
	if [ ! -e /etc/mailname ]
	then
		echo $DOM >/etc/kopano/mailname
		ln -sf /etc/kopano/mailname /etc/mailname
	fi
	# add to user-amavis hdrfrom_notify_sender and @local_domains_acl = ( "Domain-1.de", "Domin-2.de" ); 
	if [ -e /etc/kopano/user-amavis ] && ! grep -q hdrfrom_notify_sender /etc/kopano/user-amavis
	then
		sed -i -e "s~use strict;~use strict;\n\$hdrfrom_notify_sender = 'postmaster\\@${DOM}';~" /etc/kopano/user-amavis
	else
		# amavis no longer likes double quotes in $hdrfrom_notify_sender aka replace quotes
		sed -i -e "s~\"~'~g" /etc/kopano/user-amavis
	fi
	if [ -e /etc/kopano/user-amavis ] && ! grep -q local_domains_acl /etc/kopano/user-amavis
	then
		# add " before 1st and after last character and replace , with ","
		#local VDOMS=`cat /etc/kopano/postfix/vdomains | sed -e 's~, ~", "~g' | sed -e 's/^\(.\{0\}\)/\1"/' | sed 's/$/"/'`
		#sed -i -e "s~use strict;~use strict;\n\@local_domains_acl = ( \"${VDOMS}\" );~" /etc/kopano/user-amavis
		sed -i -e "s~use strict;~use strict;\n\@local_domains_acl = ( '${DOM}' );~" /etc/kopano/user-amavis
	fi
	# register and initialize razor and pysor set acl first as amavis uid changed
	chown -R amavis.kopano /var/lib/amavis/
	su - amavis -c 'razor-admin -create'
	su - amavis -c 'razor-admin -register' >/dev/null
	su - amavis -c 'razor-admin -discover'
	# change postgrey default to bind ip4 only (without it fails binding ip6) and set delay 2m only if default
	sed -i -e "s~inet=10023~inet=127.0.0.1:10023~" /etc/kopano/default-postgrey
	if ! grep -q "10023 --delay" /etc/kopano/default-postgrey ; then sed -i -e "s~10023~10023 --delay=120~" /etc/kopano/default-postgrey ; fi
	# change presence bind for all to localhost
	#if [ -e /etc/kopano/presence.cfg ]
	#then
	#	sed -i -e "s~0.0.0.0~127.0.0.1~" /etc/kopano/presence.cfg
	#fi
	# seting extra locales grep from kopano default removing the quotes
	local K_LOCALE=`grep KOPANO_LOCALE /etc/kopano/default | cut -f2 -d'=' | sed 's/^"\(.*\)"$/\1/'`
	if [ -n "$K_LOCALE" ] && [ "$K_LOCALE" != "C" ] 
	then 
		sed -i -e "s~# $K_LOCALE~$K_LOCALE~" /etc/locale.gen
		if [ ! -e /usr/share/locale/locale.alias ] ; then ln -s /etc/locale.alias /usr/share/locale/locale.alias ; fi
		dpkg-reconfigure -f noninteractive locales
	fi
	# setting different timezone to CET
	if [ -n "$TIMEZONE" ] && [ "$TIMEZONE" != "CET" ] && [ -e /usr/share/zoneinfo/"$TIMEZONE" ]
	then
		ln -sf /usr/share/zoneinfo/"$TIMEZONE" /etc/localtime
		dpkg-reconfigure -f noninteractive tzdata
	fi
	echo "setting acl, ssl, fetchmail and plugins.."
	# users created or fetchmail active from previous install do init and expand services for session
	if grep -q ^FETCHMAIL_ENABLED=yes /etc/kopano/default
	then
		/usr/local/bin/kopano-fetchmail.sh init
		killall -q -9 fetchmail
		if [ -e /var/run/fetchmail/fetchmail.pid ] ; then rm /var/run/fetchmail/fetchmail.pid ; fi
	fi
	# now adjustments for webapp plugins like mdm, passwd, fetchmail 
	# fetchmail webapp-plugin settings
	if [ -e /etc/kopano/webapp/plg.conf-fetchmail.php ]
	then
		# set MariaDB port 3307 and Docker host parent IP, user & pwd
		local DB_NAME=`grep ^mysql_database /etc/kopano/server.cfg | cut -f2 -d'=' | grep -o '[^\t ].*'`
		local DB_USER=`grep ^mysql_user /etc/kopano/server.cfg | cut -f2 -d'=' | grep -o '[^\t ].*'`
		local DB_PASS=`grep ^mysql_password /etc/kopano/server.cfg | cut -f2 -d'=' | grep -o '[^\t ].*'`
		local SALT="$(openssl rand -hex 8 | sed 's,/,_,g')"
		sed -i -e "s~3306~3307~g" /etc/kopano/webapp/plg.conf-fetchmail.php
		sed -i -e "s~define('PLUGIN_FETCHMAIL_DATABASE_HOST'.*~define('PLUGIN_FETCHMAIL_DATABASE_HOST', \"${PARENT}\");~" /etc/kopano/webapp/plg.conf-fetchmail.php
		sed -i -e "s~\"kopano\"~\"$DB_NAME\"~" /etc/kopano/webapp/plg.conf-fetchmail.php
		sed -i -e "s~define('PLUGIN_FETCHMAIL_DATABASE_USER'.*~define('PLUGIN_FETCHMAIL_DATABASE_USER', \"${DB_USER}\");~" /etc/kopano/webapp/plg.conf-fetchmail.php
		sed -i -e "s~password~$DB_PASS~" /etc/kopano/webapp/plg.conf-fetchmail.php
		sed -i -e "s~changethis\!~$SALT~" /etc/kopano/webapp/plg.conf-fetchmail.php
	fi
	if [ -e /etc/kopano/webapp/plg.conf-google2fa.php ]
	then
		local DB_NAME=`grep ^mysql_database /etc/kopano/server.cfg | cut -f2 -d'=' | grep -o '[^\t ].*'`
		local DB_USER=`grep ^mysql_user /etc/kopano/server.cfg | cut -f2 -d'=' | grep -o '[^\t ].*'`
		local DB_PASS=`grep ^mysql_password /etc/kopano/server.cfg | cut -f2 -d'=' | grep -o '[^\t ].*'`
		local SALT="$(openssl rand -hex 16 | sed 's,/,_,g')"
		sed -i -e "s~define('PLUGIN_GOOGLE2FA_DATABASE_SERVERNAME'.*~define('PLUGIN_GOOGLE2FA_DATABASE_SERVERNAME', \"${PARENT}:337\");~" /etc/kopano/webapp/plg.conf-google2fa.php
		sed -i -e "s~define('PLUGIN_GOOGLE2FA_DATABASE_DBNAME'.*~define('PLUGIN_GOOGLE2FA_DATABASE_DBNAME', '$DB_NAME');~" /etc/kopano/webapp/plg.conf-google2fa.php
		sed -i -e "s~define('PLUGIN_GOOGLE2FA_DATABASE_USERNAME'.*~define('PLUGIN_GOOGLE2FA_DATABASE_USERNAMEE', '$DB_USER');~" /etc/kopano/webapp/plg.conf-google2fa.php
		sed -i -e "s~define('PLUGIN_GOOGLE2FA_DATABASE_PASSWORD'.*~define('PLUGIN_GOOGLE2FA_DATABASE_PASSWORD', '$DB_PASS');~" /etc/kopano/webapp/plg.conf-google2fa.php
		sed -i -e "s~define('PLUGIN_GOOGLE2FA_MCRYPTKEY'.*~define('PLUGIN_GOOGLE2FA_MCRYPTKEY', '$SALT');~" /etc/kopano/webapp/plg.conf-google2fa.php
	fi
	if [ -e /etc/kopano/webapp/plg.conf-mdm.php ] && ! grep -q 9080 /etc/kopano/webapp/plg.conf-mdm.php
	then
		sed -i -e "s~localhost~localhost:9080~" /etc/kopano/webapp/plg.conf-mdm.php
	fi
	
}
post_build()
{
	echo "$(date "+%Y-%m-%d-%H:%M")" >/etc/kopano/custom/postbuild.log
	# optional packages to the container: courier-imap for mail-archive
	apt-get update -y > /etc/update.list
	if grep -q ^COURIER_IMAP_ENABLED=yes /etc/kopano/default
	then 
		apt-get install -y --no-install-recommends courier-imap >>/etc/kopano/custom/postbuild.log 2>&1
		# configuration for courier-imap to be added here...
		mv /etc/courier /etc/kopano/courier
		ln -sf /etc/kopano/courier /etc/courier
		mkdir -p /var/run/courier
		service start courier-imap
	fi
	# add custom packages	
	if [ -e /etc/kopano/custom/dpkg-add ]
	then
		apt-get install -y --no-install-recommends $(grep -vE "^\s*#" /etc/kopano/custom/dpkg-add | tr "\n" " ") >>/etc/kopano/custom/postbuild.log 2>&1
	fi
	# run custom postbuild script
	if [ -e /etc/kopano/custom/postbuild.sh ]
	then
		chmod 770 /etc/kopano/custom/postbuild.sh
		/etc/kopano/custom/postbuild.sh >>/etc/kopano/custom/postbuild.log 2>&1
	fi
	# run upgrade
	apt-get upgrade --no-install-recommends --allow-unauthenticated --assume-yes >>/etc/kopano/custom/postbuild.log 2>&1
	apt-get clean >>/etc/kopano/custom/postbuild.log 2>&1
}
# check in server-log last 6 lines for advise to run kopano-dbadm k-xyz (e.g. k-1216)
dbadm_repair()
{
	local ADVISE=`tail -4 /var/log/kopano/server.log | grep error | grep -o "kopano-dbadm k-[0-9]*"`
	if [ ! -n "$ADVISE" ] ; then ADVISE=`tail -2 /var/log/kopano/server.log | grep warning | grep -o "kopano-dbadm k-[0-9]*"` ; fi
	if [ ! -n "$ADVISE" ] ; then ADVISE=`tail -2 /var/log/kopano/server.log | grep warning | grep -o "kopano-dbadm [a-z]*"` ; fi
	# run as per advise but do not loop in again while server-cfg entry is running advise cmd
	if [ -n "$ADVISE" ] && ! tail -1 /var/log/kopano/server.log | grep -q running
	then
		echo "running $ADVISE as per advise from server.log usually needed post ZCP upgrade.."
		echo "$(date "+%Y-%m-%d-%H:%M") running $ADVISE as per advise from server.log usually needed post ZCP upgrade.." >> /var/log/kopano/server.log
		$ADVISE
		echo "$(date "+%Y-%m-%d-%H:%M") completed with $ADVISE exiting now" >> /var/log/kopano/server.log
		echo "completed and exiting so you will have to restart k4s"
	fi
}
# end of functions starting processing area
# mount point and license checks with exit on fatal error
if [ ! -e /run/mysqld ]
then
	echo "fatal error: no msql mount point /run/mysqld; run kopano4s-init reset or re-install"	
	exit 1
fi
if [ ! -e /etc/kopano ]
then
	echo "fatal error: no msql mount point /etc/kopano; run kopano4s-init reset or re-install"	
	exit 1
fi
if [ ! -e /etc/kinit.done ]
then
	echo "image intializing UID, GID, etc-cfg, log, ssl, post-build"
	# set init.run flag to avoid overlapping init /  upgrades
	touch /etc/kopano.init
	init_kopano
	install_ssl
	set_acl
	post_build
	if grep -q ^CLAMAVD_ENABLED=yes /etc/kopano/default ; then echo "initializing av database.." && freshclam > /dev/null 2>&1; fi
	# set init.done flag
	if [ -e /etc/kopano.init ] ; then rm /etc/kopano.init ; fi
	echo "$(date "+%Y-%m-%d-%H:%M")" > /etc/kinit.done
	if [ ! -e /run/mysqld/mysqld10.sock ]
	then
		echo "health check error: no msql socket via mount point; mariadb not yet running?"	
	fi
	echo "Active services: $K_SERVICES $M_SERVICES $W_SERVICES"
fi
# start stop status in synology mode
case $1 in
	start)
		if k_srv_on kopano-server && k_srv_on kopano-spooler && k_srv_on kopano-dagent && k_srv_on kopano-search && 
			k_srv_on kopano-monitor && k_srv_on kopano-gateway && k_srv_on kopano-ical &&
			m_srv_on postfix && m_srv_on postgrey && m_srv_on clamav-daemon && m_srv_on amavis && m_srv_on fetchmail && 
			m_srv_on courier-imap &&
			w_srv_on nginx && w_srv_on php${PHP_VER}-fpm && w_srv_on kopano-presence && s_srv_on rsyslog && s_srv_on cron
		then
			echo "Kopano core and web is already running"
			exit 0
		else
			# just in case stop oe kill previous sessions
			if k_srv_on kopano-server
			then
				stop_kopano
				sleep 2
			fi
			kill_kopano
			# test msql socket avaiable and start kopano
			mysql_sock_on && start_kopano
			sleep 1
			# error vs warning: exit 0 at critical services running (postfix optional)
			if k_srv_on kopano-server && k_srv_on kopano-spooler && k_srv_on kopano-dagent &&
			   m_srv_on postfix && w_srv_on nginx && w_srv_on php${PHP_VER}-fpm
			then
				echo "Kopano core and web services are now running"
				exit 0
			else
				echo "Failed to start Kopano critical services call status for details"
				exit 1
			fi
		fi
		;;
	stop)
		if k_srv_on kopano-server
		then
			stop_kopano
			sleep 2
		fi
		kill_kopano
		exit 0
		;;
	restart)
		# avoid docker while loop to exit
		touch /etc/kopano.restart
		if [ -e /etc/kopano.maintenance ] ; then rm /etc/kopano.maintenance ; fi
		if k_srv_on kopano-server
		then
			stop_kopano
			sleep 2
		fi
		kill_kopano
		start_kopano
		exit 0
		;;
	ssl)
		# avoid docker while loop to exit
		touch /etc/kopano.restart
		if k_srv_on kopano-server
		then
			stop_kopano
			sleep 2
		fi
		kill_kopano
		install_ssl
		start_kopano
		exit 0
		;;
	acl)
		set_acl
		exit 0
		;;
	reset)
		echo "Image reset request. Intializing UID, GID, etc-cfg, log, ssl"
		# avoid docker while loop to exit
		touch /etc/kopano.restart
		if k_srv_on kopano-server
		then
			stop_kopano
			sleep 1
		fi
		kill_kopano
		# set init.run flag to avoid overlapping init /  upgrades
		touch /etc/kopano.init
		init_kopano
		install_ssl
		set_acl
		post_build
		if [ -e /etc/kopano.maintenance ] ; then rm /etc/kopano.maintenance ; fi
		if grep -q ^CLAMAVD_ENABLED=yes /etc/kopano/default ; then echo "initializing av database.." && freshclam > /dev/null 2>&1; fi
		# set init.done flag
		if [ -e /etc/kopano.init ] ; then rm /etc/kopano.init ; fi
		echo "$(date "+%Y-%m-%d-%H:%M")" > /etc/kinit.done
		start_kopano
		exit 0
		;;
	status)
		if [ -e /etc/kopano.init ]
		then
			echo "Init still running revisit for service run status later.."
			exit 0
		fi
		if [ -e /etc/kopano.restart ]
		then
			echo "Restarting revisit for service run status later.."
			exit 0
		fi
		if [ -e /etc/kopano.maintenance ]
		then
			echo "Maintenance mode no services will be running but container will stay alive.."
			exit 0
		fi
		if k_srv_on kopano-server && k_srv_on kopano-spooler && k_srv_on kopano-dagent && k_srv_on kopano-search && 
			k_srv_on kopano-monitor && k_srv_on kopano-gateway && k_srv_on kopano-ical &&
			m_srv_on postfix && m_srv_on postgrey && m_srv_on clamav-daemon && m_srv_on amavis && m_srv_on kopano-spamd &&
			m_srv_on fetchmail && m_srv_on courier-imap &&
			w_srv_on nginx && w_srv_on php${PHP_VER}-fpm && w_srv_on kopano-presence && s_srv_on rsyslog && s_srv_on cron
		then
			echo "Running: $K_SERVICES"
			echo "Running: $W_SERVICES"
			echo "Running: $M_SERVICES"
			echo "Running: $S_SERVICES"
			if grep -q ^CLAMAVD_ENABLED=yes /etc/kopano/default && [ -e "$CLAMPLD" ]
			then
				echo "clamav-daemon loading in background (1-5m) restarting dependent service amavis once done.."
			fi
			exit 0
		else
			RET="Core:"
			if k_srv_on kopano-server
			then
				RET="$RET Kopano Server Running"
			else
				RET="$RET Kopano Server Not Running"
			fi
			if k_srv_on kopano-spooler
			then
				RET="$RET, Spooler Running"
			else
				RET="$RET, Spooler Not Running"
			fi
			if k_srv_on kopano-dagent
			then
				RET="$RET, Dagent Running"
			else
				RET="$RET, Dagent Not Running"
			fi
			if k_srv_on kopano-search
			then
				if echo $K_SERVICES | grep -q "kopano-search"
				then
					RET="$RET, Search Running"
				else
					RET="$RET, Search Disabled"
				fi
			else
				RET="$RET, Search Not Running"
			fi
			if k_srv_on kopano-monitor
			then
				if echo $K_SERVICES | grep -q "kopano-monitor"
				then
					RET="$RET, Monitor Running"
				else
					RET="$RET, Monitor Disabled"
				fi
			else
				RET="$RET, Monitor Not Running"
			fi
			if k_srv_on kopano-gateway
			then
				if echo $K_SERVICES | grep -q "kopano-gateway"
				then
					RET="$RET, Gateway Running"
				else
					RET="$RET, Gateway Disabled"
				fi
			else
				RET="$RET, Gateway Not Running"
			fi
			if k_srv_on kopano-ical
			then
				if echo $K_SERVICES | grep -q "kopano-ical"
				then			
					RET="$RET, ICAL Running"
				else
					RET="$RET, ICAL Disabled"
				fi
			else
				RET="$RET, ICAL Not Running"
			fi
			echo $RET
			RET="Web:"
			if w_srv_on nginx
			then
				RET="$RET NGINX Running"
			else
				RET="$RET NGINX Not Running"
			fi
			if w_srv_on php${PHP_VER}-fpm
			then
				RET="$RET, PHP${PHP_VER}-FPM Running"
			else
				RET="$RET, PHP${PHP_VER}-FPM Not Running"
			fi
			if w_srv_on kopano-presence
			then
				if echo $W_SERVICES | grep -q "kopano-presence"
				then
					RET="$RET, Presence Running"
				else
					RET="$RET, Presence Disabled"
				fi
			else
				RET="$RET, Presence Not Running"
			fi
			echo $RET
			RET="Mail:"
			if m_srv_on postfix
			then
				RET="$RET Postfix Running"
			else
				RET="$RET Postfix Not Running"
			fi
			if m_srv_on postgrey
			then
				if echo $M_SERVICES | grep -q "postgrey"
				then
					RET="$RET, Postgrey Running"
				else
					RET="$RET, Postgrey Disabled"
				fi
			else
				RET="$RET, Postgrey Not Running"
			fi
			if m_srv_on clamav-daemon
			then
				if echo $M_SERVICES | grep -q "clamav-daemon"
				then
					RET="$RET, Clamav Running"
				else
					RET="$RET, Clamav Disabled"
				fi
			else
				RET="$RET, Clamav Not Running"
			fi
			if m_srv_on amavis
			then
				if echo $M_SERVICES | grep -q "amavis"
				then
					RET="$RET, Amavis Running"
				else
					RET="$RET, Amavis Disabled"
				fi
			else
				RET="$RET, Amavis Not Running"
			fi
			if m_srv_on kopano-spamd
			then
				if echo $M_SERVICES | grep -q "kopano-spamd"
				then
					RET="$RET, Spamd Running"
				else
					RET="$RET, Spamd Disabled"
				fi
			else
				RET="$RET, Spamd Not Running"
			fi
			if m_srv_on fetchmail
			then
				if echo $M_SERVICES | grep -q "fetchmail"
				then
					RET="$RET, Fetchmail Running"
				else
					RET="$RET, Fetchmail Disabled"
				fi
			else
				RUNNING=$(ps -ef | grep -v grep | grep -c fetchmail)
				if [ $RUNNING -gt 1 ]
				then
					RET="$RET, multiple Fetchmails Running"
				else
					RET="$RET, Fetchmail Not Running"
				fi
			fi
			if m_srv_on courier-imap
			then
				if echo $M_SERVICES | grep -q "courier-imap"
				then
					RET="$RET, Courier-Imap Running"
				else
					RET="$RET, Courier-Imap Disabled"
				fi
			else
				RET="$RET, Courier-Imap Not Running"
			fi
			echo $RET
			RET="Sys:"
			if s_srv_on rsyslog
			then
				RET="$RET Syslog Running"
			else
				RET="$RET Syslog Not Running"
			fi
			if s_srv_on cron
			then
				RET="$RET, Cron Running"
			else
				RET="$RET, Cron Not Running"
			fi
			echo $RET
			# error vs warning: exit 0 at critical services running
			if k_srv_on kopano-server && k_srv_on kopano-spooler && k_srv_on kopano-dagent &&
			   m_srv_on postfix && w_srv_on nginx && w_srv_on php${PHP_VER}-fpm
			then
				exit 0
			else
				exit 1
			fi
		fi
		;;
	upgrade)
		echo "running system update and upgrade for latest versions..."
		apt-get update && apt-get upgrade -y --allow-unauthenticated --assume-yes > /etc/update.list
		echo "done"
		;;
	maintain-on)
		echo "switching on maintenance mode: services can be stopped and container remains running.."
		touch /etc/kopano.maintenance
		;;
	maintain-off)
		if [ -e /etc/kopano.maintenance ]
		then
			echo "switching off maintenance mode to standard mode; restart pls.."
			rm /etc/kopano.maintenance
		fi
		;;
	alive)
		if ! k_supported_license
		then 
			echo "fatal error: could no validate /etc/kopano/license/base for kopano supported edition"	
			exit 1
		fi
		# set dockerhost as parent ip in hosts to make logging more readable for postfix etc.
		if ! grep -q dockerhost /etc/hosts ; then echo "${PARENT}  dockerhost" >> /etc/hosts ; fi
		# clean up old pid.files
		if ls /var/run/kopano/*.pid 1> /dev/null 2>&1; then rm /var/run/kopano/*.pid ; fi
		# dummy maintenance mode if flag is set
		if [ -e /etc/kopano.maintenance ] ; then tail -f /dev/null ; exit 0 ; fi
		# continue standard mode
		mysql_sock_on && start_kopano
		# adjust php-fmp socket according to version in case running socket differs from config kopano-web.conf
		if ! grep -q "php${PHP_VER}-fpm" /etc/kopano/web/kopano-web.conf && [ -e "/var/run/php/php${PHP_VER}-fpm.sock" ]
		then
			sed -i -e "s~/var/run/php/php7.*~/var/run/php/php${PHP_VER}-fpm.sock;~g" /etc/kopano/web/kopano-web.conf
			service nginx restart
		fi
		# reset ssl config back to self signed default for nginx and disabled for kopano in case of errors
		if ! w_srv_on nginx && tail -3 /var/log/nginx/error.log | grep -q ssl ; then default_ssl && service nginx start ; fi
		if ! k_srv_on kopano-server && tail -3 /var/log/kopano/server.log | grep -q ssl ; then disable_ssl && service kopano-server start ; fi
		echo "staying alive while kopano service is running.."
		HEALTH_C_TIMER=0
		while k_srv_on kopano-server
		do
			sleep 10
			# run kopano-dbadm for warnings if advised in server.log
			if tail -2 /var/log/kopano/server.log | grep warning | grep -q kopano-dbadm ; then dbadm_repair ; fi
			# restart amavis once clamd has loaded aka clamd-load and clamd.ctl exist
			if grep -q ^CLAMAVD_ENABLED=yes /etc/kopano/default && [ -e "$CLAMPLD" ] && [ -e "$CLAMCTL" ]
			then
				rm "$CLAMPLD"
				echo "clamav-daemon loaded, now restarting dependent daemon amavis.."
				echo "$(date "+%Y.%m.%d-%H:%M:%S") clamav loaded, restarting amavis.." >>/var/log/clamd-bgload.log
				service amavis restart
			fi
			HEALTH_C_TIMER=$(expr $HEALTH_C_TIMER + 10)
			# health check each 3 mins for critical services inlc. daily refresh aof clamav database
			if [ $HEALTH_C_TIMER -gt 180 ]
			then
				HEALTH_C_TIMER=0
				TS=$(date "+%Y.%m.%d")
				if grep -q ^CLAMAVD_ENABLED=yes /etc/kopano/default && [ ! -e "/var/run/clamav/freshclam.${TS}" ]
				then
					echo "daily refresh of clam-av database this may take some time (1-3m).."
					if ls /var/run/clamav/freshclam.* >/dev/null 2>&1; then rm /var/run/clamav/freshclam.* ; fi
					touch "/var/run/clamav/freshclam.${TS}"
					freshclam > /dev/null 2>&1
					echo "done with refreshing clamd antivirus database"
				fi
				if ! k_srv_on kopano-spooler ; then service kopano-spooler start ; fi
				if ! k_srv_on kopano-dagent ; then service kopano-dagent start ; fi
				if ! s_srv_on rsyslog ; then service rsyslog start ; fi
				if ! s_srv_on cron ; then service cron start ; fi
				if ! m_srv_on postfix ; then service postfix start ; fi
				if ! w_srv_on nginx ; then service nginx start ; fi
				if ! w_srv_on php${PHP_VER}-fpm ; then service php${PHP_VER}-fpm start ; fi
				if ! m_srv_on clamav-daemon ; then service clamav-daemon start ; fi
				# ensure only 1 fetchmail is running as service start script is not stable on stop or restart
				if grep -q ^FETCHMAIL_ENABLED=yes /etc/kopano/default
				then
					RUNNING=$(ps -ef | grep -v grep | grep -c fetchmail)
					if [ $RUNNING -gt 1 ]
					then
						echo "multiple fetchmail services found restarting 1 only.."
						killall -q -9 fetchmail
						if [ -e /var/run/fetchmail/fetchmail.pid ] ; then rm -f /var/run/fetchmail/fetchmail.pid ; fi
					fi
					if [ $RUNNING -gt 1 ] || [ $RUNNING -eq 0 ] 
					then
						service fetchmail start					
					fi
				fi
				# restart or disable amavis and postgrey
				if ! m_srv_on amavis
				then
					service amavis start
					sleep 2
					if ! m_srv_on amavis ; then disable_amavis ; fi
				fi
				if ! m_srv_on amavis postgrey
				then
					service postgrey start
					sleep 2
					if ! m_srv_on postgrey ; then disable_postgrey ; fi
				fi
			fi
		done
		echo "exiting as server stopped; if non-grace shutdown see last entry from /var/log/kopano/server.log and consider kopano4s-init reset or re-install"
		tail -4 /var/log/kopano/server.log
		# run kopano-dbadm for errors e.g. k-1216 if indicated in server-log entries to enable clean upgrade from ZCP
		dbadm_repair
		# sleep 15sec as start stop will wait 15 secs for grace shutdown services but container still running
		sleep 15
		;;
	*)
	echo "Valid parameters: start, stop, restart, reset, upgrade, ssl, acl, status, alive (up when core service running), maintain-on/off"
	exit 1
	;;
esac
