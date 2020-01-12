#!/bin/sh
# (c) 2018 vbettag - wraper script for kopano4s-init optional services in Docker container
# admins only plus set sudo for DSM 6 as root login is no longer possible
LOGIN=$(whoami)
if [ $LOGIN != "root" ] && ! (grep administrators /etc/group | grep -q "$LOGIN")
then 
	echo "admins only"
	exit 1
fi
if [ "$LOGIN" != "root" ]
then
	echo "Switching in sudo mode. You may need to provide root password at initial call.."
	SUDO="sudo"
else
	SUDO=""
fi
# ** get library and common procedures, settings, tags and download urls
. /var/packages/Kopano4s/scripts/library
. /var/packages/Kopano4s/scripts/common
. /var/packages/Kopano4s/etc/package.cfg
# default does not work message avoid repeating cmd ech else path
MSG="please provide 2nd parameter for on or off"
case "$1" in
	help)
	echo "kopano4s-optionals (c) TosoBoso: script to en- or disable optional services in init-script for kopano4s"
	MSG="provide kopano-service: gateway | ical | search | monitor | autoblock | amavis | clamav | bounce-spam | helo/mx/rbl-check | spamd | postgrey | fetchmail | courier-imap | webmeetings | coturn to set it to on or off."
	;;
	gateway)
	if grep -q "^#GATEWAY_ENABLED" "$ETC_PATH"/kopano/default
	then
		$SUDO sed -i -e 's~#GATEWAY_ENABLED~GATEWAY_ENABLED~' "$ETC_PATH"/kopano/default
	fi
	if [ $# -gt 1 ] && [ $2 = "on" ]
	then
		$SUDO sed -i -e 's~GATEWAY_ENABLED.*~GATEWAY_ENABLED=yes~' "$ETC_PATH"/kopano/default
		$SUDO sed -i -e 's~K_GATEWAY.*~K_GATEWAY="ON"~' "$ETC_PATH"/package.cfg
		MSG="Gateway enabled; please run kopano4s-init container to make effective"
	else
		if [ $# -gt 1 ] && [ $2 = "off" ]
		then
			$SUDO sed -i -e 's~GATEWAY_ENABLED.*~GATEWAY_ENABLED=no~' "$ETC_PATH"/kopano/default
			$SUDO sed -i -e 's~K_GATEWAY.*~K_GATEWAY="OFF"~' "$ETC_PATH"/package.cfg
			MSG="Gateway disabled; please run kopano4s-init container to make effective"
		fi
	fi
	;;
	ical)
	if grep -q "^#ICAL_ENABLED" "$ETC_PATH"/kopano/default
	then
		$SUDO sed -i -e 's~#ICAL_ENABLED~ICAL_ENABLED~' "$ETC_PATH"/kopano/default
	fi
	if [ $# -gt 1 ] && [ $2 = "on" ]
	then
		$SUDO sed -i -e 's~ICAL_ENABLED.*~ICAL_ENABLED=yes~' "$ETC_PATH"/kopano/default
		$SUDO sed -i -e 's~K_ICAL.*~K_ICAL="ON"~' "$ETC_PATH"/package.cfg
		MSG="ICAL enabled; please run kopano4s-init container to make effective"
	else
		if [ $# -gt 1 ] && [ $2 = "off" ]
		then
			$SUDO sed -i -e 's~ICAL_ENABLED.*~ICAL_ENABLED=no~' "$ETC_PATH"/kopano/default
			$SUDO sed -i -e 's~K_ICAL.*~K_ICAL="OFF"~' "$ETC_PATH"/package.cfg
			MSG="ICAL disabled; please run kopano4s-init container to make effective"
		fi
	fi
	;;
	search)
	if grep -q "^#SEARCH_ENABLED" "$ETC_PATH"/kopano/default
	then
		$SUDO sed -i -e 's~#SEARCH_ENABLED~SEARCH_ENABLED~' "$ETC_PATH"/kopano/default
	fi
	# search is also present in server.cfg
	if grep -q "^#search_enabled" "$ETC_PATH"/kopano/server.cfg
	then
		$SUDO sed -i -e 's~#search_enabled~search_enabled~' "$ETC_PATH"/kopano/server.cfg
	fi
	if [ $# -gt 1 ] && [ $2 = "on" ]
	then
		$SUDO sed -i -e 's~SEARCH_ENABLED.*~SEARCH_ENABLED=yes~' "$ETC_PATH"/kopano/default
		# search is also present in server.cfg
		$SUDO sed -i -e 's~#search_enabled.*~search_enabled = yes~' "$ETC_PATH"/kopano/server.cfg
		$SUDO sed -i -e 's~K_SEARCH.*~K_SEARCH="ON"~' "$ETC_PATH"/package.cfg
		MSG="Search enabled; please restart package to make effective"
	else
		if [ $# -gt 1 ] && [ $2 = "off" ]
		then
			$SUDO sed -i -e 's~SEARCH_ENABLED.*~SEARCH_ENABLED=no~' "$ETC_PATH"/kopano/default
			# search is also present in server.cfg
			$SUDO sed -i -e 's~#search_enabled.*~search_enabled = no~' "$ETC_PATH"/kopano/server.cfg
			$SUDO sed -i -e 's~K_SEARCH.*~K_SEARCH="OFF"~' "$ETC_PATH"/package.cfg
			MSG="Search disabled; please restart package to make effective"
		fi
	fi
	;;
	monitor)
	if grep -q "^#MONITOR_ENABLED" "$ETC_PATH"/kopano/default
	then
		$SUDO sed -i -e 's~#MONITOR_ENABLED~MONITOR_ENABLED~' "$ETC_PATH"/kopano/default
	fi
	if [ $# -gt 1 ] && [ $2 = "on" ]
	then
		$SUDO sed -i -e 's~MONITOR_ENABLED.*~MONITOR_ENABLED=yes~' "$ETC_PATH"/kopano/default
		$SUDO sed -i -e 's~K_MONITOR.*~K_MONITOR="ON"~' "$ETC_PATH"/package.cfg
		MSG="Monitor enabled; please restart package to make effective"
	else
		if [ $# -gt 1 ] && [ $2 = "off" ]
		then
			$SUDO sed -i -e 's~MONITOR_ENABLED.*~MONITOR_ENABLED=no~' "$ETC_PATH"/kopano/default
			$SUDO sed -i -e 's~K_MONITOR.*~K_MONITOR="OFF"~' "$ETC_PATH"/package.cfg
			MSG="Monitor disabled; please restart package to make effective"
		fi
	fi
	;;
	autoblock)
	if [ -e /etc/fail2ban ]
	then
		if [ $# -gt 1 ] && [ $2 = "on" ]
		then
			$SUDO cp "$TARGET_PATH"/merge/fail2ban/action.d/kopano4s-* /etc/fail2ban/action.d
			$SUDO cp "$TARGET_PATH"/merge/fail2ban/filter.d/kopano4s-* /etc/fail2ban/action.d
			$SUDO cp "$TARGET_PATH"/merge/fail2ban/jail.d/kopano4s-* /etc/fail2ban/action.d
			MSG="Autoblock enabled; please restart fail2ban package to make effective"
		else
			if [ $# -gt 1 ] && [ $2 = "off" ]
			then
				$SUDO rm /etc/fail2ban/action.d/kopano4s-*
				$SUDO rm /etc/fail2ban/filter.d/kopano4s-*
				$SUDO rm /etc/fail2ban/jail.d/kopano4s-*
				MSG="Autoblock disabled; please restart fail2ban package to make effective"
			fi
		fi
	else
		echo "For use of autoblock you have to install Fail2Ban4S package from cphub.net first.."
	fi
	;;
	amavis)
	if [ $# -gt 1 ] && [ $2 = "on" ]
	then
		$SUDO sed -i -e 's~AMAVISD_ENABLED.*~AMAVISD_ENABLED=yes~' "$ETC_PATH"/kopano/default
		$SUDO sed -i -e 's~K_AMAVISD.*~K_AMAVISD="ON"~' "$ETC_PATH"/package.cfg
		$SUDO sed -i -e "s~#content_filter =~content_filter =~" "$ETC_PATH"/kopano/postfix/main.cf
		$SUDO sed -i -e "s~spam_header_name = X-Spam-Status~spam_header_name = X-Spam-Flag~" "$ETC_PATH"/kopano/dagent.cfg
		$SUDO sed -i -e "s~spam_header_value = Yes,~spam_header_value = Yes~" "$ETC_PATH"/kopano/dagent.cfg
		MSG="Amavis enabled run optionals clamav on to also enable antivirus; please restart package to make effective"
	else
		if [ $# -gt 1 ] && [ $2 = "off" ]
		then
			$SUDO sed -i -e 's~AMAVISD_ENABLED.*~AMAVISD_ENABLED=no~' "$ETC_PATH"/kopano/default
			$SUDO sed -i -e 's~CLAMAVD_ENABLED.*~CLAMAVD_ENABLED=no~' "$ETC_PATH"/kopano/default
			$SUDO sed -i -e 's~K_AMAVISD.*~K_AMAVISD="OFF"~' "$ETC_PATH"/package.cfg
			$SUDO sed -i -e 's~K_CLAMAVD.*~K_CLAMAVD="OFF"~' "$ETC_PATH"/package.cfg
			$SUDO sed -i -e "s~content_filter =~#content_filter =~" "$ETC_PATH"/kopano/postfix/main.cf
			$SUDO sed -i -e "s~spam_header_name = X-Spam-Flag~spam_header_name = X-Spam-Status~" "$ETC_PATH"/kopano/dagent.cfg
			$SUDO sed -i -e "s~spam_header_value = Yes~spam_header_value = Yes,~" "$ETC_PATH"/kopano/dagent.cfg
			MSG="Amavis and dependent ClamAV disabled; please restart package to make effective"
		fi
	fi
	;;
	clamav)
	if [ $# -gt 1 ] && [ $2 = "on" ]
	then
		$SUDO sed -i -e 's~AMAVISD_ENABLED.*~AMAVISD_ENABLED=yes~' "$ETC_PATH"/kopano/default
		$SUDO sed -i -e 's~CLAMAVD_ENABLED.*~CLAMAVD_ENABLED=yes~' "$ETC_PATH"/kopano/default
		$SUDO sed -i -e 's~K_AMAVISD.*~K_AMAVISD="ON"~' "$ETC_PATH"/package.cfg
		$SUDO sed -i -e 's~K_CLAMAVD.*~K_CLAMAVD="ON"~' "$ETC_PATH"/package.cfg
		$SUDO sed -i -e "s~#content_filter =~content_filter =~" "$ETC_PATH"/kopano/postfix/main.cf
		$SUDO sed -i -e "s~spam_header_name = X-Spam-Status~spam_header_name = X-Spam-Flag~" "$ETC_PATH"/kopano/dagent.cfg
		$SUDO sed -i -e "s~spam_header_value = Yes,~spam_header_value = Yes~" "$ETC_PATH"/kopano/dagent.cfg
		MSG="ClamAV antivirus enabled together with amavis; please restart package to make effective"
	else
		if [ $# -gt 1 ] && [ $2 = "off" ]
		then
			$SUDO sed -i -e 's~CLAMAVD_ENABLED.*~CLAMAVD_ENABLED=no~' "$ETC_PATH"/kopano/default
			$SUDO sed -i -e 's~K_CLAMAVD.*~K_CLAMAVD="OFF"~' "$ETC_PATH"/package.cfg
			MSG="ClamAV disabled; please restart package to make effective"
		fi
	fi
	;;
	bounce-spam)
	if [ $# -gt 1 ] && [ $2 = "on" ]
	then
		$SUDO sed -i -e 's~BOUNCE_SPAM_ENABLED.*~BOUNCE_SPAM_ENABLED=yes~' "$ETC_PATH"/kopano/default
		$SUDO sed -i -e 's~K_BOUNCE_SPAM.*~K_BOUNCE_SPAM="ON"~' "$ETC_PATH"/package.cfg
		$SUDO sed -i -e "s~\$final_spam_destiny.*~\$final_spam_destiny       = D_BOUNCE;~" "$ETC_PATH"/kopano/default-amavis
		MSG="Bounce Spam enabled; please restart package to make effective"
	else
		if [ $# -gt 1 ] && [ $2 = "off" ]
		then
			$SUDO sed -i -e 's~BOUNCE_SPAM_ENABLED.*~BOUNCE_SPAM_ENABLED=no~' "$ETC_PATH"/kopano/default
			$SUDO sed -i -e 's~K_BOUNCE_SPAM.*~K_BOUNCE_SPAM="OFF"~' "$ETC_PATH"/package.cfg		
			$SUDO sed -i -e "s~\$final_spam_destiny.*~\$final_spam_destiny       = D_PASS;~" "$ETC_PATH"/kopano/default-amavis
			MSG="Bounce Spam disabled; please restart package to make effective"
		fi
	fi
	;;
	helo-check)
	if [ $# -gt 1 ] && [ $2 = "on" ]
	then
		$SUDO sed -i -e 's~SPAM_HELO.*~SPAM_HELO="ON"~' "$ETC_PATH"/package.cfg
		$SUDO sed -i -e "s~#smtpd_helo_restrictions~smtpd_helo_restrictions~" "$ETC_PATH"/kopano/postfix/main.cf
		MSG="Helo-Check enabled; please restart package to make effective"
	else
		if [ $# -gt 1 ] && [ $2 = "off" ]
		then
			$SUDO sed -i -e 's~SPAM_HELO.*~SPAM_HELO="OFF"~' "$ETC_PATH"/package.cfg		
			$SUDO sed -i -e "s~smtpd_helo_restrictions~#smtpd_helo_restrictions~" "$ETC_PATH"/kopano/postfix/main.cf
			MSG="Helo-Check disabled; please restart package to make effective"
		fi
	fi
	;;
	mx-check)
	if [ $# -gt 1 ] && [ $2 = "on" ]
	then
		$SUDO sed -i -e 's~SPAM_MX.*~SPAM_MX="ON"~' "$ETC_PATH"/package.cfg
		# mind the spave when enabling it in main.cf
		$SUDO sed -i -e "s~#reject_unknown_sender_domain~ reject_unknown_sender_domain~" "$ETC_PATH"/kopano/postfix/main.cf
		MSG="MX-Domain-Check enabled; please restart package to make effective"
	else
		if [ $# -gt 1 ] && [ $2 = "off" ]
		then
			$SUDO sed -i -e 's~SPAM_MX.*~SPAM_MX="OFF"~' "$ETC_PATH"/package.cfg		
			$SUDO sed -i -e "s~ reject_unknown_sender_domain~#reject_unknown_sender_domain~" "$ETC_PATH"/kopano/postfix/main.cf
			MSG="MX-Domain-Check ; please restart package to make effective"
		fi
	fi
	;;
	rbl-check)
	if [ $# -gt 1 ] && [ $2 = "on" ]
	then
		$SUDO sed -i -e 's~SPAM_RBL.*~SPAM_RBL="ON"~' "$ETC_PATH"/package.cfg
		# mind the spave when enabling it in main.cf
		$SUDO sed -i -e "s~#reject_rbl_client~ reject_rbl_client~g" "$ETC_PATH"/kopano/postfix/main.cf
		MSG="RBL-Check enabled; please restart package to make effective"
	else
		if [ $# -gt 1 ] && [ $2 = "off" ]
		then
			$SUDO sed -i -e 's~SPAM_RBL.*~SPAM_RBL="OFF"~' "$ETC_PATH"/package.cfg		
			$SUDO sed -i -e "s~ reject_rbl_client~#reject_rbl_client~g" "$ETC_PATH"/kopano/postfix/main.cf
			MSG="RBL-Check ; please restart package to make effective"
		fi
	fi
	;;
	spamd)
	if [ $# -gt 1 ] && [ $2 = "on" ]
	then
		$SUDO sed -i -e 's~SPAMD_ENABLED.*~SPAMD_ENABLED=yes~' "$ETC_PATH"/kopano/default
		$SUDO sed -i -e 's~K_SPAMD.*~K_SPAMD="ON"~' "$ETC_PATH"/package.cfg
		MSG="Spamd enabled; please restart package to make effective"
	else
		if [ $# -gt 1 ] && [ $2 = "off" ]
		then
			$SUDO sed -i -e 's~SPAMD_ENABLED.*~SPAMD_ENABLED=no~' "$ETC_PATH"/kopano/default
			$SUDO sed -i -e 's~K_SPAMD.*~K_SPAMD="OFF"~' "$ETC_PATH"/package.cfg
			MSG="Spamd disabled; please restart package to make effective"
		fi
	fi
	;;
	postgrey)
	if [ $# -gt 1 ] && [ $2 = "on" ]
	then
		$SUDO sed -i -e 's~POSTGREY_ENABLED.*~POSTGREY_ENABLED=yes~' "$ETC_PATH"/kopano/default
		$SUDO sed -i -e 's~K_POSTGREY.*~K_POSTGREY="ON"~' "$ETC_PATH"/package.cfg
		# mind the spave when enabling it in main.cf
		$SUDO sed -i -e "s~#check_policy_service~ check_policy_service~" "$ETC_PATH"/kopano/postfix/main.cf
		MSG="Postgrey enabled; please restart package to make effective"
	else
		if [ $# -gt 1 ] && [ $2 = "off" ]
		then
			$SUDO sed -i -e 's~POSTGREY_ENABLED.*~POSTGREY_ENABLED=no~' "$ETC_PATH"/kopano/default
			$SUDO sed -i -e 's~K_POSTGREY.*~K_POSTGREY="OFF"~' "$ETC_PATH"/package.cfg
			$SUDO sed -i -e "s~ check_policy_service~#check_policy_service~" "$ETC_PATH"/kopano/postfix/main.cf
			MSG="Postgrey disabled; please restart package to make effective"
		fi
	fi
	;;
	fetchmail)
	if [ $# -gt 1 ] && [ $2 = "on" ]
	then
		$SUDO sed -i -e 's~FETCHMAIL_ENABLED.*~FETCHMAIL_ENABLED=yes~' "$ETC_PATH"/kopano/default
		MSG="Fetchmail enabled; please restart package to make effective"
	else
		if [ $# -gt 1 ] && [ $2 = "off" ]
		then
			$SUDO sed -i -e 's~FETCHMAIL_ENABLED.*~FETCHMAIL_ENABLED=yes~' "$ETC_PATH"/kopano/default
			MSG="Fetchmail diabled; please restart package to make effective"
		fi
	fi
	;;
	courier-imap)
	if [ $# -gt 1 ] && [ $2 = "on" ]
	then
		$SUDO sed -i -e 's~COURIER_IMAP_ENABLED.*~COURIER_IMAP_ENABLED=yes~' "$ETC_PATH"/kopano/default
		$SUDO sed -i -e 's~K_ARCHIVE_IMAP.*~K_ARCHIVE_IMAP="ON"~' "$ETC_PATH"/package.cfg
		MSG="Courier-imap enabled; please run kopano4s-init container to make effective"
	else
		if [ $# -gt 1 ] && [ $2 = "off" ]
		then
			$SUDO sed -i -e 's~COURIER_IMAP_ENABLED.*~COURIER_IMAP_ENABLED=no~' "$ETC_PATH"/kopano/default
			$SUDO sed -i -e 's~K_ARCHIVE_IMAP.*~K_ARCHIVE_IMAP="OFF"~' "$ETC_PATH"/package.cfg
			MSG="Courier-imap disabled; please run kopano4s-init container to make effective"
		fi
	fi
	;;
	webmeetings)
	if [ $# -gt 1 ] && [ $2 = "on" ]
	then
		$SUDO sed -i -e 's~WEBMEETINGS_ENABLED.*~WEBMEETINGS_ENABLED=yes~' "$ETC_PATH"/kopano/default
		$SUDO sed -i -e 's~PRESENCE_ENABLED.*~PRESENCE_ENABLED=yes~' "$ETC_PATH"/kopano/default
		$SUDO sed -i -e 's~K_WEBMEETINGS.*~K_WEBMEETINGS="ON"~' "$ETC_PATH"/package.cfg
		MSG="Webmeetings enabled; please run kopano4s-init container to make effective"
	else
		if [ $# -gt 1 ] && [ $2 = "off" ]
		then
			$SUDO sed -i -e 's~WEBMEETINGS_ENABLED.*~WEBMEETINGS_ENABLED=no~' "$ETC_PATH"/kopano/default
			$SUDO sed -i -e 's~PRESENCE_ENABLED.*~PRESENCE_ENABLED=no~' "$ETC_PATH"/kopano/default
			$SUDO sed -i -e 's~K_WEBMEETINGS.*~K_WEBMEETINGS="OFF"~' "$ETC_PATH"/package.cfg
			MSG="Webmeetings disabled; please run kopano4s-init container to make effective"
		fi
	fi
	;;
	coturn)
	if [ $# -gt 1 ] && [ $2 = "on" ]
	then
		$SUDO sed -i -e 's~COTURN_ENABLED.*~COTURN_ENABLED=yes~' "$ETC_PATH"/kopano/default
		MSG="Coturn enabled; please run kopano4s-init container to make effective"
	else
		if [ $# -gt 1 ] && [ $2 = "off" ]
		then
			$SUDO sed -i -e 's~COTURN_ENABLED.*~COTURN_ENABLED=no~' "$ETC_PATH"/kopano/default
			MSG="Coturn disabled; please run kopano4s-init container to make effective"
		fi
	fi
	;;
	*)
	echo "provide kopano-service: gateway | ical | search | monitor | autoblock | amavis | clamav | bounce-spam | helo/mx/rbl-check | spamd | postgrey | fetchmail | courier-imap | webmeetings | coturn to set it to on or off."
	;;
esac
echo "$MSG"
exit 0