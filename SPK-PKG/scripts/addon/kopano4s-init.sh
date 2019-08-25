#!/bin/sh
# (c) 2018 vbettag - wraper script for kopano-init in Docker container
# admins only plus set sudo for DSM 6 as root login is no longer possible
LOGIN=$(whoami)
if [ "$LOGIN" != "root" ] && ! (grep administrators /etc/group | grep -q "$LOGIN")
then 
	echo "admins only"
	exit 1
fi
if [ "$LOGIN" != "root" ]
then
	echo "Switching in sudo mode. You may need to provide root password at initial call.."
	SUDO="sudo"
else
	SUDO=""
fi
# get common and config
. /var/packages/Kopano4s/scripts/common
. "$ETC_PATH"/package.cfg

CONT="OFF"
ETC="OFF"
ACL="OFF"
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
		if [ $# -gt 1 ] && ( [ "$2" == "Community" ] || [ "$2" == "Supported" ] )
		then
			if [ "$K_EDITION" == "Community" ] && [ "$2" == "Supported" ]
			then
				echo "cannot switch from Community to Supported. Run kopano4s-downgrade instead"
				exit 1
			fi
			K_EDITION="$2"
			if [ $# -gt 2 ] && [ "$K_EDITION" == "Supported" ]
			then
				K_SNR=$3
				DOWNLOAD_SOURCE="https://serial:${K_SNR}@${K_URL_SUP}/core:/"
				if [ "$K_EDITION" == "Supported" ] && CHECK_DOWNLOAD_SOURCE $DOWNLOAD_SOURCE
				then
					$SUDO sed -i -e "s~K_SNR.*~K_SNR=\"$K_SNR\""~ $ETC_PATH/package.cfg
					$SUDO mkdir -p $ETC_PATH/kopano/license
					$SUDO touch $ETC_PATH/kopano/license/base
					$SUDO chmod 666 $ETC_PATH/kopano/license/base
					echo -e $K_SNR > $ETC_PATH/kopano/license/base
					$SUDO chmod 640 $ETC_PATH/kopano/license/base
				else
					echo "SNR could not be validated at Kopano download area ($K_SNR)"
					exit 1
				fi
			fi
			if [ $# -lt 2 ] && [ "$K_EDITION" == "Supported" ]
			then
				echo "Please provide SNR as 3rd parameter for Supported edition"
				exit 1
			fi
			GET_VER_TAG
			echo "switching edition to $VER_TAG and initializing container "
			$SUDO sed -i -e "s~K_EDITION=.*~K_EDITION=\"$K_EDITION\""~ $ETC_PATH/package.cfg
			SET_SVR_CFG_NEW
			CONT="ON"
			IMG="ON"
		else
			echo "Please provide valid edition to swith to: Community/Supported (for Default us kopano4s-downgrade)"
			exit 1
		fi
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
		echo "Usage: kopano-init plus reset (bridge|host) | frefresh | defresh | edition | maintenance | no-ports | etc | acl | ssl | mobiles | upgrade | all | help"
		echo "Reset re-builds container from local k4s image, optionally in host nw mode; refresh loads latest and defresh previous image from docker hub."
		echo "Maintenance builds container with no kopano services running but staying up to allow repairs with kopano-dbadm etc.."
		echo "No-ports builds container with no ports exposed for migration scenario to connect to zarafa tcp 236/7 on same synology."
		echo "For both, maintenance and no-ports it is essential to run reset building std. container for resuming default operations."
		echo "Edition lets you switch from Migration to Community or Supported. The latter requires a valid Serial-Nr. Switch from Supported"
		echo "to Community is a downgrade so instead use kopano-backup then remove Supported dropping database leaving share and run restore."
		echo "Option etc copies cfg from backup area; acl resets the access control lists in volumes (etc, attachments, z-push-state..)"
		echo "Option upgrade will run Debian apt-get upgrade in container (usually container refresh will do the trick)."
		exit 0
		;;
	*)
		echo "Usage: kopano-init plus reset (bridge|host) | frefresh | defresh | edition | maintenance | no-ports | etc | acl | ssl | mobiles | upgrade | all | help"
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
	$SUDO sed -i -e "s~DOCKER_NW=.*~DOCKER_NW=\"${DNW}\"~" /var/packages/Kopano4s/etc/package.cfg
	DOCKER_NW="$DNW"
fi
if [ "$MOB" == "ON" ]
then
#find /usr/share/kopano-webapp -type d -exec chmod 750 "{}" ";"
	# remove legacy z-push incl. state in kopano-etc and backup area
	if [ -e $K_SHARE/backup/etc/kopano/z-push ] ; then rm -R $K_SHARE/backup/etc/kopano/z-push ; fi
	if [ -e /etc/kopano/z-push ] && [ -h /etc/kopano/z-push ] ; then $SUDO rm /etc/kopano/z-push ; fi
	if [ -e /etc/kopano/z-push ] && [ ! -h /etc/kopano/z-push ] ; then $SUDO rm -R /etc/kopano/z-push ; fi
	# delete all subdirectories of z-push aka mindepth 1
	SDIR=`find $K_SHARE/z-push -mindepth 1 -maxdepth 1 -type d -exec basename "{}" ";"`
	for S in $SDIR ; do $SUDO rm -R $K_SHARE/z-push/$S ; done 
	find $K_SHARE/z-push -type f -exec $SUDO rm "{}" ";"
	if [ "$ACL" == "OFF" ]
	then
		$SUDO chown -R http.kopano $K_SHARE/z-push
		$SUDO chmod 770 $K_SHARE/z-push
	fi
fi
if [ "$SSL" == "ON" ]
then
	SET_K_CERTIFICATE
	if [ "$ACL" == "OFF" ]
	then
		$SUDO chown -R root.kopano /etc/kopano/ssl
		$SUDO chmod 751 /etc/kopano/ssl
	fi
	if [ "$CONT" == "OFF" ]
	then
		echo -e "\n" | $SUDO docker exec -i kopano4s init.sh ssl
		echo -e "\n" | $SUDO docker exec -i kopano4s init.sh restart
	fi
fi
if [ "$ETC" == "ON" ]
then
	$SUDO cp -R -f $K_SHARE/backup/etc/kopano $ETC_PATH
fi
if [ "$ACL" == "ON" ]
then
	INIT_SYNOACL
	if [ "$CONT" == "OFF" ]
	then
		echo -e "\n" | $SUDO docker exec -i kopano4s init.sh acl
		echo -e "\n" | $SUDO docker exec -i kopano4s init.sh restart
	fi
fi
if [ "$UPG" == "ON" ]
then
	if [ "$CONT" == "OFF" ]
	then
		echo -e "\n" | $SUDO docker exec -i kopano4s init.sh upgrade
		echo -e "\n" | $SUDO docker exec -i kopano4s init.sh restart
	fi
fi
if [ "$CONT" == "ON" ]
then
		# remove and rebuild the docker container
		FRESH=""
		if [ "$IMG" == "ON" ]
		then
			FRESH="refreshed "
			if [ "$PREV" == "ON" ]
			then
				GET_VER_TAG	previous
			else
				GET_VER_TAG
			fi
			$SUDO sed -i -e "s~VER_TAG=.*~VER_TAG=\"$VER_TAG\""~ $ETC_PATH/package.cfg
		fi
		echo "init: remove and build kopano4s docker container from ${FRESH}image.. stop:"
		# send enter and skip -t as it messes up when called from perl ui
		echo -e "\n" | $SUDO docker stop kopano4s
		echo "remove:"
		echo -e "\n" | $SUDO docker rm -f kopano4s
		if [ "$IMG" == "ON" ]
		then
			echo "remove image:"
			echo -e "\n" | $SUDO docker rmi -f `$SUDO docker images | awk '$1 ~ /kopano4s/ {print $3}'`
		fi
		echo "build $VER_TAG:"
		SET_DOCKER_ENV
		if [ "$PORT" == "OFF" ]
		then
			DOCKER_PORTS=""
		fi
		if [ "$SRV" == "ON" ]
		then
			DOCKER_CMD=""
		else
			DOCKER_CMD="maintenance"
		fi
		#echo "docker run $DOCKER_PARAMS $DOCKER_MOUNTS $DOCKER_PORTS $DOCKER_IMAGE $DOCKER_CMD .."
		if ! ( $SUDO docker run $DOCKER_PARAMS $DOCKER_MOUNTS $DOCKER_PORTS $DOCKER_IMAGE $DOCKER_CMD )
		then
			echo "failed to rebuild Kopano"
			exit 1
		fi
		# init phase docker post build
		INIT_DOCKER
		if grep -q ^AMAVISD_ENABLED=yes /etc/kopano/default
		then 
			WAIT=120
		else
			WAIT=60
		fi
		if [ $# -gt 1 ] && [ "$2" == "nowait" ] ; then WAIT=1 ; fi
		echo "waiting for services to restart: ${WAIT}s.."
		sleep $WAIT
		echo -e "\n" | $SUDO docker exec -i kopano4s init.sh status
fi