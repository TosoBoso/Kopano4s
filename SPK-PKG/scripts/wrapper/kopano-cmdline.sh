#!/bin/sh
# (c) 2015-19 vbettag - wraper script for kopano-cmdline in Docker or Debian-Chroot container
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
$SUDO docker exec -it kopano4s bash
