#!/bin/sh
# (c) 2018 vbettag - wraper script for devicelist via z-push-admin in Docker container
# admins only plus set sudo for DSM 6 as root login is no longer possible
LOGIN=`whoami`
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
if [ $# -gt 0 ] && [ $1 == "csv" ]
then
	CSV="YES"
else
	CSV="NO"
fi
if [ "$CSV" == "YES" ]
then
	echo "k-user, device name, last sync, attention, device-id"
else
	echo -e "k-user \t\t| device name \t| last sync \t\t\t| attention \t\t| device-id"
	echo -e "----------------------------------------------------------------------------------------------------"
fi

# send enter and skip -t as it messes up when called from perl ui
# run kopano admin command and strip of unneccessary tabs etc
DEVLST=`echo -e "\n" | $SUDO docker exec -i kopano4s /usr/share/z-push/z-push-admin.php -a list | grep -v "All synchronized" | grep -v "Device id" | grep -v "\-\-\-" | cut -d " " -f1`
for DEV in $DEVLST; do
	echo -e "\n" | $SUDO docker exec -i kopano4s /usr/share/z-push/z-push-admin.php -a list -d $DEV >/tmp/kdev
	# can have multiple users per device: nested loop
	USRLST=`grep user /tmp/kdev | cut -d ":" -f2- | sed "s~^[ \t]*~~"`
	for USR in $USRLST; do
		echo -e "\n" | $SUDO docker exec -i kopano4s /usr/share/z-push/z-push-admin.php -a list -u $USR -d $DEV >/tmp/kdev
		KUSER=`grep user /tmp/kdev | cut -d ":" -f2- | sed "s~^[ \t]*~~"`
		DNAME=`grep friendly /tmp/kdev | cut -d ":" -f2- | sed "s~^[ \t]*~~"`
		DTYPE=`grep type /tmp/kdev | cut -d ":" -f2- | sed "s~^[ \t]*~~"`
		LSYNC=`grep Last /tmp/kdev | cut -d ":" -f2- | sed "s~^[ \t]*~~"`
		ATTN=`grep Attention /tmp/kdev | cut -d ":" -f2- | sed "s~^[ \t]*~~"`
		if [ "_$DNAME" == "_" ]
		then
			DNAME=$DTYPE
		fi
		if [ "$CSV" == "YES" ]
		then
			echo "$KUSER,$DNAME,$LSYNC,$ATTN,$DEV"
		else
			# dname smaller 10 chars add extra tab
			if [ ${#DNAME} -lt 10 ]
			then
				DNAME="$DNAME\t"
			fi
			echo -e "$KUSER \t\t| $DNAME \t| $LSYNC \t| $ATTN \t| $DEV"
		fi
	done
done
if [ -e /tmp/kdev ] ; then rm /tmp/kdev ; fi
