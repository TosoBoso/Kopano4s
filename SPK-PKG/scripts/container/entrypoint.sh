#!/bin/bash
# (c) 2020 vbettag init entrypoint for Kopano4S(ynolog) containers inspired by postgres-docker & kopano-docker
set -eu # unset variables are errors & non-zero return values exit the whole script

# for secret files passed via XYZ_FILE source environment variables expanding via file_env
# it sources the file into variable of same name without _FILE extension to use Dockers secrets feature
# generic solution instead of expected values as in postgres-docker e.g. via file_env 'POSTGRES_PASSWORD'
get_file_envs() {
	local local envFileVar;
	for envFileVar in $(printenv | grep _FILE | cut -f1 -d"=") ; do
		if [ -n ${envFileVar} ] && [ -e ${!envFileVar} ] ; then
			# get the left-hand-side to envFileVar aka removing _FILE
			local envVar=${envFileVar%%"_FILE"*}
			# get value from secret file and export it
			local value="$(< "${!envFileVar}")"
			export "$envVar"="$value"
		fi
	done
}

# check to see if this file is being run or sourced from another script
_is_sourced() {
	# https://unix.stackexchange.com/a/215279
	[ "${#FUNCNAME[@]}" -ge 2 ] \
		&& [ "${FUNCNAME[0]}" = '_is_sourced' ] \
		&& [ "${FUNCNAME[1]}" = 'source' ]
}
_main() {

	get_file_envs
	if [ "$DEBUG" -eq 1 ] ; then echo "Environment:" && printenv ; fi
	#exec "$@"
	tail -f /dev/null
}

if ! _is_sourced; then
	_main "$@"
fi
