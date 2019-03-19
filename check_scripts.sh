#!/bin/bash

set -euo pipefail
IFS=$'\n\t'

grep -rIl '^#![[:blank:]]*/bin/\(bash\|sh\|zsh\)' \
--exclude-dir=.git --exclude=*.sw? \
| xargs shellcheck

# List files which name starts with 'Dockerfile'
# eg. Dockerfile, Dockerfile.build, etc.
git ls-files --exclude='Dockerfile*' --ignored | xargs --max-lines=1 hadolint
