#!/bin/sh
# (c) 2018-19 vbettag - wraper for synoautoblock and notification to be used by fail2ban
# inspired by ruedi61: https://www.synology-forum.de/showthread.html?80679-Automatischer-Import-einer-Blockliste
# DSM 6.2 AutoBlockIP Table via .sqlite3 /etc/synoautoblock.db & .schema AutoBlockIP:
#CREATE TABLE AutoBlockIP(IP varchar(50) PRIMARY KEY,RecordTime date NOT NULL,ExpireTime date NOT NULL,Deny boolean NOT NULL,IPStd varchr(50) NOT NULL,Type INTEGER,Meta varchar(256));
# CREATE TABLE AutoBlockIP(IP varchar(50) PRIMARY KEY,RecordTime date NOT NULL,ExpireTime date NOT NULL,Deny boolean NOT NULL,IPStd varchr(50) NOT NULL); 
DELETE_IP_AFTER="3"
LOGIN=`whoami`
MAJOR_VERSION=`grep majorversion /etc.defaults/VERSION | grep -o [0-9]`
if [ $LOGIN != "root" ]
then 
	echo "you have to run as root! alternatively as admin run with sudo prefix! exiting.."
	exit 1
fi
if [ $# -eq 0 ]
then
	echo "usage: kopano-autoblock [IP | help | list]"
	exit 0
fi
if [ $# -gt 0 ] && [ "$1" == "help" ]
then
	echo "kopano-autoblock (c) TosoBoso: wraper to synoautoblock and notification for fail2ban."
	echo "usage: kopano-autoblock [IP | help | list]"
	echo "provide IP and it will be blocked plus notified; use list to show all blocked IPs same as per Synology GUI."
	exit 0
fi
if [ $# -gt 0 ] && [ "$1" == "list" ]
then
	echo "List from synoautoblock for blocks by kopano4s (unblocked in $DELETE_IP_AFTER days):"
	sqlite3 -csv /etc/synoautoblock.db "select ip from AutoBlockIP where Meta = 'Kopano4s';"
	exit 0
fi
# default block incl validation of IP as paramater 1
# get package config for notification
. /var/packages/Kopano4s/etc/package.cfg
BLOCKED_IP=$1
UNIXTIME=`date +%s`
UNIXTIME_DELETE_IP=`date -d "+$DELETE_IP_AFTER days" +%s`
# Check if IP valid
VALID_IPv4=`echo "$BLOCKED_IP" | grep -Eo "^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$" | wc -l`
if [[ $VALID_IPv4 -eq 1 ]]
then
	# since synoautoblock does not work with --deny we go for sqllite as shown by ruedi61
	# Convert IPv4 to IPv6 :)
	IPv4=`echo $BLOCKED_IP | sed 's/\./ /g'`
	IPv6=`printf "0000:0000:0000:0000:0000:FFFF:%02X%02X:%02X%02X" $IPv4` 
	CHECK_IF_EXISTS=`sqlite3 /etc/synoautoblock.db "SELECT DENY FROM AutoBlockIP WHERE IP = '$BLOCKED_IP'" | wc -l`
	if [[ $CHECK_IF_EXISTS -lt 1 ]]
	then
		#/usr/syno/bin/synoautoblock --deny $BLOCKED_IP
		INSERT=`sqlite3 /etc/synoautoblock.db "INSERT INTO AutoBlockIP VALUES ('$BLOCKED_IP','$UNIXTIME','$UNIXTIME_DELETE_IP','1','$IPv6',0,'Kopano4s')"`
		MSG="IP $BLOCKED_IP had been blocked by Kopano4s at $(date "+%Y.%m.%d-%H.%M.%S")"
		echo $MSG
		/usr/syno/bin/synodsmnotify $NOTIFYTARGET Kopano4s "$MSG"
	else
		echo "IP already in Database: $BLOCKED_IP"
	fi
else
	echo "No valid IP-4 provided: $BLOCKED_IP"
fi
