#!/bin/bash

set -euo pipefail
IFS=$'\n\t'
# will not run nativ on synology as shellcheck missing
if ! [ -x "$(command -v shellcheck)" ]; then
	echo 'Error: shellcheck is not installed; use it via web frontend https://www.shellcheck.net/.' >&2
	exit 1
fi
grep -rIl '^#![[:blank:]]*/bin/\(bash\|sh\|zsh\)' \
--exclude-dir=.git --exclude=*.sw? \
| xargs shellcheck
if ! [ -x "$(command -v hadolint)" ]; then
	echo 'Error: hadolint is not installed.' >&2
	exit 1
fi
# List files which name starts with 'Dockerfile'
# eg. Dockerfile, Dockerfile.build, etc. and send it to hadolint
git ls-files --exclude='Dockerfile*' --ignored | xargs --max-lines=1 hadolint
