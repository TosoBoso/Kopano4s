#!/bin/sh
# (c) 2015/16 vbettag - script for fetchmail integration with kopano via postfix
#
FRC="/etc/kopano/fetchmailrc"
case "$1" in
	help)
	echo "kopano-fetchmail (c) TosoBoso: script for fetchmail integration with kopano via postfix"
	echo "Usage: kopano-fetchmail list, add, remove, (no)keep, (re)start, stop, status, init, test, help."
	echo "list entries, add new fetchmail user or remove it. Init as a service or run in test mode to debug."
	exit 0
	;;
	status)
	if service fetchmail status | grep -q "fetchmail is running"
	then
		if grep -q '#mda=on' $FRC
		then
			echo "fetchmail is running mda-mode (no Spam/AV)."		
		else
			echo "fetchmail is running via postfix and Spam/AV."		
		fi
	else
		echo "fetchmail is NOT running."	
	fi	
	exit 0
	;;
	stop)
	if [ $# -gt 1 ] && [ $2 = "force" ]
	then
		echo "stoping fetchmail with kill-all..."
		CMD="killall -q -9 fetchmail"
		if [ -e /var/run/fetchmail/fetchmail.pid ] ; then rm /var/run/fetchmail/fetchmail.pid ; fi
	else
		echo "stoping gracefully. check the status and eventually run stop force"
		CMD="service fetchmail stop"
	fi
	;;
	start)
	if grep -q "place your configuration here" $FRC || ! grep -q "^poll" $FRC
	then
		echo "at least 1 poll entry must be present and init has to be done before starting it.."
		sed -i -e 's~FETCHMAIL_ENABLED.*~FETCHMAIL_ENABLED=no~' /etc/kopano/default
		exit 1
	fi
	CMD="service fetchmail start"
	;;
	restart)
	if grep -q "place your configuration here" $FRC || ! grep -q "^poll" $FRC
	then
		echo "at least 1 poll entry must be present and init has to be done before starting it.."
		sed -i -e 's~FETCHMAIL_ENABLED.*~FETCHMAIL_ENABLED=no~' /etc/kopano/default
		exit 1
	fi
	killall -q -9 fetchmail
	if [ -e /var/run/fetchmail/fetchmail.pid ] ; then rm /var/run/fetchmail/fetchmail.pid ; fi
	sleep 2
	CMD="service fetchmail start"
	;;
	test)
	if [ $# -gt 1 ]
	then
		SEC=$2
	else
		SEC=40
	fi
	killall -q -9 fetchmail
	if [ -e /var/run/fetchmail/fetchmail.pid ] ; then rm /var/run/fetchmail/fetchmail.pid ; fi
	echo "fetchmail in debug mode hit crtl.c and then restart service.."
	CMD="/etc/init.d/fetchmail debug-run"
	;;
	init)
	if grep -q "place your configuration here" $FRC || ! grep -q "^poll" $FRC
	then
		echo "at least 1 poll entry must be present and init has to be done before starting it.."
		sed -i -e 's~FETCHMAIL_ENABLED.*~FETCHMAIL_ENABLED=no~' /etc/kopano/default
		exit 1
	fi
	echo "init: enable fetchmail in kopano-default, add it to dagent local_admin_users and start it.."
	sed -i -e 's~FETCHMAIL_ENABLED.*~FETCHMAIL_ENABLED=yes~' /etc/kopano/default
	# ensure fetchmail part of local_admin_users to dagent via server.cfg
	if ! grep -q fetchmail /etc/kopano/server.cfg
	then
		sed -i -e "s~root kopano~root kopano fetchmail~" /etc/kopano/server.cfg
	fi
	touch /etc/kopano/default-fetchmail
	if ! grep -q START_DAEMON /etc/kopano/default-fetchmail
	then
		echo -e "# Declare demon mode here\nSTART_DAEMON=yes" > /etc/kopano/default-fetchmail
	fi	
	sed -i -e "s~START_DAEMON=no~START_DAEMON=yes~" /etc/kopano/default-fetchmail
	# make softlinks
	ln -sf $FRC /etc/fetchmailrc
	ln -sf /etc/kopano/default-fetchmail /etc/default/fetchmail
	adduser fetchmail kopano
	chown fetchmail.kopano $FRC
	chmod 600 $FRC
	touch /var/log/kopano/fetchmail.log
	chown root.kopano /var/log/kopano/fetchmail.log
	chmod 660 /var/log/kopano/fetchmail.log
	touch /var/log/kopano/dagent.log
	chown root.kopano /var/log/kopano/dagent.log
	chmod 660 /var/log/kopano/dagent.log
	# ensure rotate log of fetchmail
	cat <<-EOF > "/etc/logrotate.d/fetchmail" 
		/var/log/kopano/fetchmail.log {
		su root kopano
		weekly
		missingok
		rotate 4
		compress
		delaycompress
	}
	EOF
	# kill old fetchmail processes and pid for a clean start
	killall -q -9 fetchmail
	if [ -e /var/run/fetchmail/fetchmail.pid ] ; then rm -f /var/run/fetchmail/fetchmail.pid ; fi
	CMD="service fetchmail start"
	;;	
	list)
	if grep -q "place your configuration here" $FRC
	then
		echo "no poll entries so far"
		exit 1
	fi	
	USRLIST='k-user; r-user; r-pwd; server; protocol; port; ssl; folder(s)'
	while read LINE
	do
		IFS=" "
		set -- $LINE
		# we only take poll ntries with 13 or 1 entries
		#poll pop3.svr protocol pop3 port 995 user xy pass 'z' ssl mda "pgm z-usr"
		if [ $# -gt 12 ] && [ $1 = "poll" ]
		then
			SVR=$2
			PROT=$4
			PORT=$6
			USR=$8
			PWD=$10
			# folder imap only before mda/is in pos 11 or 12 dependent on ssl
			if ([ $PROT = "imap" ] || [ $PROT = "IMAP" ]) && [ $11 != "mda" ] && [ $12 != "mda" ] && [ $11 != "is" ] && [ $12 != "is" ]
			then
				# 2 more compared to default mda on pos 13 or 14
				if [ $11 != "ssl" ]
				then
					FLD=$12
					if [ $13 = "mda" ]
					then
						# two pos after mda, cut last char
						ZUSR=${15%?}
					else
						ZUSR=$14
					fi
					SSL="no-ssl"
				else
					FLD=$13
					if [ $14 = "mda" ]
					then
						ZUSR=${16%?}
					else
						ZUSR=$15
					fi
					SSL="ssl"
				fi
			else
				#default pop3 no folder mda on pos 11 or 12
				FLD="INBOX"
				if [ $11 != "ssl" ]
				then
					if [ $11 = "mda" ]
					then
						# two pos after mda, cut last char
						ZUSR=${13%?}
					else
						ZUSR=$12
					fi
					SSL="no-ssl"
				else
					if [ $12 = "mda" ]
					then
						ZUSR=${14%?}
					else
						ZUSR=$13
					fi
					SSL="ssl"
				fi
			fi
			USRLIST="$USRLIST\n$ZUSR;$USR;$10;$SVR;$PROT;$PORT;$SSL;$FLD"
		fi
	done < $FRC
	echo "$USRLIST"
	exit 0
	;;
	add)
	if [ $# -lt 9 ]
	then
		echo "please provide all fetch-mail parameters in order: k-user r-user r-pwd server protocol port ssl folder (INBOX or n/a for pop3)"
		exit 1
	fi
	ZUSR=$2
	USR=$3
	PWD=$4
	SVR=$5
	PROT=$6
	PORT=$7
	SSL=$8
	if ([ $PROT = "imap" ] || [ $PROT = "IMAP" ]) && [ $9 != "n/a" ]
	then
		FLD=" folder $9"
	else
		FLD=""
	fi
	if [ $SSL != "ssl" ]
	then
		SSL=""
	else
		SSL=" ssl"	
	fi
	if grep $ZUSR $FRC | grep -q $USR
	then
		echo "no duplicate entries with same kopano and remote user allowed."
		exit 1	
	fi
	NOINIT=0
	if grep -q "#place your configuration here" $FRC
	then
		sed -i -e "s~#place your configuration here~# poll entries~" $FRC
		NOINIT=1
	fi
	chmod 660 $FRC
	if grep -q "#preconnect_tstamp=on" $FRC
	then 
		PRECON=" preconnect \"date >> /var/log/kopano/fetchmail.log\""
	else
		PRECON=""
	fi
	if grep -q "#mda=on" $FRC
	then
		# the mda mail delivery way with z-account
		DELIVER="mda \"/usr/sbin/kopano-dagent $ZUSR\""
	else
		# the postfix way with z-email
		#DOMAIN=`grep ^mydomain /etc/kopano/postfix/main.cf | cut -f2 -d'=' | grep -o '[^\t ].*'`
		# set envelope X-Delivered-to localdomains $DOMAIN after fetch from
		DELIVER="is $ZUSR here"
	fi
	echo "poll $SVR protocol $PROT port $PORT user $USR pass '${PWD}'${SSL}${FLD} ${DELIVER}${PRECON}" >> $FRC
	chmod 600 $FRC
	echo "OK adding fetchmail entry for k-user $ZUSR as $USR at $SVR."
	if [ $NOINIT -gt 0 ]
	then
		echo "post adding first entry you have to run kopano-fetchmail init."
		exit 0
	fi
	killall -q -9 fetchmail
	sleep 2
	if [ -e /var/run/fetchmail/fetchmail.pid ] ; then rm /var/run/fetchmail/fetchmail.pid ; fi
	CMD="service fetchmail start"
	;;
	remove)
	if [ $# -lt 3 ]
	then
		echo "please provide kopano user and external user of entry to remove"
		exit 1
	fi
	LINE=`grep $2 $FRC | grep $3`
	if [ -n "$LINE" ]
	then
		sed -i -e "s~$LINE~~" $FRC
	else
		echo "no match found for $2:$3"
		exit 1
	fi
	echo "removed fetchmail entry for k-user $2 as $3."
	if ! grep -q "^poll" $FRC
	then
		# no more entries so disable service
		echo "disable service as no more poll entries exist."
		sed -i -e "s~# poll entries~#place your configuration here~" $FRC
		sed -i -e 's~FETCHMAIL_ENABLED.*~FETCHMAIL_ENABLED=no~' /etc/kopano/default
		exit 0
	fi
	killall -q -9 fetchmail
	sleep 2
	if [ -e /var/run/fetchmail/fetchmail.pid ] ; then rm /var/run/fetchmail/fetchmail.pid ; fi
	CMD="service fetchmail start"
	;;
	*)
	echo "Usage: kopano-fetchmail list, add, remove, (re)start, stop, status, init, test, help"
	exit 1
	;;
esac
# run command
$CMD
exit 0
