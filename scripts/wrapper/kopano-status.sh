#!/bin/sh
# (c) 2018 vbettag - wraper script for kopano-status in Docker container
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
echo -e "\n" | $SUDO docker exec -i kopano4s init.sh status
