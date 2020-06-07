#!/bin/sh
# script to compoe the docker containers which is also part of the synology spk tool-chain
#set -euo pipefail
LOGIN=$(whoami)
if [ "$LOGIN" != "root" ]
then
	echo "Switching in sudo mode. You may need to provide root password at initial call.."
	SUDO="sudo"
else
	SUDO=""
fi
echo "still in docker run mode.."
IMG_WMEET="tosoboso/kopano4s:C-Webmeetings-0.29.5"

if !($SUDO docker ps -a | grep -q k4s-webmeet)
then
	$SUDO docker run -d --init --name k4s-webmeet --hostname webmeet --restart=on-failure:3 \
					-p 8090:8090 -p 1935:1935 \
					-v /etc/kopano:/etc/kopano \
					-v /etc/secrets:/etc/secrets \
					-v /var/log/kopano:/var/log/kopano \
					-e K_UID=1033 \
					-e K_GID=65538 \
					-e WEBMEETINGS_CFG_sharedsecret_secret_FILE=/etc/secrets/WEBMEETINGS_SHAREDSECRET \
					-e WEBMEETINGS_CFG_sessionSecret_FILE=/etc/secrets/WEBMEETINGS_SESSIONSECRET \
					-e WEBMEETINGS_CFG_encryptionSecret_FILE=/etc/secrets/WEBMEETINGS_ENCRYPTIONSECRET \
					-e PRESENCE_CFG_server_secret_key_FILE=/etc/secrets/PRESENCE_SHAREDSECRET \
					-e SPREEDWEBRTC_CFGPHP_PLUGIN_SPREEDWEBRTC_PRESENCE_SHARED_SECRET_FILE=/etc/secrets/PRESENCE_SHAREDSECRET \
					-e SPREEDWEBRTC_CFGPHP_PLUGIN_SPREEDWEBRTC_WEBMEETINGS_SHARED_SECRET_FILE=/etc/secrets/WEBMEETINGS_SHAREDSECRET \
					-e SPREEDWEBRTC_CFGPHP_PLUGIN_SPREEDWEBRTC_TURN_AUTHENTICATION_URL="" \
					-e SPREEDWEBRTC_CFGPHP_PLUGIN_SPREEDWEBRTC_TURN_USE_KOPANO_SERVICE=false \
					-e SPREEDWEBRTC_CFGPHP_PLUGIN_SPREEDWEBRTC_USER_DEFAULT_ENABLE=true \
					-e SPREEDWEBRTC_CFGPHP_PLUGIN_SPREEDWEBRTC_AUTO_START=true \
					-e SPREEDWEBRTC_CFGPHP_PLUGIN_SPREEDWEBRTC_REQUIRE_AUTHENTICATION=true \
					$IMG_WMEET
#					-e CORE_SERVICE=dummy \
#					-e DEBUG=1 \
# secreats via SECRET=$(xxd -ps -l 32 -c 32 /dev/random)
fi
if !($SUDO docker ps | grep -q k4s-webmeet)
then
	echo "starting webmeetings container"
	$SUDO docker start k4s-webmeet
fi
$SUDO docker exec -it k4s-webmeet bash