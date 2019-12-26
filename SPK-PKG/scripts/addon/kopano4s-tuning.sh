#!/bin/sh
# (c) 2018 vbettag - script to perform tuning to mysql and kopano buffers according to available memory
# admins only plus set sudo for DSM 6 as root login is no longer possible
if [ $# -eq 0 ]
then
	echo "usage: kopano4s-tuning 20 | 40 | 60 (% of memory) | info | help"
	exit 0
fi
if [ $# -gt 0 ] && [ "$1" = "help" ]
then
	echo "usage: kopano4s-tuning 20 | 40 | 60 (% of memory) | info | help"
	echo "info provides memory overview and advise what % pattern can be used for caches." 
	echo "mySQL InnoDB Buffer is capped at 1.25GB so 4GB+ the buffer calculation is not linear."
	echo "A dedicated server should allocate up to 60% of RAM to caches: Kopano cache_cell_size: ~20%, cache_object_size: 100k per user (0.5-2MB),"
	echo "cache_indexedobject_size: 512k per user (2-8MB), MySQL-innodb_buffer_pool_size: ~40%, innodb_log_file_size: 25% of innodb_buffer_pool"
	exit 0
fi
if [ $# -gt 0 ] && [ "$1" = "list" ]
then
LOGIN=$(whoami)
if ! (grep administrators /etc/group | grep -q "$LOGIN")
then 
	echo "admins only"
	exit 1
fi
MAJOR_VERSION=$(grep majorversion /etc.defaults/VERSION | grep -o [0-9])
if [ $MAJOR_VERSION -gt 5 ] && [ $LOGIN != "root" ]
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


#$SUDO
exit 0