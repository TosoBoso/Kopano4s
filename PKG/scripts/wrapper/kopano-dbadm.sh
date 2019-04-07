#!/bin/sh
# (c) 2018 vbettag - wraper script for kopano-dmadm in Docker container
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
. /var/packages/Kopano4s/etc/package.cfg
if [ "$K_EDITION" == "Migration" ]
then
	echo "kopano-dbadm does not exist in migration edition 8.4.5 (only later 8.6+)"
	exit 1
fi
echo "Common repair post Zarafa upgrade is: option k-1216 (names table unexpected rows / duplicates)"
echo "Other options: np-defrag, np-remove-highid, np-remove-unused, np-remove-xh, np-repair-dups, np-stat, index-tags, rm-helper-index"
echo -e "\n" | $SUDO docker exec -i kopano4s kopano-dbadm "$@"
