#!/bin/sh
# (c) 2018 vbettag - wraper script for kopano-backup in Docker container
# admins only plus set sudo for DSM 6 as root login is no longer possible
LOGIN=`whoami`
if [ $LOGIN != "root" ] && ! (grep administrators /etc/group | grep -q $LOGIN)
then 
	echo "admins only"
	exit 1
fi
MAJOR_VERSION=`grep majorversion /etc.defaults/VERSION | grep -o [0-9]`
if [ $MAJOR_VERSION -gt 5 ] && [ $LOGIN != "root" ]
then
	echo "Switching in sudo mode. You may need to provide root password at initial call.."
	SUDO="sudo"
else
	SUDO=""
fi
# send enter and skip -t as it messes up when called from perl ui
if ( (! echo "$@" | grep -q "\-U") || (! echo "$@" | grep -q "\-P") && echo "$@" | grep -q "\-s") ; then echo "when using socket -s provide backup admin user and pwd via -U -P see --help" ; fi
echo -e "\n" | $SUDO docker exec -i kopano4s  kopano-backup "$@"
if (! echo "$@" | grep -q "\-\-restore" && !  echo "$@" | grep -q "\-h" )
then
	# get the K_SHARE to list directories in backup folder which are linked to users
	. /var/packages/Kopano4s/etc/package.cfg
	echo "per user kopano created in backup share (container: /var/lib/kopano/backup):"
	find $K_SHARE/backup/ -maxdepth 1 -mindepth 1 -type d -exec basename {} \;
fi