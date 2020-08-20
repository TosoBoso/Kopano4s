#!/bin/bash
# (c) 2020 vbettag entrypoint for Kopano4S containers using tini, gosu, bash 4.x wait-n plus signal handler
set -eu # unset variables are errors & non-zero return values exit the whole script
DEBUG=${DEBUG:-0}
[ "$DEBUG" -gt 0 ] && set -x
# shutdown function incl. global vars: PIDLIST, EXITCODE to deal with in capturing signal sent from tini 
PIDLIST=""
EXITCODE=0
function shutdown() {
    trap "" SIGINT
    local PID
    for PID in $PIDLIST; do
        if ! kill -0 $PID 2>/dev/null; then
            wait $PID
            EXITCODE=$?
        fi
    done
    kill -9 $PIDLIST 2>/dev/null
}
# for docker secret files passed via XYZ_FILE source into environment variables with the same name
get_file_envs() {
	local FILE_ENV
	local VAR_ENV
	local VAR_VALUE
	for FILE_ENV in $(printenv | grep _FILE | cut -f1 -d"=") ; do
		if [ -n "$FILE_ENV" ] && [ -e "${!FILE_ENV}" ] ; then
			# get the left-hand-side to FILE_ENV aka removing _FILE suffix
			VAR_ENV=${FILE_ENV%%"_FILE"*}
			# get value from secret file and export it must use ${!VAR}
			# shellcheck disable=SC2016
			VAR_VALUE="$(< "${!FILE_ENV}")"
			export "$VAR_ENV"="$VAR_VALUE"
		fi
	done
}
# update service config files from env variables via Service_CFG_Var=Value exclude _FILE: secret files
set_env_to_cfg() {
	local CFG_ENV
	local SRV
	local CFG
	local CFG
	local VAR_ENV
	local SEPARATOR
	for CFG_ENV in $(env | grep _CFG_ | grep -v _FILE | cut -f1 -d"=") ; do
		# get service SRV as left-hand-side and VAR as right hand side to CFG_ENV
		SRV=${CFG_ENV%%"_CFG_"*}
		VAR_ENV=${CFG_ENV#*"_CFG_"}
		# find in /etc non case sensitive te config file with ending cfg, conf, cf
		CFG=$(find /etc -type f -iname ${SRV}.c*f* | tail -1)
		if [ -n "$CFG" ] && [ -e ${CFG} ] && [ -n "${!CFG_ENV}" ] && grep -q "^$VAR_ENV" "$CFG" ; then
			echo "updating $CFG for $VAR_ENV"
			if grep "^$VAR_ENV" "$CFG" | grep -q "=" ; then
				SEPARATOR="= "
			else
				# some cfg files have only space as seperator eg. clamd
				SEPARATOR=""			
			fi
			# assign value of CFG_ENV to extracted varaible VAR_ENV for CFG file using respective seperator
			sed "s~^$VAR_ENV .*~$VAR_ENV ${SEPARATOR}${!CFG_ENV}~" -i "$CFG"
		fi
	done
}
# update service php-config files from env variables via Service_PHPCFG_Var=Value exclude _FILE: secret files
set_env_to_php_cfg() {
	local CFG_ENV
	local SRV
	local CFG
	local CFG
	local VAR_ENV
	local SEPARATOR
	for CFG_ENV in $(env | grep _CFGPHP_ | grep -v _FILE | cut -f1 -d"=") ; do
		# get service SRV as left-hand-side and VAR as right hand side to CFG_ENV

	done
}
# clean up environment from posted secrets and variables
clean_cfg_file_envs() {
	local CFG_ENV
	for CFG_ENV in $(env | _FILE | cut -f1 -d"=") ; do
		unset "${CFG_ENV}"
	done
	for CFG_ENV in $(env | grep _CFG_ | grep -v _FILE | cut -f1 -d"=") ; do
		unset "${CFG_ENV}"
	done
	for CFG_ENV in $(env | grep _CFGPHP_ | grep -v _FILE | cut -f1 -d"=") ; do
		unset "${CFG_ENV}"
	done
}
# set the uid and gid of kopano provided from env
set_uid_gid() {
	K_UID=${K_UID:-1099}
	K_GID=${K_GID:-65599}
	echo "modifying kopano user and group ids ($K_UID / $K_GID) .."
	groupmod -g $K_GID kopano
	usermod -u $K_UID kopano	
}
# copy over default cfg and set acl ownership to kopano for etc and var-log
set_cfg_log_acls() {
	local CONFIGS
	local CFG
	if [ -e /etc/kopano ] ; then
		CONFIGS=$(find /etc-dist/kopano/*.cfg -maxdepth 0 -type f -exec basename "{}" ";")
		for CFG in $CONFIGS; do if [ ! -e /etc/kopano/$CFG ] ; then cp /etc-dist/kopano/$CFG /etc/kopano ; fi ; done	
		CONFIGS=$(find /etc-dist/kopano/default* -maxdepth 0 -type f -exec basename "{}" ";")
		for CFG in $CONFIGS; do if [ ! -e /etc/kopano/$CFG ] ; then cp /etc-dist/kopano/$CFG /etc/kopano ; fi ; done	
		chown -R root.kopano /etc/kopano
	fi
	if [ -e /var/log/kopano ] ; then chown -R kopano.kopano /var/log/kopano ; fi
}
# services to run dependent on container (core, web, mail, (web)meet, chat, spam, av)
get_services() {
	local CORE_SERVICE=${1:-dummy}
	local SERVICES=""
	case "$CORE_SERVICE" in
	dummy)	
		SERVICES="coreutils" # tail for dummy is part of coreutils
		;;		
	mail)
		SERVICES="postfix rsyslog"
		;;
	server)	
		SERVICES="kopano-server kopano-spooler kopano-dagent"
		if [ -e /etc/kopano/default ] ; then
			if grep -q ^GATEWAY_ENABLED=yes /etc/kopano/default ; then SERVICES="$SERVICES kopano-gateway" ; fi
			if grep -q ^ICAL_ENABLED=yes /etc/kopano/default ; then SERVICES="$SERVICES kopano-ical" ; fi
			if grep -q ^MONITOR_ENABLED=yes /etc/kopano/default ; then SERVICES="$SERVICES kopano-monitor" ; fi
			if grep -q ^PRESENCE_ENABLED=yes /etc/kopano/default ; then W_SERVICES="$SERVICES kopano-presence" ; fi
			if grep -q ^SEARCH_ENABLED=yes /etc/kopano/default ; then SERVICES="$SERVICES kopano-search" ; fi
		fi
		;;
	web)	
		SERVICES="nginx php${PHP_VER}-fpm"
		;;		
	webmeetings)	
		SERVICES="kopano-webmeetings"
		;;
	esac
	echo "$SERVICES"
}
# cmds for each service as alternative to init.d / systemd scripts and concious of parameter changes in kopano
get_run_cmd() {
	local SERVICE=${1:-coreutils} # tail for dummy is part of coreutils
	local SRV_VERSION=$(dpkg-query --showformat='${Version}' --show "$SERVICE")
	case "$SERVICE" in
	kopano-server)
		echo "gosu kopano /usr/sbin/kopano-server"
		;;
	kopano-dagent)
		echo "gosu kopano /usr/sbin/kopano-dagent -l -d"
		;;
	kopano-gateway)
		echo "gosu kopano /usr/sbin/kopano-gateway"
		;;
	kopano-ical)
		echo "gosu kopano /usr/sbin/kopano-ical"
		;;
	kopano-grapi)
		echo "gosu kopano kopano-grapi serve &"
		;;
	kopano-kapi)
		echo "gosu kopano kopano-kapid serve --log-timestamp=false"
		;;
	kopano-monitor)
		echo "gosu kopano /usr/sbin/kopano-monitor"
		;;
	kopano-search)
		# give kopano-server time to settle at startup
		sleep 3
		# search does not use -F(oreground) any longer with 8.7.82.165 so we need &
		if dpkg --compare-versions "$SRV_VERSION" "gt" "8.7.82.165"; then
			echo "gosu kopano /usr/sbin/kopano-search &"
		else
			echo "gosu kopano /usr/sbin/kopano-search"
		fi
		;;
	kopano-spooler)
		echo "gosu kopano /usr/sbin/kopano-spooler"
		;;		
	kopano-webmeetings)
    	export GOMAXPROCS=1
		local NOFILE=1024
		ulimit -n $NOFILE
		echo "gosu kopano /usr/sbin/kopano-webmeetings &"
		;;		
	coreutils)	# tail for dummy is part of coreutils
		echo "gosu kopano tail -f /dev/null"
		;;
	esac		
}
# check for init.done flag
_is_initialized() {
	[ -e /etc/init.done ]
}
# check to see if this file is being run or sourced from another script
_is_sourced() {
	# https://unix.stackexchange.com/a/215279
	[ "${#FUNCNAME[@]}" -ge 2 ] \
		&& [ "${FUNCNAME[0]}" = '_is_sourced' ] \
		&& [ "${FUNCNAME[1]}" = 'source' ]
}
_main() {
	local ACTION=""
	local SERVICES=""
	local SRV=""
	local CFG_DIR=""
	CORE_SERVICE=${CORE_SERVICE:-dummy}
	SERVICES=$(get_services "$CORE_SERVICE")
	if ! _is_initialized; then
		set_uid_gid
		set_cfg_log_acls
		get_file_envs
		set_env_to_cfg
		set_env_to_php_cfg
		echo "$(date "+%Y-%m-%d-%H:%M")" > /etc/init.done 
	fi
	clean_cfg_file_envs
	[ "$DEBUG" -eq 2 ] && echo "environment:" && printenv
	if [ $# -gt 0 ] ; then
		ACTION="$1"
	fi
	# start stop status in synology mode, start runs with trap and wait-n
	case $ACTION in
		start)
		local CMD=""
		echo "active services: $SERVICES"
		for SRV in $SERVICES ; do
			CMD=$(get_run_cmd "$SRV")
			echo "starting via $CMD.."
			exec $CMD
		done
		# recognize PIDs started in this shell scripot
		PIDLIST=$(jobs -p)
		echo "Pidlist: $PIDLIST"
		trap shutdown SIGINT
		wait -n
		echo "exiting $EXITCODE.."
		exit $EXITCODE
		;;
		status)		
		;;
		*)
		echo "valid parameters: start, status, upgrade, ssl, acl"
		exit 1
		;;
	esac	
}
if ! _is_sourced; then
	_main "$@"
fi
