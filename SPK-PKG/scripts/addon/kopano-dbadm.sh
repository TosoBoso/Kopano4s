#!/bin/sh
# (c) 2018-19 vbettag - wraper script for kopano-dmadm in Docker container
# admins and docker members only otherwise set sudo for DSM 6 as root login is no longer possible
LOGIN=$(whoami)
if [ $LOGIN != "root" ] && ! (grep administrators /etc/group | grep -q "$LOGIN")
then 
	echo "admins only"
	exit 1
fi
if [ "$LOGIN" != "root" ] && ! (grep docker /etc/group | grep -q "$LOGIN")
then
	echo "switching in sudo mode for ${LOGIN} as you are not in docker group. You may need to provide root password initially and post timeout.."
	SUDO="sudo"
else
	SUDO=""
fi
. /var/packages/Kopano4s/etc/package.cfg
if [ "$K_EDITION" = "Migration" ]
then
	echo "kopano-dbadm does not exist in migration edition 8.4.5 (only later 8.6+)"
	exit 1
fi
echo "Common repair post Zarafa upgrade is: option k-1216 (names table unexpected rows / duplicates)"
echo "Other options: np-defrag, np-remove-highid, np-remove-unused, np-remove-xh, np-repair-dups, np-stat, index-tags, rm-helper-index"
# send enter and skip -t as it messes up when called from perl ui plus collect stderror on stdout
echo -e "\n" | $SUDO docker exec -i kopano4s kopano-dbadm "$@" 2>&1
