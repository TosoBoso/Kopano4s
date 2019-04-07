#!/bin/sh
# (c) 2018 vbettag - wraper script for kopano4s-init optional services in Docker container
# admins only plus set sudo for DSM 6 as root login is no longer possible
LOGIN=`whoami`
if [ $LOGIN != "root" ] && ! (grep administrators /etc/group | grep -q $LOGIN)
then 
	echo "admins only"
	exit 1
fi
MAJOR_VERSION=`grep majorversion /etc.defaults/VERSION | grep -o [0-9]`
if [ $MAJOR_VERSION -gt 5 ] && [ $LOGIN != "root" ]
then
	echo "Switching in sudo mode. You may need to provide root password at initial call.."
	SUDO="sudo"
else
	SUDO=""
fi
# get common and config
. /var/packages/Kopano4s/scripts/common
. "$ETC_PATH"/package.cfg
# default does not work message avoid repeating cmd ech else path
MSG="please provide 2nd parameter for on or off"
case "$1" in
	help)
	echo "kopano4s-optionals (c) TosoBoso: script to en- or disable optional services in init-script for kopano4s"
	MSG="provide kopano-service: gateway | ical | search | monitor | amavis |  bounce-spam | spamd | postgrey | fetchmail | courier-imap | webmeetings | coturn to set it to on or off."
	;;
	gateway)
	if grep -q "^#GATEWAY_ENABLED" $ETC_PATH/kopano/default
	then
		$SUDO sed -i -e 's~#GATEWAY_ENABLED~GATEWAY_ENABLED~' $ETC_PATH/kopano/default
	fi
	if [ $# -gt 1 ] && [ $2 = "on" ]
	then
		$SUDO sed -i -e 's~GATEWAY_ENABLED.*~GATEWAY_ENABLED=yes~' $ETC_PATH/kopano/default
		$SUDO sed -i -e 's~K_GATEWAY.*~K_GATEWAY="ON"~' $ETC_PATH/package.cfg
		MSG="Gateway enabled; please run kopano4s-init container to make effective"
	else
		if [ $# -gt 1 ] && [ $2 = "off" ]
		then
			$SUDO sed -i -e 's~GATEWAY_ENABLED.*~GATEWAY_ENABLED=no~' $ETC_PATH/kopano/default
			$SUDO sed -i -e 's~K_GATEWAY.*~K_GATEWAY="OFF"~' $ETC_PATH/package.cfg
			MSG="Gateway disabled; please run kopano4s-init container to make effective"
		fi
	fi
	;;
	ical)
	if grep -q "^#ICAL_ENABLED" $ETC_PATH/kopano/default
	then
		$SUDO sed -i -e 's~#ICAL_ENABLED~ICAL_ENABLED~' $ETC_PATH/kopano/default
	fi
	if [ $# -gt 1 ] && [ $2 = "on" ]
	then
		$SUDO sed -i -e 's~ICAL_ENABLED.*~ICAL_ENABLED=yes~' $ETC_PATH/kopano/default
		$SUDO sed -i -e 's~K_ICAL.*~K_ICAL="ON"~' $ETC_PATH/package.cfg
		MSG="ICAL enabled; please run kopano4s-init container to make effective"
	else
		if [ $# -gt 1 ] && [ $2 = "off" ]
		then
			$SUDO sed -i -e 's~ICAL_ENABLED.*~ICAL_ENABLED=no~' $ETC_PATH/kopano/default
			$SUDO sed -i -e 's~K_ICAL.*~K_ICAL="OFF"~' $ETC_PATH/package.cfg
			MSG="ICAL disabled; please run kopano4s-init container to make effective"
		fi
	fi
	;;
	search)
	if grep -q "^#SEARCH_ENABLED" $ETC_PATH/kopano/default
	then
		$SUDO sed -i -e 's~#SEARCH_ENABLED~SEARCH_ENABLED~' $ETC_PATH/kopano/default
	fi
	# search is also present in server.cfg
	if grep -q "^#search_enabled" $ETC_PATH/kopano/server.cfg
	then
		$SUDO sed -i -e 's~#search_enabled~search_enabled~' $ETC_PATH/kopano/server.cfg
	fi
	if [ $# -gt 1 ] && [ $2 = "on" ]
	then
		$SUDO sed -i -e 's~SEARCH_ENABLED.*~SEARCH_ENABLED=yes~' $ETC_PATH/kopano/default
		# search is also present in server.cfg
		$SUDO sed -i -e 's~#search_enabled.*~search_enabled = yes~' $ETC_PATH/kopano/server.cfg
		$SUDO sed -i -e 's~K_SEARCH.*~K_SEARCH="ON"~' $ETC_PATH/package.cfg
		MSG="Search enabled; please restart package to make effective"
	else
		if [ $# -gt 1 ] && [ $2 = "off" ]
		then
			$SUDO sed -i -e 's~SEARCH_ENABLED.*~SEARCH_ENABLED=no~' $ETC_PATH/kopano/default
			# search is also present in server.cfg
			$SUDO sed -i -e 's~#search_enabled.*~search_enabled = no~' $ETC_PATH/kopano/server.cfg
			$SUDO sed -i -e 's~K_SEARCH.*~K_SEARCH="OFF"~' $ETC_PATH/package.cfg
			MSG="Search disabled; please restart package to make effective"
		fi
	fi
	;;
	monitor)
	if grep -q "^#MONITOR_ENABLED" $ETC_PATH/kopano/default
	then
		$SUDO sed -i -e 's~#MONITOR_ENABLED~MONITOR_ENABLED~' $ETC_PATH/kopano/default
	fi
	if [ $# -gt 1 ] && [ $2 = "on" ]
	then
		$SUDO sed -i -e 's~MONITOR_ENABLED.*~MONITOR_ENABLED=yes~' $ETC_PATH/kopano/default
		$SUDO sed -i -e 's~K_MONITOR.*~K_MONITOR="ON"~' $ETC_PATH/package.cfg
		MSG="Monitor enabled; please restart package to make effective"
	else
		if [ $# -gt 1 ] && [ $2 = "off" ]
		then
			$SUDO sed -i -e 's~MONITOR_ENABLED.*~MONITOR_ENABLED=no~' $ETC_PATH/kopano/default
			$SUDO sed -i -e 's~K_MONITOR.*~K_MONITOR="OFF"~' $ETC_PATH/package.cfg
			MSG="Monitor disabled; please restart package to make effective"
		fi
	fi
	;;
	amavis)
	if [ $# -gt 1 ] && [ $2 = "on" ]
	then
		$SUDO sed -i -e 's~AMAVISD_ENABLED.*~AMAVISD_ENABLED=yes~' $ETC_PATH/kopano/default
		$SUDO sed -i -e 's~CLAMAVD_ENABLED.*~CLAMAVD_ENABLED=yes~' $ETC_PATH/kopano/default
		$SUDO sed -i -e 's~K_AMAVISD.*~K_AMAVISD="ON"~' $ETC_PATH/package.cfg
		$SUDO sed -i -e 's~K_CLAMAVD.*~K_CLAMAVD="ON"~' $ETC_PATH/package.cfg
		$SUDO sed -i -e "s~#content_filter =~content_filter =~" $ETC_PATH/kopano/postfix/main.cf
		$SUDO sed -i -e "s~spam_header_name = X-Spam-Status~spam_header_name = X-Spam-Flag~" $ETC_PATH/kopano/dagent.cfg
		$SUDO sed -i -e "s~spam_header_value = Yes,~spam_header_value = Yes~" $ETC_PATH/kopano/dagent.cfg
		echo -e "\n" | $SUDO docker exec -i kopano4s kopano-postfix.sh refresh-avdb
		MSG="Amavis enabled and av database initialised; please restart package to make effective"
	else
		if [ $# -gt 1 ] && [ $2 = "off" ]
		then
			$SUDO sed -i -e 's~AMAVISD_ENABLED.*~AMAVISD_ENABLED=no~' $ETC_PATH/kopano/default
			$SUDO sed -i -e 's~CLAMAVD_ENABLED.*~CLAMAVD_ENABLED=no~' $ETC_PATH/kopano/default
			$SUDO sed -i -e 's~K_AMAVISD.*~K_AMAVISD="OFF"~' $ETC_PATH/package.cfg
			$SUDO sed -i -e 's~K_CLAMAVD.*~K_CLAMAVD="OFF"~' $ETC_PATH/package.cfg
			$SUDO sed -i -e "s~content_filter =~#content_filter =~" $ETC_PATH/kopano/postfix/main.cf
			$SUDO sed -i -e "s~spam_header_name = X-Spam-Flag~spam_header_name = X-Spam-Status~" $ETC_PATH/kopano/dagent.cfg
			$SUDO sed -i -e "s~spam_header_value = Yes~spam_header_value = Yes,~" $ETC_PATH/kopano/dagent.cfg
			MSG="Amavis disabled; please restart package to make effective"
		fi
	fi
	;;
	bounce-spam)
	if [ $# -gt 1 ] && [ $2 = "on" ]
	then
		$SUDO sed -i -e 's~BOUNCE_SPAM_ENABLED.*~BOUNCE_SPAM_ENABLED=yes~' $ETC_PATH/kopano/default
		$SUDO sed -i -e 's~K_BOUNCE_SPAM.*~K_BOUNCE_SPAM="ON"~' $ETC_PATH/package.cfg
		$SUDO sed -i -e "s~\$final_spam_destiny.*~\$final_spam_destiny       = D_BOUNCE;~" $ETC_PATH/kopano/default-amavis
		MSG="Bounce Spam enabled; please restart package to make effective"
	else
		if [ $# -gt 1 ] && [ $2 = "off" ]
		then
			$SUDO sed -i -e 's~BOUNCE_SPAM_ENABLED.*~BOUNCE_SPAM_ENABLED=no~' $ETC_PATH/kopano/default
			$SUDO sed -i -e 's~K_BOUNCE_SPAM.*~K_BOUNCE_SPAM="OFF"~' $ETC_PATH/package.cfg		
			$SUDO sed -i -e "s~\$final_spam_destiny.*~\$final_spam_destiny       = D_PASS;~" $ETC_PATH/kopano/default-amavis
			MSG="Bounce Spam  disabled; please restart package to make effective"
		fi
	fi
	;;
	spamd)
	if [ $# -gt 1 ] && [ $2 = "on" ]
	then
		$SUDO sed -i -e 's~SPAMD_ENABLED.*~SPAMD_ENABLED=yes~' $ETC_PATH/kopano/default
		$SUDO sed -i -e 's~K_POSTGREY.*~K_POSTGREY="ON"~' $ETC_PATH/package.cfg
		$SUDO sed -i -e "s~#check_policy_service ~check_policy_service " $ETC_PATH/kopano/postfix/main.cf
		MSG="Postgrey enabled; please restart package to make effective"
	else
		if [ $# -gt 1 ] && [ $2 = "off" ]
		then
			$SUDO sed -i -e 's~POSTGREY_ENABLED.*~POSTGREY_ENABLED=no~' $ETC_PATH/kopano/default
			$SUDO sed -i -e 's~K_POSTGREY.*~K_POSTGREY="OFF"~' $ETC_PATH/package.cfg
			$SUDO sed -i -e "s~check_policy_service ~#check_policy_service " $ETC_PATH/kopano/postfix/main.cf
			MSG="Postgrey disabled; please restart package to make effective"
		fi
	fi
	;;
	postgrey)
	if [ $# -gt 1 ] && [ $2 = "on" ]
	then
		$SUDO sed -i -e 's~POSTGREY_ENABLED.*~POSTGREY_ENABLED=yes~' $ETC_PATH/kopano/default
		$SUDO sed -i -e 's~K_POSTGREY.*~K_POSTGREY="ON"~' $ETC_PATH/package.cfg
		$SUDO sed -i -e "s~#check_policy_service ~check_policy_service " $ETC_PATH/kopano/postfix/main.cf
		MSG="Postgrey enabled; please restart package to make effective"
	else
		if [ $# -gt 1 ] && [ $2 = "off" ]
		then
			$SUDO sed -i -e 's~POSTGREY_ENABLED.*~POSTGREY_ENABLED=no~' $ETC_PATH/kopano/default
			$SUDO sed -i -e 's~K_POSTGREY.*~K_POSTGREY="OFF"~' $ETC_PATH/package.cfg
			$SUDO sed -i -e "s~check_policy_service ~#check_policy_service " $ETC_PATH/kopano/postfix/main.cf
			MSG="Postgrey disabled; please restart package to make effective"
		fi
	fi
	;;
	fetchmail)
	if [ $# -gt 1 ] && [ $2 = "on" ]
	then
		$SUDO sed -i -e 's~FETCHMAIL_ENABLED.*~FETCHMAIL_ENABLED=yes~' $ETC_PATH/kopano/default
		MSG="Fetchmail enabled; please restart package to make effective"
	else
		if [ $# -gt 1 ] && [ $2 = "off" ]
		then
			$SUDO sed -i -e 's~FETCHMAIL_ENABLED.*~FETCHMAIL_ENABLED=yes~' $ETC_PATH/kopano/default
			MSG="Fetchmail diabled; please restart package to make effective"
		fi
	fi
	;;
	courier-imap)
	if [ $# -gt 1 ] && [ $2 = "on" ]
	then
		$SUDO sed -i -e 's~COURIER_IMAP_ENABLED.*~COURIER_IMAP_ENABLED=yes~' $ETC_PATH/kopano/default
		$SUDO sed -i -e 's~K_ARCHIVE_IMAP.*~K_ARCHIVE_IMAP="ON"~' $ETC_PATH/package.cfg
		MSG="Courier-imap enabled; please run kopano4s-init container to make effective"
	else
		if [ $# -gt 1 ] && [ $2 = "off" ]
		then
			$SUDO sed -i -e 's~COURIER_IMAP_ENABLED.*~COURIER_IMAP_ENABLED=no~' $ETC_PATH/kopano/default
			$SUDO sed -i -e 's~K_ARCHIVE_IMAP.*~K_ARCHIVE_IMAP="OFF"~' $ETC_PATH/package.cfg
			MSG="Courier-imap disabled; please run kopano4s-init container to make effective"
		fi
	fi
	;;
	webmeetings)
	if [ $# -gt 1 ] && [ $2 = "on" ]
	then
		$SUDO sed -i -e 's~WEBMEETINGS_ENABLED.*~WEBMEETINGS_ENABLED=yes~' $ETC_PATH/kopano/default
		$SUDO sed -i -e 's~PRESENCE_ENABLED.*~PRESENCE_ENABLED=yes~' $ETC_PATH/kopano/default
		$SUDO sed -i -e 's~K_WEBMEETINGS.*~K_WEBMEETINGS="ON"~' $ETC_PATH/package.cfg
		MSG="Webmeetings enabled; please run kopano4s-init container to make effective"
	else
		if [ $# -gt 1 ] && [ $2 = "off" ]
		then
			$SUDO sed -i -e 's~WEBMEETINGS_ENABLED.*~WEBMEETINGS_ENABLED=no~' $ETC_PATH/kopano/default
			$SUDO sed -i -e 's~PRESENCE_ENABLED.*~PRESENCE_ENABLED=no~' $ETC_PATH/kopano/default
			$SUDO sed -i -e 's~K_WEBMEETINGS.*~K_WEBMEETINGS="OFF"~' $ETC_PATH/package.cfg
			MSG="Webmeetings disabled; please run kopano4s-init container to make effective"
		fi
	fi
	;;
	coturn)
	if [ $# -gt 1 ] && [ $2 = "on" ]
	then
		$SUDO sed -i -e 's~COTURN_ENABLED.*~COTURN_ENABLED=yes~' $ETC_PATH/kopano/default
		MSG="Coturn enabled; please run kopano4s-init container to make effective"
	else
		if [ $# -gt 1 ] && [ $2 = "off" ]
		then
			$SUDO sed -i -e 's~COTURN_ENABLED.*~COTURN_ENABLED=no~' $ETC_PATH/kopano/default
			MSG="Coturn disabled; please run kopano4s-init container to make effective"
		fi
	fi
	;;
	*)
	echo "provide kopano-service: gateway | ical | search | monitor | amavis | bounce-spam | spamd | postgrey | fetchmail | courier-imap | webmeetings | coturn to set it to on or off."
	;;
esac
echo "$MSG"
exit 0