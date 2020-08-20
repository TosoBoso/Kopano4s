#!/bin/sh
# script to build the docker images which is also part of the synology spk tool-chain
#set -euo pipefail
LOGIN=$(whoami)
if [ $# -eq 0 ]
then
	echo "Usage: build_docker.sh all | core | wmeet | help, get-repo | web-repo, clean."
	exit 1
fi
if [ $# -gt 0 ] && [ "$1" = "help" ]
then
	echo "Usage: build_docker.sh all | core | wmeet | help, get-repo | web-repo, clean."
	echo "1st parameter defines what to build (all, core, wmeet); 2nd if to get the repo or work from web-repo; 3rd to clean cache."
	echo "Web-repo has to be created by get-repo first and then copied to /repo in web-server. This option saves time and image space."
	exit 0
fi
if [ "$LOGIN" != "root" ]
then
	echo "Switching in sudo mode. You may need to provide root password at initial call.."
	SUDO="sudo"
else
	SUDO=""
fi
B_CORE=0
B_WMEET=0
if [ $# -gt 0 ] && [ "$1" = "all" ]
then
	B_CORE=1
	B_WMEET=1
fi
if [ $# -gt 0 ] && [ "$1" = "core" ]
then
	B_CORE=1
fi
if [ $# -gt 0 ] && [ "$1" = "webmeet" ]
then
	B_WMEET=1
fi

if [ -z "$K_EDITION" ]
then
	read -p "Pleae provide Kopano K_EDITION to build (Community) : " K_EDITION
	if [ -z "$K_EDITION" ] ; then K_EDITION="Community" ; fi
fi
BUILD_PARAMS="--build-arg EDITION=${K_EDITION}"

if [ "$K_EDITION" = "Migration" ]
# old migration running on stretch with php-7.0
then
	BUILD_PARAMS="$BUILD_PARAMS --build-arg DEBIAN_VER=stretch --build-arg PHP_VER=7.0"
# debian buster with php-7.3
else
	BUILD_PARAMS="$BUILD_PARAMS --build-arg DEBIAN_VER=buster --build-arg PHP_VER=7.3"	
fi

if [ "$K_EDITION" != "Community" ] && [ -z "$K_SNR" ]
then
	read -p "Pleae provide Kopano subscription Serial-Nr: " K_SNR
fi
echo "Building image for kopano4s $K_EDITION you need to provide sudo pwd at initial start.."
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
"$SUDO" cp -f "$MYDIR"/SPK-PKG/scripts/container/Dockerfile* "$DOCKER_PATH/kopano4s"
"$SUDO" cp -f "$MYDIR"/SPK-PKG/scripts/container/*.sh "$DOCKER_PATH/kopano4s/container"
"$SUDO" cp -f "$MYDIR"/SPK-PKG/scripts/container/*.sh.* "$DOCKER_PATH/kopano4s/container"
"$SUDO" cp -f "$MYDIR"/SPK-PKG/scripts/container/dpkg-remove* "$DOCKER_PATH/kopano4s/container"
"$SUDO" cp -f "$MYDIR"/SPK-APP/merge/kopano-cfg.tgz "$DOCKER_PATH/kopano4s/container"
"$SUDO" cp -f "$MYDIR"/SPK-APP/merge/kinit.tgz "$DOCKER_PATH/kopano4s/container"
"$SUDO" cp -f "$MYDIR"/SPK-APP/ui/images/robot.png "$DOCKER_PATH/kopano4s/container"

echo "Calling kopano4s Dockerfile build at $(date "+%Y%m%d-%H:%M:%S").."
GET_K_DOWNLOAD_RELEASE_TAG()
{
	local URL="$1"
	local TAG="[[:graph:]]*${2}[[:graph:]]*"
	# get basename from download URL for tag (e.g. Debian_9) which is recognized in between double-brackets
	local DOWNL=$(curl --silent "$URL" | grep -o "$TAG" | head -1 | cut -f2 -d \")
	if [ -z "$DOWNL" ]
	then
		echo ""
	fi
	DOWNL_FILE=$(basename "$DOWNL")
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
	TAG1=$( GET_K_DOWNLOAD_RELEASE_TAG "https://download.kopano.io/community/core:/" "Debian_10" )
	if [ -z "$TAG1" ]
	then
		echo "Could not evaluate Kopano core release tag from download; exiting.."
		exit 1
	fi
	#TAG1=8.7.85
	TAG2=$( GET_K_DOWNLOAD_RELEASE_TAG "https://download.kopano.io/community/webapp:/" "Debian_10" )
	if [ -z "$TAG2" ]
	then
		echo "Could not evaluate Kopano webapp release tag from download; exiting.."
		exit 1
	fi
	#TAG2=4.2
	# currently we cut of 3rd suffix as it is 3 digit number
	TAG2=$(echo $TAG2 | cut -f1-2 -d .)
	TAG3=$( GET_K_DOWNLOAD_RELEASE_TAG "https://repo.z-hub.io/z-push:/final/Debian_10/all/" "z-push-kopano_" )
	if [ -z "$TAG3" ]
	then
		echo "Could not evaluate Kopano z-push release tag from download; exiting.."
		exit 1
	fi
	TAG4=$( GET_K_DOWNLOAD_RELEASE_TAG "https://download.kopano.io/community/webmeetings:/" "Debian_10" )
	if [ -z "$TAG4" ]
	then
		echo "Could not evaluate Kopano webmeetings release tag from download; exiting.."
		exit 1
	fi	
	IMG_TAG="Core-${TAG1}_Webapp-${TAG2}_Z-Push-${TAG3}"
	VER_TAG="C-${IMG_TAG}"
	WM_IMG_TAG="Webmeetings-${TAG4}"
	WM_VER_TAG="C-${WM_IMG_TAG}"
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
	#TAG1=8.7.16
	TAG2=$( GET_K_DOWNLOAD_RELEASE_TAG "https://serial:${K_SNR}@download.kopano.io/supported/webapp:/final/tarballs/" "Debian_9.0" )
	if [ -z "$TAG2" ]
	then
		echo "Could not evaluate Kopano webapp release tag from download; exiting.."
		exit 1
	fi
	#TAG2=4.2
	# currently we cut of 3rd suffix as it is 3 digit number
	TAG2=$(echo $TAG2 | cut -f1-2 -d .)
	TAG3=$( GET_K_DOWNLOAD_RELEASE_TAG "https://repo.z-hub.io/z-push:/final/Debian_10/all/" "z-push-kopano_" )
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
	IMG_TAG="Core-${TAG1}_Webapp-${TAG2}_Z-Push-${TAG3}"
	VER_TAG="S-${IMG_TAG}"
	WM_IMG_TAG="Webmeetings-${TAG4}"
	WM_VER_TAG="S-${WM_IMG_TAG}"
	# passing SNR for download via arg http_proxy not found in docker history.
	BUILD_PARAMS="$BUILD_PARAMS --build-arg SUPPORTED_BUILD=1 --build-arg K_SNR=${K_SNR}"
fi
if [ "$K_EDITION" = "Default" ]
then
	TAG1="8.7.14"
	TAG2="4.1"
	TAG3=$( GET_K_DOWNLOAD_RELEASE_TAG "https://repo.z-hub.io/z-push:/final/Debian_10/all/" "z-push-kopano_" )
	if [ -z "$TAG3" ]
	then
		echo "Could not evaluate Kopano z-push release tag from download; exiting.."
		exit 1
	fi
	IMG_TAG="Core-${TAG1}_Webapp-${TAG2}_Z-Push-${TAG3}"
	VER_TAG="D-${IMG_TAG}"
	BUILD_PARAMS="$BUILD_PARAMS --build-arg DEFAULT_BUILD=1 --build-arg K_SNR=${K_SNR}"
fi
if [ "$K_EDITION" = "Migration" ]
then
	IMG_TAG="Core-8.4.5.0_Webapp-3.4.2_Z-Push-2.4.5"
	VER_TAG="M-${IMG_TAG}"
	BUILD_PARAMS="$BUILD_PARAMS --build-arg MIGRATION_BUILD=1 --build-arg K_SNR=${K_SNR}"
	B_WMEET=0
fi
DATE_BUILD=$(date "+%Y-%m-%d")
# in get repo mode only run the k4s-intermediate build and extract repo from container
if [ $# -gt 1 ] && [ "$2" = "get-repo" ]
then
	# get the repo from intermediate image aka stop at the stage and copy from container
	C_BUILD_PARAMS="$BUILD_PARAMS --target k4s-intermediate --tag tosoboso/k4s-repo:${VER_TAG}"
	WM_BUILD_PARAMS="$BUILD_PARAMS --target k4s-intermediate --tag tosoboso/k4s-repo:${WM_VER_TAG}"
else
	C_BUILD_PARAMS="$BUILD_PARAMS --build-arg PARENT=${DOCKER_HOST} --build-arg BUILD=${DATE_BUILD} --build-arg TAG=${IMG_TAG} --tag tosoboso/kopano4s:${VER_TAG}"
	WM_BUILD_PARAMS="$BUILD_PARAMS --build-arg PARENT=${DOCKER_HOST} --build-arg BUILD=${DATE_BUILD} --build-arg TAG=${WM_IMG_TAG} --tag tosoboso/kopano4s:${WM_VER_TAG}"
fi
# in use repo mode only run the k4-main build and use extracted repo from local webserver
if [ $# -gt 1 ] && [ "$2" = "web-repo" ]
then
	WEBREPO=${DOCKER_HOST}/repo
	echo "Building from web-repo $WEBREPO assuming you did run get-repo before and put the artifacts to this location.."
	# in Dockerfile we comment of the copy from interactive which is skipped anyway via target k4s-main
	#sed -i -e 's~^COPY --from=k4s-intermediate~#COPY --from=k4s-intermediate'~  "$DOCKER_PATH"/kopano4s/Dockerfile
	C_BUILD_PARAMS="$C_BUILD_PARAMS --build-arg ENV_BUILD=web-repo --build-arg WEBREPO=${WEBREPO}"
	WM_BUILD_PARAMS="$WM_BUILD_PARAMS --build-arg ENV_BUILD=web-repo --build-arg WEBREPO=${WEBREPO}"
fi

# remove old image if exists
if $SUDO docker images | grep -q "$VER_TAG"
then
	"$SUDO" docker rmi tosoboso/kopano4s:"$VER_TAG"
fi
if ( [ $# -gt 1 ] && [ "$2" = "clean" ] ) || ( [ $# -eq 3 ] && [ "$3" = "clean" ] )
then
	# deleting all containers with status exit if no exists error is ok
	"$SUDO" docker rm -v $($SUDO docker ps -a -q -f status=exited)
	# deleting all images with status dangling - if no exists error is ok
	"$SUDO" docker rmi $($SUDO docker images -f "dangling=true" -q)
	# searching and deleting images with none as name
	LIST=`$SUDO docker images | grep none | grep -o [0-f][0-f][0-f][0-f][0-f][0-f][0-f][0-f][0-f][0-f][0-f][0-f]`
	for L in $LIST ; do "$SUDO" docker rmi -f $L ; done
	C_BUILD_PARAMS="$C_BUILD_PARAMS --no-cache"
	WM_BUILD_PARAMS="$WM_BUILD_PARAMS --no-cache"
fi
if [ $B_CORE -gt 0 ]
then
	echo "Build-Args Core: ${C_BUILD_PARAMS}"
	"$SUDO" docker build ${DOCKER_PATH}/kopano4s ${C_BUILD_PARAMS}
fi
if [ $B_WMEET -gt 0 ]
then
	echo "Build-Args WebMeetings: ${WM_BUILD_PARAMS}"
	"$SUDO" docker build ${DOCKER_PATH}/kopano4s -f ${DOCKER_PATH}/kopano4s/Dockerfile.wmeet ${WM_BUILD_PARAMS}
fi

# if we created image with repo copy it over to place it on a webserver e.g. for wget $PARENT/repo/k4s-${K_EDITION}-repo.tgz
if [ $# -gt 1 ] && [ "$2" = "get-repo" ]
then
	if [ $B_CORE -gt 0 ]
	then
		"$SUDO" docker create -ti --name k4s-repo tosoboso/k4s-repo:${VER_TAG} bash
		"$SUDO" docker cp k4s-repo:/root/k4s-${K_EDITION}-repo.tgz .
		"$SUDO" docker rm -fv k4s-repo
	fi
	if [ $B_WMEET -gt 0 ]
	then
		"$SUDO" docker create -ti --name k4s-repo tosoboso/k4s-repo:${WM_VER_TAG} bash
		"$SUDO" docker cp k4s-repo:/root/k4s-${K_EDITION}-wmeet-repo.tgz .
		"$SUDO" docker rm -fv k4s-repo
	fi
	echo "collected k4s-repo with deb files:"
	ls -al k4s-*repo*
fi
