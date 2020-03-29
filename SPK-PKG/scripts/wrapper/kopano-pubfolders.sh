#!/bin/sh
# (c) 2018-19 vbettag - wraper script for z-push listfolders.php to user SYSTEM in Docker container
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
echo "Running listfolders.php -l SYSTEM. If store does not exist create is with kopano-admin -s."
echo "If no 'Public Contacts' exists create folder via kopano-webapp in section public folders."
echo -e "\n" | $SUDO docker exec -i kopano4s /usr/share/z-push/backend/kopano/listfolders.php -l SYSTEM 2>&1
