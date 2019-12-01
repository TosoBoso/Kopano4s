#!/bin/sh
# (c) 2018-19 vbettag - wraper script for kopano-admin in Docker container
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
# send enter and skip -t as it messes up when called from perl ui plus collect stderror on stdout
echo -e "\n" | $SUDO docker exec -i kopano4s kopano-admin "$@" 2>&1
# for create user ensure the store is created as latest versions do not create it leading to orphaned issue
if [ $# -gt 1 ] && [ "$1" = "-c" ]
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
