#!/bin/sh
# script to build the docker images which is also part of the synology spk tool-chain
#set -euo pipefail
LOGIN=$(whoami)
if [ "$LOGIN" != "root" ]
then
	echo "Switching in sudo mode. You may need to provide root password at initial call.."
	SUDO="sudo"
else
	SUDO=""
fi
if [ -z "$K_EDITION" ]
then
	read -p "Pleae provide Kopano K_EDITION to build (Community) : " K_EDITION
	if [ -z "$K_EDITION" ] ; then K_EDITION="Community" ; fi
fi
BUILD_PARAMS="--build-arg EDITION=${K_EDITION} --build-arg PHP_VER=7.0"
if [ "$K_EDITION" != "Community" ] && [ -z "$K_SNR" ]
then
	read -p "Pleae provide Kopano subscription Serial-Nr: " K_SNR
fi
echo "Building image for kopano 4s $K_EDITION you need to provide sudo pwd at initial start.."
MYDIR=$(dirname "$0")
if [ -z "$DOCKER_PATH" ]
then
	if [ -n $(command -v synoshare) ] ; then DOCKER_PATH="$($SUDO synoshare --get docker | grep $'\t Path' | sed 's/.*\[\(.*\)].*/\1/')" ; fi
fi
if [ -z "$DOCKER_HOST" ]
then
	DOCKER_HOST=$(ip address show docker0 | grep inet | awk '{print $2}' | cut -f1 -d/ | head -n 1)
fi
"$SUDO" mkdir -p "$DOCKER_PATH"/kopano4s
"$SUDO" mkdir -p "$DOCKER_PATH"/kopano4s/container
# copy over dockerfile and cfg for packages to remove post build, then conatiner init, robot.png 
"$SUDO" cp -f "$MYDIR"/SPK-PKG/scripts/container/Dockerfile "$DOCKER_PATH/kopano4s"
"$SUDO" cp -f "$MYDIR"/SPK-PKG/scripts/container/*.sh "$DOCKER_PATH/kopano4s/container"
"$SUDO" cp -f "$MYDIR"/SPK-PKG/scripts/container/dpkg-remove "$DOCKER_PATH/kopano4s/container"
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
if [ "$K_EDITION" = "Community" ]
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
if [ "$K_EDITION" = "Supported" ]
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
if [ "$K_EDITION" = "Default" ]
then
	#TAG1="8.6.9.0"
	#TAG2="3.5.0"
	TAG1="8.7.1.0"
	TAG2="3.5.6"
	TAG3=$( GET_K_DOWNLOAD_RELEASE_TAG "http://repo.z-hub.io/z-push:/final/Debian_9.0/all/" "z-push-kopano_" )
	if [ -z "$TAG3" ]
	then
		echo "Could not evaluate Kopano z-push release tag from download; exiting.."
		exit 1
	fi
	TAG4="0.29.5"
	IMG_TAG="Core-${TAG1}_Webapp-${TAG2}_Z-Push-${TAG3}_WMeet-${TAG4}"
	VER_TAG="D-${IMG_TAG}"
	BUILD_PARAMS="$BUILD_PARAMS --build-arg DEFAULT_BUILD=1 --build-arg K_SNR=${K_SNR}"
fi
if [ "$K_EDITION" = "Migration" ]
then
	IMG_TAG="Core-8.4.5.0_Webapp-3.4.2_Z-Push-2.4.5"
	VER_TAG="M-${IMG_TAG}"
	BUILD_PARAMS="$BUILD_PARAMS --build-arg MIGRATION_BUILD=1 --build-arg K_SNR=${K_SNR}"
fi
DATE_BUILD=$(date "+%Y-%m-%d")
# in get repo mode only run the k4s-intermediate build and extract repo from container
if [ $# -gt 0 ] && [ "$1" = "get-repo" ]
then
	# get the repo from intermediate image aka stop at the stage and copy from container
	BUILD_PARAMS="$BUILD_PARAMS --target k4s-intermediate --tag tosoboso/k4s-repo:${VER_TAG}"
else
	BUILD_PARAMS="$BUILD_PARAMS --build-arg PARENT=${DOCKER_HOST} --build-arg BUILD=${DATE_BUILD} --build-arg TAG=${IMG_TAG} --tag tosoboso/kopano4s:${VER_TAG}"
fi
# in use repo mode only run the k4-main build and use extracted repo from local webserver
if [ $# -gt 0 ] && [ "$1" = "web-repo" ]
then
	WEBREPO=${DOCKER_HOST}/repo
	echo "Building from web-repo $WEBREPO assuming you did run get-repo before and put the artifacts to this location.."
	# in Dockerfile we comment of the copy from interactive which is skipped anyway via target k4s-main
	#sed -i -e 's~^COPY --from=k4s-intermediate~#COPY --from=k4s-intermediate'~  "$DOCKER_PATH"/kopano4s/Dockerfile
	BUILD_PARAMS="$BUILD_PARAMS --build-arg ENV_BUILD=web-repo --build-arg WEBREPO=${WEBREPO}"
fi

# remove old image if exists
if $SUDO docker images | grep -q "$VER_TAG"
then
	"$SUDO" docker rmi tosoboso/kopano4s:"$VER_TAG"
fi
if ( [ $# -gt 0 ] && [ "$1" = "clean" ] ) || ( [ $# -eq 2 ] && [ "$2" = "clean" ] )
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

# if we created image with repo copy it over to place it on a webserver e.g. for wget $PARENT/repo/k4s-${K_EDITION}-repo.tgz
if [ $# -gt 0 ] && [ "$1" = "get-repo" ]
then
	"$SUDO" docker create -ti --name k4s-repo tosoboso/k4s-repo:${VER_TAG} bash
	"$SUDO" docker cp k4s-repo:/root/k4s-${K_EDITION}-repo.tgz .
	"$SUDO" docker rm -fv k4s-repo
	echo "collected k4s-repo with deb files:"
	ls -al k4s-*repo*
fi
