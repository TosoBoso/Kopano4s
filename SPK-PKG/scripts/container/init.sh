#!/bin/sh
# (c) 2018 vbettag initialisation for Kopano4Syno in Docker container
# kopano-monitor, gateway, ical disabled by default and added if found in etc-default
if [ ! -e /etc/kopano/default ] && [ -e /etc/kopano/default.init ] ; then cp /etc/kopano/default.init /etc/kopano/default ; fi
K_SERVICES="kopano-server kopano-spooler kopano-dagent"
if grep -q ^SEARCH_ENABLED=yes /etc/kopano/default ; then K_SERVICES="$K_SERVICES kopano-search" ; fi
if grep -q ^MONITOR_ENABLED=yes /etc/kopano/default ; then K_SERVICES="$K_SERVICES kopano-monitor" ; fi
if grep -q ^GATEWAY_ENABLED=yes /etc/kopano/default ; then K_SERVICES="$K_SERVICES kopano-gateway" ; fi
if grep -q ^ICAL_ENABLED=yes /etc/kopano/default ; then K_SERVICES="$K_SERVICES kopano-ical" ; fi
W_SERVICES="nginx php${PHP_VER}-fpm"
if grep -q ^PRESENCE_ENABLED=yes /etc/kopano/default ; then W_SERVICES="$W_SERVICES kopano-presence" ; fi
if grep -q ^WEBMEETINGS_ENABLED=yes /etc/kopano/default ; then W_SERVICES="$W_SERVICES kopano-webmeetings" ; fi
if grep -q ^COTURN_ENABLED=yes /etc/kopano/default ; then W_SERVICES="$W_SERVICES coturn" ; fi
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
WEBMPID="/var/run/kopano-webmeetings.pid"
AMAVPID="/var/run/amavis/amavis.pid"
CLAMPID="/var/run/clamav/clamav.pid"
PFIXPID="/var/spool/postfix/pid/master.pid"
PGRYPID="/var/run/postgrey.pid"
FEMLPID="/var/run/fetchmail/fetchmail.pid"
PHPFPMPID="/var/run/php/php${PHP_VER}-fpm.pid"
SYSLPID="/var/run/rsyslogd.pid"
NGINXPID="/var/run/nginx.pid"
IMAPDPID="/var/run/courier/imapd.pid"

mysql_sock_on()
{
	# loop some time waiting fo mysql socket
	if [ ! -e  /run/mysqld/mysqld10.sock ] 
	then
		echo "waiting for mysql socket being available at /run/mysqld/mysqld10.sock..." 
	fi
	for i in 0 1 2 3 4 5 6 7 8 9
	do
		if [ -e /run/mysqld/mysqld10.sock ]
		then
			return 0
		fi
		sleep 10
	done
	echo "giving up no MySQL found; restart package or run kopano-init reset to address mount issues"
	touch /etc/kopano/mount.issue
	return 1
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
# status for all kopano web daemons defined in W_SERVICES
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
		service $S start
	done
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
	rm -f /var/run/kopano/*.pid
	rm -f /var/run/fetchmail/fetchmail.pid
}
set_secrets()
{
	local PRESENCE_SHARED_SECRET
	local WEBMEETINGS_SHARED_SECRET
	local WEBMEETINGS_SESSION_SECRET
	local WEBMEETINGS_ENCRYPTION_SECRET
	# only once: replace secrets in presence.cfg, config-spreedwebrtc.php, webmeetings.cfg
	if [ ! -e /etc/kopano/ssl/PRESENCE_SHARED_SECRET ]
	then
		# no vim pkg so no `xxd -ps -l 32 -c 32 /dev/random`
		PRESENCE_SHARED_SECRET="$(openssl rand -hex 32 | sed 's,/,_,g')"
		echo $PRESENCE_SHARED_SECRET > /etc/kopano/ssl/PRESENCE_SHARED_SECRET
	else
		PRESENCE_SHARED_SECRET=`cat /etc/kopano/ssl/PRESENCE_SHARED_SECRET`
	fi
	if [ ! -e /etc/kopano/ssl/WEBMEETINGS_SHARED_SECRET ]
	then
		WEBMEETINGS_SHARED_SECRET="$(openssl rand -hex 32 | sed 's,/,_,g')"
		echo $WEBMEETINGS_SHARED_SECRET > /etc/kopano/ssl/WEBMEETINGS_SHARED_SECRET
	else
		WEBMEETINGS_SHARED_SECRET=`cat /etc/kopano/ssl/WEBMEETINGS_SHARED_SECRET`
	fi
	if [ ! -e /etc/kopano/ssl/WEBMEETINGS_SESSION_SECRET ]
	then
		WEBMEETINGS_SESSION_SECRET="$(openssl rand -hex 32 | sed 's,/,_,g')"
		echo $WEBMEETINGS_SESSION_SECRET > /etc/kopano/ssl/WEBMEETINGS_SESSION_SECRET
	else
		WEBMEETINGS_SESSION_SECRET=`cat /etc/kopano/ssl/WEBMEETINGS_SESSION_SECRET`
	fi
	if [ ! -e /etc/kopano/ssl/WEBMEETINGS_ENCRYPTION_SECRET ]
	then
		WEBMEETINGS_ENCRYPTION_SECRET="$(openssl rand -hex 32 | sed 's,/,_,g')"
		echo $WEBMEETINGS_ENCRYPTION_SECRET > /etc/kopano/ssl/WEBMEETINGS_ENCRYPTION_SECRET
	else
		WEBMEETINGS_ENCRYPTION_SECRET=`cat /etc/kopano/ssl/WEBMEETINGS_ENCRYPTION_SECRET`
	fi
	if [ -e /etc/kopano/presence.cfg ]
	then
		sed -i -e "s~^#server_secret_key =~server_secret_key ="~ /etc/kopano/presence.cfg
		sed -i -e "s~server_secret_key =.*~server_secret_key = $PRESENCE_SHARED_SECRET"~ /etc/kopano/presence.cfg
		sed -i -e "s~#data_path.*~data_path = /var/lib/kopano/backup/presence/~" /etc/kopano/presence.cfg
		mkdir -p /var/lib/kopano/backup/presence
	fi
	if [ -e /etc/kopano/webmeetings.cfg ]
	then
		sed -i -e "s~sharedsecret_secret =.*~sharedsecret_secret = $WEBMEETINGS_SHARED_SECRET"~ /etc/kopano/webmeetings.cfg
		sed -i -e "s~sessionSecret =.*~sessionSecret = $WEBMEETINGS_SESSION_SECRET"~ /etc/kopano/webmeetings.cfg
		sed -i -e "s~encryptionSecret =.*~encryptionSecret = $WEBMEETINGS_ENCRYPTION_SECRET"~ /etc/kopano/webmeetings.cfg	
		sed -i -e "s~/webapp/~/~g"  /etc/kopano/webmeetings.cfg
	fi
	if [ -e /etc/kopano/webapp/config-spreedwebrtc.php ]
	then
		sed -i -e "s~/webapp/~/~g" /etc/kopano/webapp/config-spreedwebrtc.php
		sed -i -e "s~DEFINE('PLUGIN_SPREEDWEBRTC_PRESENCE_SHARED_SECRET',.*~DEFINE('PLUGIN_SPREEDWEBRTC_PRESENCE_SHARED_SECRET', '${PRESENCE_SHARED_SECRET}');"~ /etc/kopano/webapp/config-spreedwebrtc.php
		sed -i -e "s~DEFINE('PLUGIN_SPREEDWEBRTC_WEBMEETINGS_SHARED_SECRET',.*~DEFINE('PLUGIN_SPREEDWEBRTC_WEBMEETINGS_SHARED_SECRET', '${WEBMEETINGS_SHARED_SECRET}');"~ /etc/kopano/webapp/config-spreedwebrtc.php
		sed -i -e "s~DEFINE('PLUGIN_SPREEDWEBRTC_TURN_AUTHENTICATION_URL',.*~DEFINE('PLUGIN_SPREEDWEBRTC_TURN_AUTHENTICATION_URL', '');"~ /etc/kopano/webapp/config-spreedwebrtc.php
		sed -i -e "s~DEFINE('PLUGIN_SPREEDWEBRTC_TURN_USE_KOPANO_SERVICE',.*~DEFINE('PLUGIN_SPREEDWEBRTC_TURN_USE_KOPANO_SERVICE', false);"~ /etc/kopano/webapp/config-spreedwebrtc.php
		if grep -q ^WEBMEETINGS_ENABLED=yes /etc/kopano/default
		then
			sed -i -e "s~DEFINE('PLUGIN_SPREEDWEBRTC_USER_DEFAULT_ENABLE',.*~DEFINE('PLUGIN_SPREEDWEBRTC_USER_DEFAULT_ENABLE', true);"~ /etc/kopano/webapp/config-spreedwebrtc.php
			sed -i -e "s~DEFINE('PLUGIN_SPREEDWEBRTC_AUTO_START',.*~DEFINE('PLUGIN_SPREEDWEBRTC_AUTO_START', true);"~ /etc/kopano/webapp/config-spreedwebrtc.php
		else
			sed -i -e "s~DEFINE('PLUGIN_SPREEDWEBRTC_USER_DEFAULT_ENABLE',.*~DEFINE('PLUGIN_SPREEDWEBRTC_USER_DEFAULT_ENABLE', false);"~ /etc/kopano/webapp/config-spreedwebrtc.php
			sed -i -e "s~DEFINE('PLUGIN_SPREEDWEBRTC_AUTO_START',.*~DEFINE('PLUGIN_SPREEDWEBRTC_AUTO_START', false);"~ /etc/kopano/webapp/config-spreedwebrtc.php		
		fi
		sed -i -e "s~DEFINE('PLUGIN_SPREEDWEBRTC_REQUIRE_AUTHENTICATION',.*~DEFINE('PLUGIN_SPREEDWEBRTC_REQUIRE_AUTHENTICATION', true);"~ /etc/kopano/webapp/config-spreedwebrtc.php
		sed -i -e "s~DEFINE('PLUGIN_SPREEDWEBRTC_DEBUG',.*~DEFINE('PLUGIN_SPREEDWEBRTC_DEBUG', false);"~ /etc/kopano/webapp/config-spreedwebrtc.php
	fi
}
set_acl()
{
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

	chown -R root.www-data /etc/z-push
	chmod 751 /etc/z-push
	chmod 640 /etc/z-push/*
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
	# remove recursive softlink in etc-kopano
	if [ -h /etc/kopano/kopano ] ; then rm /etc/kopano/kopano ; fi

	# other than etc-kopano: /var/www/html /usr/share-web, /var-log
	chown -R root.www-data /var/www/html && chmod 750 /var/www/html && chmod 640 /var/www/html/*.html
	chown -R root.www-data /usr/share/kopano-webapp
	chown -R root.www-data /usr/share/z-push
	chown -R kopano.kopano /var/log/kopano
	chown amavis.kopano /var/log/kopano/amavis.log
	chown www-data.kopano /var/log/kopano/webapp-usr.log
	chown -R www-data.kopano /var/log/kopano/z-push/
	find /usr/share/kopano-webapp -type f -exec chmod 640 "{}" ";"
	find /usr/share/kopano-webapp -type d -exec chmod 750 "{}" ";"
	find /usr/share/z-push -type f -exec chmod 640 "{}" ";"
	find /usr/share/z-push -type d -exec chmod 750 "{}" ";"
	chmod 750 /usr/share/z-push/backend/kopano/listfolders.php
	chmod 750 /usr/share/z-push/z-push-admin.php
	chmod 771 /var/log/kopano
	chmod 660 /var/log/kopano/*.log
	chmod 770 /var/log/kopano/z-push/
	chmod 660 /var/log/kopano/z-push/*.log
	chmod 660 /var/log/kopano/amavis.log
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
	if [ -e /etc/kopano/ssl/svrcertbundle.pem ] && [ -e /etc/kopano/ssl/server.key ]
	then
		ln -sf /etc/kopano/ssl/svrcertbundle.pem /etc/ssl/certs/ssl-cert-kopano.pem
		ln -sf /etc/kopano/ssl/server.key /etc/ssl/private/ssl-cert-kopano.key
		sed -i -e 's~cert-snakeoil~cert-kopano~g' /etc/kopano/web/kopano-web.conf
		cat /etc/kopano/ssl/server.key /etc/kopano/ssl/svrcertbundle.pem > /etc/kopano/ssl/server.pem
		sed -i -e 's~replace-with-server-cert-password~~' /etc/kopano/server.cfg
		sed -i -e 's~/etc/kopano/ssl/cacert.pem~~' /etc/kopano/server.cfg
		mkdir -p /etc/kopano/ical
		ln -sf /etc/kopano/ssl/server.key /etc/kopano/ical/privkey.pem
		ln -sf /etc/kopano/ssl/svrcertbundle.pem /etc/kopano/ical/cert.pem
		mkdir -p /etc/kopano/gateway
		ln -sf /etc/kopano/ssl/server.key /etc/kopano/gateway/privkey.pem
		ln -sf /etc/kopano/ssl/svrcertbundle.pem /etc/kopano/gateway/cert.pem
	fi
}
default_ssl()
{
	echo "going back to default self signed SSL to deal with to SSL errors"
	echo "" > /var/log/nginx/error.log
	sed -i -e 's,cert-kopano,cert-snakeoil,g' /etc/kopano/web/kopano-web.conf
}
# for supported version validate license against download portal
k_supported_license()
{
	if echo $EDITION | grep -q "Migration"
	then
		# set counter so it stops past 6 hours aka 3 min x 120
		MIG_TIMER=120
	fi
	if echo $EDITION | grep -q "Supported" || [ -e /etc/K_SUPPORTED ]
	then
		if [ ! -e /etc/kopano/license/base ]
		then
			return 1
		fi
		local K_SNR=`cat /etc/kopano/license/base`
		local URL="https://serial:${K_SNR}@download.kopano.io/supported/core:/"
		if wget -q --no-check-certificate --spider $URL
		then
			echo "base license validated for kopano supported edition.."
			return 0
		else
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
	# Init function to set database user, pwd, acl, secrets also if argument exists being reset
	# adjust postfix status in init-file for docker as even root does not have acl to read from /proc/$PPID/exe
	sed -i -e 's~dir=$(ls -l /proc/$pid/exe~pgrep -f /usr/lib/postfix -s "$pid" \&\& echo y || true \n\t#dir=$(ls -l /proc/$pid/exe~' /etc/init.d/postfix
	# set default index.html with redirect to webapp
	if [ ! -e /var/www/html/index.html ]
	then
		echo '<html><head><title>Got lost?</title>' > /var/www/html/index.html
		echo '<meta charset="utf-8" name="viewport" content="width=device-width, initial-scale=1">' >> /var/www/html/index.html
		echo '<style>body{text-align:center;vertical-align:middle;font-family:Verdana;font-size: 110%;}</style></head>' >> /var/www/html/index.html
		echo '<body><br>Got lost ? Goto <a href="/webapp/index.php">Webapp</a> <a href="/Microsoft-Server-ActiveSync">Microsoft-Server-ActiveSync</a>' >> /var/www/html/index.html
		echo '<br><br><img src="robot.png"></body></html>' >> /var/www/html/index.html
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
	# ensure the right php version for socket in kopanos nginx cfg file 
	sed -i -e "s~fastcgi_pass.*~fastcgi_pass unix:/var/run/php/php${PHP_VER}-fpm.sock;~g" /etc/kopano/web/kopano-web.conf
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
	sed -i -e "s~;rlimit_files = 1024~rlimit_files = 131072~" /etc/php/$PHP_VER/fpm/pool.d/www.conf
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
	touch /var/log/kopano/webmeetings.log
	touch /var/log/kopano/webapp-usr.log
	touch /var/log/kopano/z-push/z-push.log
	touch /var/log/kopano/z-push/z-push-error.log
	touch /var/log/kopano/mail.log
	touch /var/log/kopano/mail.info
	touch /var/log/kopano/mail.warn
	touch /var/log/kopano/mail.err
	touch /var/log/kopano/amavis.log
	touch /var/log/kopano/clamav.log
	touch /var/log/kopano/freshclam.log
	touch /var/log/kopano/spamassassin.log
	touch /var/log/kopano/messages
	touch /var/log/kopano/syslog
	touch /var/log/kopano/daemon.log
	touch /var/log/kopano/php${PHP_VER}-fpm.log
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
	# create file limits at large site for user kopano to run services via  sockets
	if ! grep -q kopano /etc/security/limits.conf
	then
		echo "increasing file-limits for user kopano running sockets.."
		sed -i -e "s~# End of file~~" /etc/security/limits.conf
		echo "kopano          soft    nofile          60000" >> /etc/security/limits.conf
		echo "kopano          soft    nofile          80000" >> /etc/security/limits.conf
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
	#not anymore since payzor 1.0 su - amavis -c 'pyzor discover'
	# webmmetings and presence adjustments
	if [ -e /usr/share/kopano-webmeetings ]
	then 
		chown -R root.kopano /usr/share/kopano-webmeetings
		usermod -d /usr/share/kopano-webmeetings kopano
	fi
	# change presence bind for all to localhost
	if [ -e /etc/kopano/presence.cfg ]
	then
		sed -i -e "s~0.0.0.0~127.0.0.1~" /etc/kopano/presence.cfg
	fi
	# seting extra locales grep from kopano default removing the quotes
	local K_LOCALE=`grep KOPANO_LOCALE /etc/kopano/default | cut -f2 -d'=' | sed 's/^"\(.*\)"$/\1/'`
	if [ -n "$K_LOCALE" ] && [ "$K_LOCALE" != "C" ] 
	then 
		sed -i -e "s~# $K_LOCALE~$K_LOCALE~" /etc/locale.gen
		if [ ! -e /usr/share/locale/locale.alias ] ; then ln -s /etc/locale.alias /usr/share/locale/locale.alias ; fi
		dpkg-reconfigure  -f noninteractive locales
	fi
	echo "setting acl, ssl, encryption shared secrets, fetchmail and plugins.."
	# change run group for webmeetings for acls with synology
	if [ -e /etc/kopano/default-webmeetings ]
	then
		sed -i -e "s~www-data~kopano~" /etc/kopano/default-webmeetings
		sed -i -e "s~'/var/run'~'/var/run/kopano'~" /etc/kopano/default-webmeetings
		sed -i -e "s~kopano-webmeetings.pid~webmeetings.pid~" /etc/kopano/default-webmeetings
	fi
	# users created or fetchmail active from previous install do init and expand services for session
	if ! grep -q "place your configuration here" /etc/kopano/fetchmailrc
	then
		if grep -q ^FETCHMAIL_ENABLED=no /etc/kopano/default
		then
			M_SERVICES="$M_SERVICES fetchmail"
		fi
		/usr/local/bin/kopano-fetchmail.sh init
	fi
	# now adjustments for webapp plugins like mdm, passwd, fetchmail 
	# fetchmail webapp-plugin settings
	if [ -e /etc/kopano/webapp/config-fetchmail.php ]
	then
		# set MariaDB port 3307 and Docker host parent IP, user & pwd
		local DB_NAME=`grep ^mysql_database /etc/kopano/server.cfg | cut -f2 -d'=' | grep -o '[^\t ].*'`
		local DB_USER=`grep ^mysql_user /etc/kopano/server.cfg | cut -f2 -d'=' | grep -o '[^\t ].*'`
		local DB_PASS=`grep ^mysql_password /etc/kopano/server.cfg | cut -f2 -d'=' | grep -o '[^\t ].*'`
		local SALT="$(openssl rand -hex 8 | sed 's,/,_,g')"
		sed -i -e "s~3306~3307~g" /etc/kopano/webapp/config-fetchmail.php
		sed -i -e "s~define('PLUGIN_FETCHMAIL_DATABASE_HOST'.*~define('PLUGIN_FETCHMAIL_DATABASE_HOST', \"${PARENT}\");~" /etc/kopano/webapp/config-fetchmail.php
		sed -i -e "s~\"kopano\"~\"$DB_NAME\"~" /etc/kopano/webapp/config-fetchmail.php
		sed -i -e "s~define('PLUGIN_FETCHMAIL_DATABASE_USER'.*~define('PLUGIN_FETCHMAIL_DATABASE_USER', \"${DB_USER}\");~" /etc/kopano/webapp/config-fetchmail.php
		sed -i -e "s~password~$DB_PASS~" /etc/kopano/webapp/config-fetchmail.php
		sed -i -e "s~changethis\!~$SALT~" /etc/kopano/webapp/config-fetchmail.php
	fi
	if [ -e /etc/kopano/webapp/config-mdm.php ] && ! grep -q 9080 /etc/kopano/webapp/config-mdm.php
	then
		sed -i -e "s~localhost~localhost:9080~" /etc/kopano/webapp/config-mdm.php
	fi
	
}
post_build()
{
	echo "$(date "+%Y-%m-%d-%H:%M")" >/etc/kopano/custom/postbuild.log
	# optional packages to the container: courier-imap for mail-archive, coturn for webmeetings proxy
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
	if grep -q ^COTURN_ENABLED=yes /etc/kopano/default
	then
		apt-get install -y --no-install-recommends coturn >>/etc/kopano/custom/postbuild.log 2>&1
		# configuration for coturn to be added here...
		service start coturn
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
	touch /etc/kopano/init.run
	init_kopano
	install_ssl
	set_acl
	set_secrets
	post_build
	if grep -q ^CLAMAVD_ENABLED=yes /etc/kopano/default ; then echo "initializing av database.." && freshclam > /dev/null 2>&1; fi
	# set init.done flag
	if [ -e /etc/kopano/init.run ] ; then rm /etc/kopano/init.run ; fi
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
			w_srv_on nginx && w_srv_on php${PHP_VER}-fpm && w_srv_on kopano-presence && w_srv_on kopano-webmeetings && 
			w_srv_on coturn && s_srv_on rsyslog && s_srv_on cron
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
		set_secrets
		start_kopano
		exit 0
		;;
	acl)
		set_acl
		exit 0
		;;
	reset)
		echo "Image reset request. Intializing UID, GID, etc-cfg, log, ssl"
		if [ -e /etc/kopano/ssl/PRESENCE_SHARED_SECRET ] ; then rm  /etc/kopano/ssl/PRESENCE_SHARED_SECRET ; fi
		if [ -e /etc/kopano/ssl/WEBMEETINGS_SHARED_SECRET ] ; then rm /etc/kopano/ssl/WEBMEETINGS_SHARED_SECRET ; fi
		if [ -e /etc/kopano/ssl/WEBMEETINGS_SESSION_SECRET ] ; then rm /etc/kopano/ssl/WEBMEETINGS_SESSION_SECRET ; fi
		if [ -e /etc/kopano/ssl/WEBMEETINGS_ENCRYPTION_SECRET ] ; then rm /etc/kopano/ssl/WEBMEETINGS_ENCRYPTION_SECRET ; fi
		# avoid docker while loop to exit
		touch /etc/kopano.restart
		if k_srv_on kopano-server
		then
			stop_kopano
			sleep 1
		fi
		kill_kopano
		# set init.run flag to avoid overlapping init /  upgrades
		touch /etc/kopano/init.run
		init_kopano
		install_ssl
		set_acl
		set_secrets
		post_build
		if grep -q ^CLAMAVD_ENABLED=yes /etc/kopano/default ; then echo "initializing av database.." && freshclam > /dev/null 2>&1; fi
		# set init.done flag
		if [ -e /etc/kopano/init.run ] ; then rm /etc/kopano/init.run ; fi
		echo "$(date "+%Y-%m-%d-%H:%M")" > /etc/kinit.done
		start_kopano
		exit 0
		;;
	status)
		if [ -e /etc/kopano4h/init.run ]
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
			w_srv_on nginx && w_srv_on php${PHP_VER}-fpm && w_srv_on kopano-presence && w_srv_on kopano-webmeetings && 
			w_srv_on coturn && s_srv_on rsyslog && s_srv_on cron
		then
			echo "Running: $K_SERVICES"
			echo "Running: $W_SERVICES"
			echo "Running: $M_SERVICES"
			echo "Running: $S_SERVICES"
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
				RET="$RET, PHP5-FPM Running"
			else
				RET="$RET, PHP5-FPM Not Running"
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
			if w_srv_on kopano-webmeetings
			then
				if echo $W_SERVICES | grep -q "kopano-webmeetings"
				then
					RET="$RET, Webmeetings Running"
				else
					RET="$RET, Webmeetings Disabled"
				fi
			else
				RET="$RET, Webmeetings Not Running"
			fi
			if w_srv_on coturn
			then
				if echo $W_SERVICES | grep -q "coturn"
				then
					RET="$RET, CoTurn Running"
				else
					RET="$RET, CoTurn Disabled"
				fi
			else
				RET="$RET, CoTurn Not Running"
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
				RET="$RET, Fetchmail Not Running"
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
	maintenance)
		echo "running in maintenance mode: no kopano services will be started.."
		touch /etc/kopano.maintenance
		tail -f /dev/null
		;;
	alive)
		if ! k_supported_license 
		then 
			echo "fatal error: could no validate /etc/kopano/license/base for kopano supported edition"	
			exit 1
		fi
		# clean up old pid.files
		if ls /var/run/kopano/*.pid 1> /dev/null 2>&1; then rm /var/run/kopano/*.pid ; fi
		mysql_sock_on && start_kopano
		if grep -q ^CLAMAVD_ENABLED=yes /etc/kopano/default ; then freshclam > /dev/null 2>&1; fi
		if ! w_srv_on nginx ; then service nginx start ; fi
		echo "staying alive while kopano service is running.."
		HEALTH_C_TIMER=0
		while k_srv_on kopano-server
		do
			sleep 10
			# run kopano-dbadm for warnings if advised in server.log
			if tail -2 /var/log/kopano/server.log | grep warning | grep -q kopano-dbadm ; then dbadm_repair ; fi
			HEALTH_C_TIMER=$(expr $HEALTH_C_TIMER + 10)
			# health check each 3 mins for critical services
			if [ $HEALTH_C_TIMER -gt 180 ]
			then
				HEALTH_C_TIMER=0
				if ! k_srv_on kopano-spooler ; then service kopano-spooler start ; fi
				if ! k_srv_on kopano-dagent ; then service kopano-dagent start ; fi
				if ! s_srv_on rsyslog ; then service rsyslog start ; fi
				if ! s_srv_on cron ; then service cron start ; fi
				if ! m_srv_on postfix ; then service postfix start ; fi
				if ! w_srv_on nginx && grep -q ssl /var/log/nginx/error.log ; then default_ssl ; fi
				if ! w_srv_on nginx ; then service nginx start ; fi
				if ! w_srv_on php${PHP_VER}-fpm ; then service php${PHP_VER}-fpm start ; fi
				if ! m_srv_on clamav-daemon ; then service clamav-daemon start ; fi
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
					if ! m_srv_on amavis postgrey ; then disable_postgrey ; fi
				fi
				if echo $EDITION | grep -q "Migration"
				then
					MIG_TIMER=$(expr $MIG_TIMER - 1)
					if [ $MIG_TIMER -lt 1 ]
					then
						echo "6hrs uptime for migration purpose done exiting now.."
						exit 1
					fi
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
	echo "Valid parameters: start, stop, restart, reset, upgrade, ssl, acl, status, alive (up when core service running), maintenance (up)"
	exit 1
	;;
esac
