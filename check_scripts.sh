#!/bin/sh
# static code check to sripts and docker files via shellcheck and hadolint using native packages or docker images
set -euo pipefail
IFS=$'\n\t'
# will not run native on synology as shellcheck missing but we can use docker image
if ! [ -x "$(command -v shellcheck)" ] && [ $# -eq 0 ] || [ "$1" != "docker" ]
then
	echo 'Error: shellcheck is not installed; run with parameter docker or use frontend https://www.shellcheck.net/.' >&2
	exit 1
fi
if [ $# -gt 0 ] && [ "$1" == "docker" ]
then
	echo "Switching in sudo mode for Docker. You may need to provide root password at initial call"
	echo "$(date '+%Y.%m.%d-%H:%M:%S') Starting shellcheck for synology spk scripts.." > check_scripts.out
	SCRIPTS=$(ls -p ~/repo/Kopano4s/PKG/scripts/ | grep -v /)
	# skipp following source (1090) parsing pure posix (SC2030), unused variables (SC2034), extra $() on arithmetic (SC2004)
	for S in $SCRIPTS ; do sudo docker run -it -v ~/repo/Kopano4s/PKG/scripts:/mnt -e SHELLCHECK_OPTS="-e SC1090 -e SC2039 -e SC2034 -e SC2004" --rm koalaman/shellcheck "$S" >> check_scripts.out ; done
	# for *.sh we do not need a loop
	echo "$(date '+%Y.%m.%d-%H:%M:%S') Starting shellcheck for container scripts.." >> check_scripts.out
	SCRIPTS=$(ls -p ~/repo/Kopano4s/PKG/scripts/container/*.sh)
	for S in $SCRIPTS ; do sudo docker run -it -v ~/repo/Kopano4s/PKG/scripts/container:/mnt -e SHELLCHECK_OPTS="-e SC1090 -e SC2039 -e SC2034 -e SC2004" --rm koalaman/shellcheck "$S" >> check_scripts.out ; done
	echo "$(date '+%Y.%m.%d-%H:%M:%S') Starting shellcheck for add-on scripts.." >> check_scripts.out
	SCRIPTS=$(ls -p ~/repo/Kopano4s/PKG/scripts/container/*.sh)
	for S in $SCRIPTS ; do sudo docker run -it -v ~/repo/Kopano4s/PKG/scripts/addon:/mnt -e SHELLCHECK_OPTS="-e SC1090 -e SC2039 -e SC2034 -e SC2004" --rm koalaman/shellcheck "$S" >> check_scripts.out ; done
else
	grep -rIl '^#![[:blank:]]*/bin/\(bash\|sh\|zsh\)' --exclude-dir=.git --exclude=*.sw? | xargs shellcheck > check_scripts.out
fi
if [ -x "$(command -v hadolint)" ]
then
	# List files which name starts with 'Dockerfile"	# eg. Dockerfile, Dockerfile.build, etc. and send it to hadolint
	git ls-files --exclude='Dockerfile*' --ignored | xargs --max-lines=1 hadolint
else
	echo 'Warning: hadolint is not installed. Skipping Dockerfile check' >&2
fi
exit 0
