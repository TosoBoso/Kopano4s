#!/bin/sh
# (c) 2018 vbettag - wraper script for kopano-init in Docker container
# admins only plus set sudo for DSM 6 as root login is no longer possible
LOGIN=$(whoami)
if [ "$LOGIN" != "root" ]
then 
	echo "you have to run as root! alternatively as admin run with sudo prefix! exiting.."
	exit 1
fi
# ** get library and common procedures, settings, tags and download urls
. /var/packages/Kopano4s/scripts/library
. /var/packages/Kopano4s/scripts/common
. /var/packages/Kopano4s/etc/package.cfg

CONT="OFF"
ETC="OFF"
ACL="OFF"
GZL="OFF"
SSL="OFF"
MOB="OFF"
UPG="OFF"
SRV="ON"
PORT="ON"
IMG="OFF"
DNW="bridge"

case "$1" in
	reset)
		echo "reset: initializing container from existing image in NW mode $DNW.."
		CONT="ON"
		;;
	refresh)
		echo "refresh: initializing container from fresh image loaded at docker hub.."
		CONT="ON"
		IMG="ON"
		;;
	defresh)
		echo "defresh: initializing container from previous image loaded at docker hub.."
		CONT="ON"
		IMG="ON"
		PREV="ON"
		;;
	maintenance)
		echo "maintenance mode: initializing container with no running services; reset later to resume.."
		CONT="ON"
		SRV="OFF"
		;;	
	no-ports)
		echo "initializing container with no exposed ports; reset later to resume.."
		CONT="ON"
		PORT="OFF"
		;;
	edition)
		if [ $# -lt 2 ]
		then
			echo "Please provide Edition to swith to (Default/Supported/Community) as 2nd parameter"
			exit 1
		fi
		if [ "$K_EDITION" = "Migration" ]
		then
			# can no longer swith in one go from migration to otehr editions, too many database upgrades
			echo "cannot switch from Migration Edition (too many database upgrade steps). Run kopano4s-upgrade instead"
			exit 1
		fi
		if ([ "$K_EDITION" = "Supported" ] || [ "$K_EDITION" = "Community" ]) && [ $# -gt 1 ] && [ "$2" = "Default" ]
		then
			echo "cannot switch from Community or Supported to Default Edtion. Run kopano4s-downgrade instead"
			exit 1		
		fi
		if [ "$K_EDITION" = "Community" ] && [ $# -gt 1 ] && [ "$2" = "Supported" ]
		then
			echo "cannot switch from Community to Default Edtion. Run kopano4s-downgrade instead"
			exit 1		
		fi
		# shellcheck disable=SC2235
		if [ $# -gt 1 ] && ( [ "$2" = "Community" ] || [ "$2" = "Supported" ] )
		then
			if [ $# -lt 3 ] && [ "$2" = "Supported" ]
			then
				echo "Please provide SNR as 3rd parameter for Supported edition"
				exit 1
			fi
			K_EDITION="$2"
			if [ $# -gt 2 ] && [ "$K_EDITION" = "Supported" ]
			then
				K_SNR=$3
				DOWNLOAD_SOURCE="https://serial:${K_SNR}@${K_URL_SUP}/core:/"
				if [ "$K_EDITION" = "Supported" ] && CHECK_DOWNLOAD_SOURCE $DOWNLOAD_SOURCE
				then
					sed -i -e "s~K_SNR.*~K_SNR=\"$K_SNR\""~ $ETC_PATH/package.cfg
					mkdir -p $ETC_PATH/kopano/license
					touch $ETC_PATH/kopano/license/base
					chmod 666 $ETC_PATH/kopano/license/base
					echo -e $K_SNR > $ETC_PATH/kopano/license/base
					chmod 640 $ETC_PATH/kopano/license/base
				else
					echo "SNR could not be validated at Kopano download area ($K_SNR)"
					exit 1
				fi
			fi
		fi
		GET_VER_TAG
		echo "switching edition to $VER_TAG and initializing container "
		sed -i -e "s~K_EDITION=.*~K_EDITION=\"$K_EDITION\""~ $ETC_PATH/package.cfg
		SET_SVR_CFG_NEW
		CONT="ON"
		IMG="ON"
		;;
	etc)
		echo "initializing kopano4s etc from last backup during install or upgrade"
		ETC="ON"
		ACL="ON"
		;;
	acl)
		echo "initializing acls of all kopano folders incl. etc, log"
		ACL="ON"
		;;
	gzlogs)
		echo "initializing / deleting rotated gz logs of all kopano folders"
		GZL="ON"
		;;
	ssl)
		echo "initializing ssl by copy over latest certificates from synology"
		SSL="ON"
		;;
	mobiles)
		echo "initializing mobiles sync status by purging z-push state"
		MOB="ON"
		;;
	upgrade)
		echo "upgrading sw in container via debian apt-get upgrade"
		MOB="ON"
		;;
	all)
		echo "initializing all: container, etc from last backup during install or upgrade, acls and mobiles sysnc status"
		CONT="ON"
		ETC="ON"
		ACL="ON"
		SSL="ON"
		MOB="ON"
		;;
	help)
		echo "Usage: kopano-init plus reset (bridge|host) | refresh | defresh | edition | maintenance | no-ports | etc | acl | ssl | mobiles | upgrade | all | help"
		echo "Reset re-builds container from local k4s image, optionally in host nw mode; refresh loads latest and defresh previous image from docker hub."
		echo "Maintenance builds container with no kopano services running but staying up to allow repairs with kopano-dbadm etc.."
		echo "No-ports builds container with no ports exposed for migration scenario to connect to zarafa tcp 236/7 on same synology."
		echo "For both, maintenance and no-ports it is essential to run reset building std. container for resuming default operations."
		echo "Edition lets you switch from Migration to Community or Supported. The latter requires a valid Serial-Nr. Switch from Supported"
		echo "to Community is a downgrade so instead use kopano-backup then remove Supported dropping database leaving share and run restore."
		echo "Option etc copies cfg from backup area; acl resets the access control lists in etc, attachments, z-push.. and gzlogs removes old logs."
		echo "Option upgrade will run Debian apt-get upgrade in container (usually container refresh will do the trick)."
		exit 0
		;;
	*)
		echo "Usage: kopano-init plus reset (bridge|host) | refresh | defresh | edition | maintenance | no-ports | etc | acl | gzlogs | ssl | mobiles | upgrade | all | help"
		exit 1
		;;
esac

if [ $# -gt 1 ] && [ $2 = "host" ]
then
	DNW="host"
fi
if [ "$DOCKER_NW" != "$DNW" ]
then
	# set docker_network as parameter changed
	sed -i -e "s~DOCKER_NW=.*~DOCKER_NW=\"${DNW}\"~" /var/packages/Kopano4s/etc/package.cfg
	DOCKER_NW="$DNW"
fi
if [ "$MOB" = "ON" ]
then
	# remove legacy z-push incl. state in kopano-etc and backup area
	if [ -e $K_SHARE/backup/etc/kopano/z-push ] ; then rm -R $K_SHARE/backup/etc/kopano/z-push ; fi
	if [ -e /etc/kopano/z-push ] && [ -h /etc/kopano/z-push ] ; then rm /etc/kopano/z-push ; fi
	if [ -e /etc/kopano/z-push ] && [ ! -h /etc/kopano/z-push ] ; then rm -R /etc/kopano/z-push ; fi
	# delete files and all subdirectories of z-push aka mindepth 1
	SDIR=$(find $K_SHARE/z-push -mindepth 1 -maxdepth 1 -type d -exec basename "{}" ";")
	for S in $SDIR ; do rm -R $K_SHARE/z-push/$S ; done 
	find $K_SHARE/z-push -type f -exec rm "{}" ";"
	if [ "$ACL" = "OFF" ]
	then
		chown -R http.http $K_SHARE/z-push
		chmod 770 $K_SHARE/z-push
	fi
fi
if [ "$SSL" = "ON" ]
then
	SET_K_CERTIFICATE
	if [ "$ACL" = "OFF" ]
	then
		chown -R root.kopano /etc/kopano/ssl
		chmod 751 /etc/kopano/ssl
	fi
	if [ "$CONT" = "OFF" ]
	then
		echo -e "\n" | docker exec -i kopano4s init.sh ssl
		echo -e "\n" | docker exec -i kopano4s init.sh restart
	fi
fi
if [ "$ETC" = "ON" ]
then
	cp -R -f $K_SHARE/backup/etc/kopano $ETC_PATH
fi
if [ "$ACL" = "ON" ]
then
	INIT_SYNOACL
	if [ "$CONT" = "OFF" ]
	then
		echo -e "\n" | docker exec -i kopano4s init.sh acl
		echo -e "\n" | docker exec -i kopano4s init.sh restart
	fi
fi
if [ "$GZL" = "ON" ]
then
	echo "removing old gz logs from logrotate.."
	for gzf in /var/log/kopano/*.gz ; do rm $gzf ; done
	for gzf in /var/log/kopano/*.1 ; do rm $gzf ; done
fi
if [ "$UPG" = "ON" ]
then
	if [ "$CONT" = "OFF" ]
	then
		echo -e "\n" | docker exec -i kopano4s init.sh upgrade
		echo -e "\n" | docker exec -i kopano4s init.sh restart
	fi
fi
if [ "$CONT" = "ON" ]
then
		# remove and rebuild the docker container
		FRESH=""
		if [ "$IMG" = "ON" ]
		then
			FRESH="refreshed "
			if [ "$PREV" = "ON" ]
			then
				GET_VER_TAG	previous
			else
				GET_VER_TAG
			fi
			sed -i -e "s~VER_TAG=.*~VER_TAG=\"$VER_TAG\""~ $ETC_PATH/package.cfg
		fi
		echo "init: remove and build kopano4s docker container from ${FRESH}image.. stop:"
		# send enter and skip -t as it messes up when called from perl ui
		if echo -e "\n" | docker ps | grep -q kopano4s
		then
			echo -e "\n" | docker stop kopano4s
		fi
		if echo -e "\n" | docker ps -a | grep -q kopano4s
		then		
			echo "remove container:"
			echo -e "\n" | docker rm -f kopano4s
		fi
		if [ "$IMG" = "ON" ] && echo -e "\n" | docker images | grep -q tosoboso/kopano4s
		then
			echo "remove image:"
			# shellcheck disable=SC2046
			echo -e "\n" | docker rmi -f $(docker images | awk '$1 ~ /kopano4s/ {print $3}')
		fi
		echo "build $VER_TAG:"
		SET_DOCKER_ENV
		if [ "$PORT" = "OFF" ]
		then
			DOCKER_PORTS=""
		fi
		if [ "$SRV" = "ON" ]
		then
			DOCKER_CMD=""
		else
			DOCKER_CMD="maintenance"
		fi
		#echo "docker run $DOCKER_PARAMS $DOCKER_MOUNTS $DOCKER_PORTS $DOCKER_IMAGE $DOCKER_CMD .."
		if ! ( echo -e "\n" | docker run $DOCKER_PARAMS $DOCKER_MOUNTS $DOCKER_PORTS $DOCKER_IMAGE $DOCKER_CMD ) >/tmp/docker-run.err 2>&1
		then
			DCR_ERR=$(cat /tmp/docker-run.err | tr '\n' '. ')
			MSG="k4s container run failed: $DCR_ERR"
			echo "$MSG"
			if [ "$NOTIFY" = "ON" ]
			then
				/usr/syno/bin/synodsmnotify "$NOTIFYTARGET" Kopano4s "$MSG"
			fi
			rm /tmp/docker-run.err
			exit 1
		fi
		rm /tmp/docker-run.err
		# init phase docker post build
		INIT_DOCKER
		WAIT=20
		if [ $# -gt 1 ] && [ "$2" = "nowait" ] ; then WAIT=1 ; fi
		echo "waiting for services to restart: ${WAIT}ss.."
		sleep $WAIT
		echo -e "\n" | docker exec -i kopano4s init.sh status
fi
