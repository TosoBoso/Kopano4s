#!/bin/sh
# script to build the docker images which is also part of the spk tool-chain
#set -euo pipefail
#EDITION="Community"
EDITION="Supported"
#EDITION="Default"
#EDITION="Migration"
BUILD_PARAMS="--build-arg PHP_VERSION=7.0"
LOGIN=$(whoami)
if [ "$LOGIN" != "root" ]
then
	echo "Switching in sudo mode. You may need to provide root password at initial call.."
	SUDO="sudo"
else
	SUDO=""
fi
if [ "$EDITION" != "Community" ] && [ -z "$K_SNR" ]
then
	read -p "Pleae provide Kopano subscription Serial-Nr: " K_SNR
fi
echo "building kopano4s docker image you need to provide sudo pwd at initial start.."
MYDIR=$(dirname "$0")
if [ -z "$DOCKER_PATH" ]
then
	if [ -n $(command -v synoshare) ] ; then DOCKER_PATH="$($SUDO synoshare --get docker | grep $'\t Path' | sed 's/.*\[\(.*\)].*/\1/')" ; fi
fi
if [ -z "$DOCKER_HOST" ]
then
	DOCKER_HOST=$(ip address show docker0 | grep inet | awk '{print $2}' | cut -f1 -d/ | head -n 1)
fi
"$SUDO" mkdir -p "$DOCKER_PATH/kopano4s"
"$SUDO" mkdir -p "$DOCKER_PATH/kopano4s/container"
# copy over dockerfile and cfg for packages to remove post build, then conatiner init, robot.png 
"$SUDO" cp -f "$MYDIR"/SPK-PKG/scripts/container/Dockerfile "$DOCKER_PATH/kopano4s"
"$SUDO" cp -f "$MYDIR"/SPK-PKG/scripts/container/* "$DOCKER_PATH/kopano4s/container"
"$SUDO" cp -f "$MYDIR"/SPK-APP/merge/kopano-cfg.tgz "$DOCKER_PATH/kopano4s/container"
"$SUDO" cp -f "$MYDIR"/SPK-APP/merge/kinit.tgz "$DOCKER_PATH/kopano4s/container"
"$SUDO" cp -f "$MYDIR"/SPK-APP/ui/images/robot.png "$DOCKER_PATH/kopano4s/container"

echo "Calling kopano4s Dockerfile build at $(date "+%Y%m%d-%H:%M:%S").."
GET_K_DOWNLOAD_RELEASE_TAG()
{
	local URL="$1"
	local TAG="[[:graph:]]*${2}[[:graph:]]*"
	# get basename from download URL for tag (e.g. Debian_9) which is recognized in between double-brackets
	local DOWNL_FILE=$(basename $(curl --silent "$URL" | grep -o "$TAG" | head -1 | cut -f2 -d \"))
	if [ -n "$DOWNL_FILE" ]
	then
		# based on download file split off as major release only the 1st 3 secions on . delimiter
		local MAJ_REL=$(echo "$DOWNL_FILE" | grep -o "$TAG" | grep -o "[0-9.]*" | head -1 | cut -f1-3 -d .)
		echo "$MAJ_REL"
	else
		echo ""
	fi
}
if [ "$EDITION" = "Community" ]
then
	TAG1=$( GET_K_DOWNLOAD_RELEASE_TAG "https://download.kopano.io/community/core:/" "Debian_9.0" )
	if [ -z "$TAG1" ]
	then
		echo "Could not evaluate Kopano core release tag from download; exiting.."
		exit 1
	fi
	TAG2=$( GET_K_DOWNLOAD_RELEASE_TAG "https://download.kopano.io/community/webapp:/" "Debian_9.0" )
	if [ -z "$TAG2" ]
	then
		echo "Could not evaluate Kopano webapp release tag from download; exiting.."
		exit 1
	fi
	TAG3=$( GET_K_DOWNLOAD_RELEASE_TAG "http://repo.z-hub.io/z-push:/final/Debian_9.0/all/" "z-push-kopano_" )
	if [ -z "$TAG3" ]
	then
		echo "Could not evaluate Kopano z-push release tag from download; exiting.."
		exit 1
	fi
	TAG4=$( GET_K_DOWNLOAD_RELEASE_TAG "https://download.kopano.io/community/webmeetings:/" "Debian_9.0" )
	if [ -z "$TAG4" ]
	then
		echo "Could not evaluate Kopano webmeetings release tag from download; exiting.."
		exit 1
	fi	
	IMG_TAG="Core-${TAG1}_Webapp-${TAG2}_Z-Push-${TAG3}_WMeet-${TAG4}"
	VER_TAG="C-${IMG_TAG}"
	BUILD_PARAMS="$BUILD_PARAMS --build-arg COMMUNITY_BUILD=1"
fi
if [ "$EDITION" = "Supported" ]
then
	TAG1=$( GET_K_DOWNLOAD_RELEASE_TAG "https://serial:${K_SNR}@download.kopano.io/supported/core:/final/tarballs/" "Debian_9.0" )
	if [ -z "$TAG1" ]
	then
		echo "Could not evaluate Kopano core release tag from download; exiting.."
		exit 1
	fi
	TAG2=$( GET_K_DOWNLOAD_RELEASE_TAG "https://serial:${K_SNR}@download.kopano.io/supported/webapp:/final/tarballs/" "Debian_9.0" )
	if [ -z "$TAG2" ]
	then
		echo "Could not evaluate Kopano webapp release tag from download; exiting.."
		exit 1
	fi
	TAG3=$( GET_K_DOWNLOAD_RELEASE_TAG "http://repo.z-hub.io/z-push:/final/Debian_9.0/all/" "z-push-kopano_" )
	if [ -z "$TAG3" ]
	then
		echo "Could not evaluate Kopano z-push release tag from download; exiting.."
		exit 1
	fi
	TAG4=$( GET_K_DOWNLOAD_RELEASE_TAG "https://serial:${K_SNR}@download.kopano.io/supported/webmeetings:/final/tarballs/" "Debian_9.0" )
	if [ -z "$TAG4" ]
	then
		echo "Could not evaluate Kopano webmeetings release tag from download; exiting.."
		exit 1
	fi	
	IMG_TAG="Core-${TAG1}_Webapp-${TAG2}_Z-Push-${TAG3}_WMeet-${TAG4}"
	VER_TAG="S-${IMG_TAG}"
	# passing SNR for download via arg http_proxy not found in docker history.
	BUILD_PARAMS="$BUILD_PARAMS --build-arg SUPPORTED_BUILD=1 --build-arg K_SNR=${K_SNR}"
fi
if [ "$EDITION" = "Default" ]
then
	IMG_TAG="8.6.9.0_Web-3.5.0_Push-2.4.5"
	VER_TAG="D-${IMG_TAG}"
	BUILD_PARAMS="$BUILD_PARAMS --build-arg DEFAULT_BUILD=1 --build-arg K_SNR=${K_SNR}"
fi
if [ "$EDITION" = "Migration" ]
then
	IMG_TAG="8.4.5.0_Web-3.4.2_Push-2.4.5"
	VER_TAG="M-${IMG_TAG}"
	BUILD_PARAMS="$BUILD_PARAMS --build-arg MIGRATION_BUILD=1 --build-arg K_SNR=${K_SNR}"
fi
DATE_BUILD=$(date "+%Y-%m-%d")
if [ $# -eq 1 ] && [ "$1" = "get-repo" ]
then
	# get the repo from intermediate image aka stop at the stage and copy from container
	BUILD_PARAMS="$BUILD_PARAMS --target k4s-repo-intermediate --tag tosoboso/k4s-repo:${VER_TAG}"
else
	BUILD_PARAMS="$BUILD_PARAMS --build-arg DATE_BUILD=${DATE_BUILD} --build-arg IMG_TAG=${IMG_TAG} --tag tosoboso/kopano4s:${VER_TAG}"
fi
# remove old image if exists
if $SUDO docker images | grep -q "$VER_TAG"
then
	"$SUDO" docker rmi tosoboso/kopano4s:"$VER_TAG"
fi
if ( [ $# -eq 1 ] && [ "$1" = "clean" ] ) || ( [ $# -eq 2 ] && [ "$2" = "clean" ] )
then
	# deleting all containers with status exit if no exists error is ok
	"$SUDO" docker rm -v $($SUDO docker ps -a -q -f status=exited)
	# deleting all images with status dangling - if no exists error is ok
	"$SUDO" docker rmi $($SUDO docker images -f "dangling=true" -q)
	# searching and deleting images with none as name
	LIST=`$SUDO docker images | grep none | grep -o [0-f][0-f][0-f][0-f][0-f][0-f][0-f][0-f][0-f][0-f][0-f][0-f]`
	for L in $LIST ; do "$SUDO" docker rmi -f $L ; done
	BUILD_PARAMS="$BUILD_PARAMS --no-cache"
fi
echo "Build-Args: ${BUILD_PARAMS}"
"$SUDO" docker build ${DOCKER_PATH}/kopano4s ${BUILD_PARAMS}

# if we created image with repo copy it over to place it on a webserver e.g. for wget $PARENT/repo/k4s-${EDITION}-repo.tgz
if [ $# -eq 1 ] && [ "$1" = "get-repo" ]
then
	$SUDO docker create -ti --name k4s-repo tosoboso/k4s-repo:${VER_TAG} bash
	$SUDO docker cp k4s-repo:/root/k4s-${EDITION}-repo.tgz .
	$SUDO docker rm -fv k4s-repo
	echo "collected k4s-repo with deb files:"
	ls -al k4s-*repo*
fi
