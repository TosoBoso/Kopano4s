#!/bin/sh
# (c) 2015/16 vbettag - script for postfix configuration with kopano

case "$1" in
	help)
	echo "kopano-postfix (c) TosoBoso: script and postconf wrapper for postfix integration with kopano4s"
	echo "Usage: kopano-postfix plus config, edit, relay, tls, stop, (re)start, reset, loglines, logsumm, map, queue, queuemsgs, show, requeue, release, resend, delete, flush, sync-/stats-/reset-/export-/import-/baseline-spamdb, train-spam/ham, test-smtp/amavis/spam/smail, help"
	echo "config shows the current setting incl health check (postconf -n && postfix check)"
	echo "edit plus argument changes main.cf entry (e.g. edit 'mynetworks = 127.0.0.0/8')"
	echo "relay plus server, user, password arguments creates a relay server entry; off disables it"
	echo "tls plus on / off enable or disables opportunistic encryption via transport layer security"
	echo "stop, (re)start to change and let new settings being effective; use it after your set of changes via edit"
	echo "resets gets back to original configuration from install for main.cf and master.cf"
	echo "loglines plus number shows no of rows (default 5) to mail.log, .err, .warn, .info files"
	echo "logsumm calls utility pflogsumm with default paramaters for daily summary; call logsumm --help for details."
	echo "map plus file-name runs postmap on it; reset goes back to initial configuration at install"
	echo "queue shows the status of active (*), hold (!) defer queues and queuemsgs the messages inside"
	echo "show, requeue, release, resend, delete manipulates respective mailqueue-ids whil flush is for all"
	echo "sync-/stats-/reset-/export-/import-/baseline-spamdb performs actions on spamassassin bayesian database."
	echo "train-spam/ham trains sa-bayesian-db with input to respective amavis directory. Run sync-spamdb afterwards."
	echo "test-smtp plus recipient as argument (default: posmaster) runs a telnet test session to the smpt-server."
	echo "test-amvis runs a telnet test session to the lmtp-amvis server on 10024 and reinject smtpd-service on 10025."
	echo "test-spam runs a telnet test session with spam string in body that should be marked by spamassassin."
	echo "test-smail recipient as argument (default: posmaster) runs sendmail for testing postfix incl. recipient msg."
	echo "help obviously shows this dialog"
	exit 0	
	;;
	stop)
	echo "only stop postfix for configuration or upgrade purpose and remeber to restart it later"
	CMD="service postfix stop"
	;;
	start)
	CMD="service postfix start"
	;;
	restart)
	if grep -q ^CLAMAVD_ENABLED=yes /etc/kopano/default ; then service clamav-daemon restart ; fi
	if grep -q ^AMAVISD_ENABLED=yes /etc/kopano/default ; then service amavis restart ; fi
	CMD="service postfix restart"
	;;
	reset)
	echo "reset main.cf and master.cf to initial stat at install..."
	cp /etc/kopano/postfix/main.init /etc/kopano/postfix/main.cf
	cp /etc/kopano/postfix/master.init /etc/kopano/postfix/master.cf
	exit 0
	;;
	reconfigure)
	CMD="dpkg-reconfigure -freadline postfix"
	;;
	config)
	CMD="postconf -n"
	;;
	queuemsgs)
	QS="defer deferred active incoming maildrop hold"
	QPATH=`postconf -h queue_directory`
	for q in $QS
	do
		FILES=`find $QPATH/$q -type f`
		if [ "_$FILES" != "_" ] ; then echo "** mails in queue $q **" ; fi
		for f in $FILES
		do
			postcat $f
		done
	done
	exit 0
	CMD="postqueue -p"
	;;
	queue)
	CMD="postqueue -p"
	;;
	show)
	if [ $# -gt 1 ]
	then
		CMD="postcat -qv $2"
	else
		echo "please provide queue-id to postcat as 2nd parameter"
		exit 1
	fi
	;;	
	delete)
	if [ $# -gt 1 ]
	then
		echo "deleting message-id $2"
		CMD="postsuper -d $2"
	else
		echo "please provide queue-id to postsuper as 2nd parameter"
		exit 1
	fi
	;;	
	requeue)
	if [ $# -gt 1 ]
	then
		echo "requeueing message-id $2"
		CMD="postsuper -r $2"
		if [ "$2" != "ALL" ] 
		then
			CMD2="postqueue -i $2"
		else
			CMD2="postqueue -f"
		fi
	else
		echo "please provide queue-id to postsuper as 2nd parameter"
		exit 1
	fi
	;;	
	release)
	if [ $# -gt 1 ]
	then
		echo "releasing $2 from on-hold and resending it"
		CMD="postsuper -H $2"
		if [ "$2" != "ALL" ] 
		then
			CMD2="postqueue -i $2"
		else
			CMD2="postqueue -f"
		fi
	else
		echo "please provide queue-id to postsuper as 2nd parameter"
		exit 1
	fi
	;;
	resend)
	if [ $# -gt 1 ]
	then
		echo "resending message-id $2"
		CMD="postqueue -i $2"
	else
		echo "please provide queue-id to postqueue as 2nd parameter"
		exit 1
	fi
	;;
	flush)
	CMD="postqueue -f"
	;;
	loglines)
	if [ $# -gt 1 ]
	then
		LINES=$2
	else
		LINES=5
	fi
	LOG=`tail -$LINES /var/log/mail.log`
	ERR=`tail -$LINES /var/log/mail.err`
	WARN=`tail -$LINES /var/log/mail.warn`
	INFO=`tail -$LINES /var/log/mail.info`
	CMD="echo last $LINES log lines: $LOG , err: $ERR , warn: $WARN, info: $INFO"
	;;
	logsumm)
	if [ $# -gt 1 ]
	then
		PAR="$2 $3 $4 $5 $6 $7 $8 $9"
	else
		echo "using pflogsumm default -d today /var/log/mail.log call logsumm --help for details"
		PAR="-d today /var/log/mail.log"
	fi	
	CMD="pflogsumm $PAR"
	;;	
	edit)
	if [ $# -gt 1 ]
	then
		echo "editing entry '$2'.."
		# postconf overwrites softlink
		postconf -e "$2"
		if [ ! -h /etc/postfix/main.cf ]
		then
			cp /etc/postfix/main.cf /etc/kopano/postfix/main.cf
			ln -sf /etc/kopano/postfix/main.cf /etc/postfix/main.cf
		fi
		postfix check
		CMD="postconf -n"
	else
		echo "please provide config to edit as 2nd parameter in ':single quotes"
		exit 1
	fi
	;;
	map)
	if [ $# -gt 1 ]
	then
		if [ -e $2 ]
		then
			# remove empty lines
			sed -i '/^$/d' $2
			echo "postmap on '$2'.."
			CMD="postmap $2"
		else
			echo "config file $2 not found"
			exit 1
		fi
	else
		echo "please provide file to postmap as 2nd parameter in ':single quotes"
		exit 1
	fi
	;;
	relay)
	if [ $# -eq 2 ] && [ "$2" = "off" ]
	then
		echo "disabling relay host setting.."
		sed -i -e "s~relayhost =.*~#relayhost = smtp.example.com~" /etc/kopano/postfix/main.cf
		sed -i -e "s~smtp_sasl_~#smtp_sasl_~g" /etc/kopano/postfix/main.cf
		sed -i -e "s~smtp_use_tls~#smtp_use_tls~" /etc/kopano/postfix/main.cf
		sed -i -e "s~smtp_smtp_tls_~#smtp_smtp_tls_~g" /etc/kopano/postfix/main.cf
		exit 0
	fi
	if [ $# -lt 4 ]
	then
		echo "please all parameters for relay: server, user, pwd in ':single quotes"
		exit 1
	fi
	SVR=$2
	USR=$3
	PWD=$4
	echo "adding relay server $SVR for $USR:$PWD.."
	sed -i -e "s~#relayhost~relayhost~" /etc/kopano/postfix/main.cf
	sed -i -e "s~#smtp_sasl_~smtp_sasl_~g" /etc/kopano/postfix/main.cf
	sed -i -e "s~#smtp_use_tls~smtp_use_tls~" /etc/kopano/postfix/main.cf
	sed -i -e "s~#smtp_smtp_tls_~smtp_smtp_tls_~g" /etc/kopano/postfix/main.cf
	echo "$SVR	$USR:$PWD" > /etc/kopano/postfix/sasl_passwd
	postmap /etc/kopano/postfix/sasl_passwd
	# postconf overwrites softlink
	postconf -e "relayhost=$SVR"
	if [ ! -h /etc/postfix/main.cf ]
	then
		cp /etc/postfix/main.cf /etc/kopano/postfix/main.cf
		ln -sf /etc/kopano/postfix/main.cf /etc/postfix/main.cf
	fi
	postfix check
	CMD="postconf -n relayhost"
	;;	
	tls)
	if [ $# -gt 1 ]
	then
		echo "please provide tls parameter on or off"
		exit 1	
	fi
	if [ "$2" = "on" ]
	then
		sed -i -e "s~#myhostname~myhostname~" /etc/kopano/postfix/main.cf
		sed -i -e "s~#smtpd_use_tls~smtpd_use_tls~" /etc/kopano/postfix/main.cf
		sed -i -e "s~#tls_random_source~tls_random_source~" /etc/kopano/postfix/main.cf
		sed -i -e "s~#smtpd_tls_~smtpd_tls_~g" /etc/kopano/postfix/main.cf
	else
		sed -i -e "s~myhostname~#myhostname~" /etc/kopano/postfix/main.cf
		sed -i -e "s~smtpd_use_tls~#smtpd_use_tls~" /etc/kopano/postfix/main.cf
		sed -i -e "s~tls_random_source~#tls_random_source~" /etc/kopano/postfix/main.cf
		sed -i -e "s~smtpd_tls_~#smtpd_tls_~g" /etc/kopano/postfix/main.cf		
	fi
	exit 0
	;;
	refresh-avdb)
	echo "refreshing antivirus database by freshclam.."
	CMD="freshclam >/dev/null 2>&1"
	;;
	sync-spamdb)
	echo "Syncing spamassassin bayesian database with current learnings.."
	# must change to directory where amavis user can read from otherwise perl wil do cannot parse errors
	CPATH=`pwd`
	cd /var/lib/amavis
	su amavis -c 'sa-learn --sync'
	cd $CPATH
	exit 0
	;;
	stats-spamdb)
	echo "Statistics of users amavis spamassassin bayesian database.."
	CPATH=`pwd`
	cd /var/lib/amavis
	su amavis -c 'sa-learn --dump magic'
	exit 0
	;;
	debug-spamdb)
	echo "Debug mode and statistics of users amavis spamassassin bayesian database.."
	CPATH=`pwd`
	cd /var/lib/amavis
	su amavis -c 'sa-learn --sync -D'
	cd $CPATH
	exit 0
	;;
	reset-spamdb)
	echo "reset / clear spamassassin bayesian database.."
	CPATH=`pwd`
	cd /var/lib/amavis
	su amavis -c 'sa-learn --clear'
	cd $CPATH
	exit 0
	;;
	export-spamdb)
	echo "export amavis users spamassassin bayesian database.."
	CPATH=`pwd`
	cd /var/lib/amavis
	if [ -e /var/lib/amavis/export/sa-bay-db.gz ] ; then rm /var/lib/amavis/export/sa-bay-db.gz ; fi
	su amavis -c 'sa-learn --backup  >/var/lib/amavis/export/sa-bay-db'
	gzip /var/lib/amavis/export/sa-bay-db
	cd $CPATH
	exit 0
	;;
	import-spamdb)
	echo "import amavis users spamassassin bayesian database.."
	if [ ! -e /var/lib/amavis/export/sa-bay-db.gz ]
	then
		echo "error no /var/lib/amavis/export/sa-bay-db.gz found to import"
		exit 1
	fi
	CPATH=`pwd`
	cd /var/lib/amavis
	gunzip /var/lib/amavis/export/sa-bay-db.gz
	su amavis -c 'sa-learn --restore /var/lib/amavis/export/sa-bay-db'
	gzip /var/lib/amavis/export/sa-bay-db.gz
	cd $CPATH
	exit 0
	;;
	baseline-spamdb)
	echo "baseline training from spamassassin.apache.org/old/publiccorpus.."
	CPATH=`pwd`
	cd /var/lib/amavis
	tar xvf spamtrain.tgz >/dev/null 2>&1
	chown -R amavis.debian-spamd /var/lib/amavis/spamtrain
	echo "learning spam from training collection.."
	su amavis -c 'sa-learn --no-sync --progress --spam /var/lib/amavis/spamtrain/spam'
	echo "learning ham from training collection.."
	su amavis -c 'sa-learn --no-sync --progress --ham /var/lib/amavis/spamtrain/ham'
	rm -R /var/lib/amavis/spamtrain
	su amavis -c 'sa-learn --sync > /dev/null 2>&1'
	cd $CPATH
	exit 0
	;;
	train-spam)
	echo "training spam from spamasasin directory do not forget to run sync-spamdb later.."
	su amavis -c 'sa-learn --no-sync --progress --spam /var/lib/amavis/spam'
	cd $CPATH
	exit 0
	;;	
	train-ham)
	echo "training ham from spamasasin directory do not forget to run sync-spamdb later.."
	su amavis -c 'sa-learn --no-sync --progress --ham /var/lib/amavis/ham'
	cd $CPATH
	exit 0
	;;	
	test-smtp)
		DOMAIN=`grep ^mydomain /etc/postfix/main.cf | cut -f2 -d'=' | grep -o '[^\t ].*'`
		# split off first part
		if echo "$DOMAIN" | grep -q ';'
		then
			DOMAIN=`echo "$DOMAIN" | cut -f1 -d','`
		fi
		SDR="postmaster@$DOMAIN"
		if [ $# -gt 1 ]
		then
			RCP=$2
		else
			RCP="postmaster@$DOMAIN"
		fi
		echo "running test into telnet session to smpd on port 25 with ehelo $DOMAIN to $RCP Subject: testmail.."
		(
		echo "EHLO $DOMAIN";
		sleep 1;
		echo "mail from:<$SDR>";
		sleep 1;
		echo "rcpt to:<$RCP>";
		sleep 1;
		echo "data";
		sleep 1;
		echo "subject: testmail";
		echo "for kopano4s.";
		echo ".";
		echo "quit";
		sleep 2;
		) | telnet localhost 25
		exit 0;
	;;
	test-amavis)
		DOMAIN=`grep ^mydomain /etc/postfix/main.cf | cut -f2 -d'=' | grep -o '[^\t ].*'`
		# split off first part
		if echo "$DOMAIN" | grep -q ';'
		then
			DOMAIN=`echo "$DOMAIN" | cut -f1 -d','`
		fi
		SDR="postmaster@$DOMAIN"
		if [ $# -gt 1 ]
		then
			RCP=$2
		else
			RCP="postmaster@$DOMAIN"
		fi
		echo "running test into telnet session on amavisd on port 10024 with ehelo localhost.."
		(
		echo "EHLO localhost";
		sleep 1;
		echo "quit";
		sleep 2;
		) | telnet localhost 10024
		echo "running test into telnet session on reinject on port 10025 with ehelo $DOMAIN to $RCP Subject: testmail.."
		(
		echo "EHLO $DOMAIN";
		sleep 1;
		echo "mail from:<$SDR>";
		sleep 1;
		echo "rcpt to:<$RCP>";
		sleep 1;
		echo "data";
		sleep 1;
		echo "subject: testmail for amavis";
		echo "for kopano4s in amavis reinject smpd.";
		echo ".";
		echo "quit";
		sleep 2;
		) | telnet localhost 10025
		exit 0;
	;;
	test-spam)
		DOMAIN=`grep ^mydomain /etc/postfix/main.cf | cut -f2 -d'=' | grep -o '[^\t ].*'`
		# split off first part
		if echo "$DOMAIN" | grep -q ';'
		then
			DOMAIN=`echo "$DOMAIN" | cut -f1 -d','`
		fi
		SDR="postmaster@$DOMAIN"
		if [ $# -gt 1 ]
		then
			RCP=$2
		else
			RCP="postmaster@$DOMAIN"
		fi
		echo "running spam test into telnet session to smpd on port 25 with ehelo $DOMAIN to $RCP Subject: testmail for spam.."
		(
		echo "EHLO $DOMAIN";
		sleep 1;
		echo "mail from:<$SDR>";
		sleep 1;
		echo "rcpt to:<$RCP>";
		sleep 1;
		echo "data";
		sleep 1;
		echo "subject: testmail for spam";
		echo "XJS*C4JDBQADN1.NSBN3*2IDNEN*GTUBE-STANDARD-ANTI-UBE-TEST-EMAIL*C.34X";
		echo ".";
		echo "quit";
		sleep 2;
		) | telnet localhost 25
		exit 0;
	;;
		test-avmail)
		DOMAIN=`grep ^mydomain /etc/postfix/main.cf | cut -f2 -d'=' | grep -o '[^\t ].*'`
		# split off first part
		if echo "$DOMAIN" | grep -q ';'
		then
			DOMAIN=`echo "$DOMAIN" | cut -f1 -d','`
		fi
		SDR="postmaster@$DOMAIN"
		if [ $# -gt 1 ]
		then
			RCP=$2
		else
			RCP="postmaster@$DOMAIN"
		fi
		echo "running av test into telnet session to smpd on port 25 with ehelo $DOMAIN to $RCP Subject: testmail for anti-virus.."
		(
		echo "EHLO $DOMAIN";
		sleep 1;
		echo "mail from:<$SDR>";
		sleep 1;
		echo "rcpt to:<$RCP>";
		sleep 1;
		echo "data";
		sleep 1;
		echo "subject: testmail for anti-virus";
		echo "X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*";
		echo ".";
		echo "quit";
		sleep 2;
		) | telnet localhost 25
		exit 0;
	;;
	test-smail)
		DOMAIN=`grep ^mydomain /etc/postfix/main.cf | cut -f2 -d'=' | grep -o '[^\t ].*'`
		if [ $# -gt 1 ]
		then
			RCP=$2
		else
			RCP="postmaster@$DOMAIN"
		fi
		echo "running test via sendmail to $RCP"
		echo 'Subject: sendmail test' | sendmail -v $RCP
		exit 0
	;;
	*)
	echo "Usage: kopano-postfix plus config, edit, relay, tls, stop, (re)start, reset, loglines, logsumm, map, queue, queuemsgs, show, requeue, release, resend, delete, flush, sync-/stats-/reset-/export-/import-/baseline-spamdb, train-spam/ham, test-smtp/amavis/spam/smail, help"
	exit 1
	;;
esac
# run command
$CMD
if [ "_$CMD2" != "_" ] ; then $CMD2 ; fi
exit 0
