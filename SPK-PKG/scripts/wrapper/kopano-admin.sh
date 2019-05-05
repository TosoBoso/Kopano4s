#!/bin/sh
# (c) 2018 vbettag - wraper script for kopano-admin in Docker container
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
echo -e "\n" | $SUDO docker exec -i kopano4s kopano-admin "$@"
# for create user ensure the store is created as latest versions do not create it leading to orphaned issue
if [ $# -gt 1 ] && [ "$1" == "-c" ]
then
	KUSER=$2
	if echo -e "\n" | $SUDO docker exec -i kopano4s kopano-admin --list-orphans | grep -q $KUSER
	then
		# get common and config
		. /var/packages/Kopano4s/scripts/common
		. "$ETC_PATH"/package.cfg
		echo -e "\n" | $SUDO docker exec -i kopano4s kopano-admin --create-store $KUSER --lang $LOCALE
	fi
fi
