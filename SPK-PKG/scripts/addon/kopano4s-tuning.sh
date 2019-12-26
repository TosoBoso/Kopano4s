#!/bin/sh
# (c) 2018 vbettag - script to perform tuning to mysql and kopano buffers according to available memory
# admins only plus set sudo for DSM 6 as root login is no longer possible
LOGIN=$(whoami)
if [ "$LOGIN" != "root" ]
then 
	echo "you have to run as root! alternatively as admin run with sudo prefix! exiting.."
	exit 1
fi
if [ $# -eq 0 ]
then
	echo "usage: kopano4s-tuning 10 | 20 | 40 | 60 (% of memory) | info | help"
	exit 0
fi
if [ $# -gt 0 ] && [ "$1" = "help" ]
then
	echo "usage: kopano4s-tuning 10 | 20 | 40 | 60 (% of memory) | info | help"
	echo "info provides memory overview and advise what % pattern can be used for caches." 
	echo "mySQL InnoDB Buffer is capped at 1.25GB so 4GB+ the buffer calculation is not linear."
	echo "a dedicated Kopano server should allocate up to 60% of RAM to caches or buffers:"
	echo "Kopano cache_cell_size: ~20%, cache_object_size: 200k per user (0.5-8MB),"
	echo "cache_indexedobject_size: 512k per user (2-16MB), MySQL-innodb_buffer_pool_size: ~40%,"
	echo "innodb_log_file_size: 25% of innodb_buffer_pool_size"
	exit 0
fi
# ** get library and common procedures, settings, tags and download urls
. /var/packages/Kopano4s/scripts/library
. /var/packages/Kopano4s/scripts/common
. /var/packages/Kopano4s/etc/package.cfg
if [ "$1" = "info" ]
then
	GET_MEM_INFO
	GET_MAX_TUNING_BUFFER
	TUNING_BUFFER=$MAX_TUNING_BUFFER
	GET_INNODB_BUFFER
	GET_KOPANO_BUFFER
	echo "Mem Total:${MEM_TOTAL}KB/${SYNO_MEMG}GB Cached Buffers:${MEM_CACHED}KB Free:${MEM_FREE}KB Usable:${MEM_USABLE}KB"
	echo "Max Tunig:${MAX_TUNING_BUFFER}% MySQl InnoDB-Buffer-Pool:${INNODB_BUFFER}MB InnoDB-Log-File:${INNODB_LOGFS}MB aka ${INNODB_PERCENT}%"
	echo "Kopano Cache-Cell-Size:${K_CACHE_CELL_SIZE}MB C-Object-Size:${K_CACHE_OBJECT_SIZE}MB CIndexObjSize:${K_CACHE_INDEXOBJECT_SIZE}MB aka ${KOPANO_PERCENT}%"
	exit 0
fi
if [ "$1" = "10" ] || [ "$1" = "20" ] || [ "$1" = "40" ] || [ "$1" = "60" ]
then
	GET_MEM_INFO
	GET_MAX_TUNING_BUFFER
	if [ $MAX_TUNING_BUFFER -lt $1 ]
	then
		TUNING_BUFFER=$MAX_TUNING_BUFFER
	else
		TUNING_BUFFER=$1
	fi
	GET_INNODB_BUFFER
	GET_KOPANO_BUFFER
	TOTAL_INODB=$(($INNODB_BUFFER + $INNODB_LOGFS))
	TOTAL_KOPANO=$(($K_CACHE_CELL_SIZE + $INNODB_LOGFS))
	TOTAL_PERCENT=$(($INNODB_PERCENT + $K_CACHE_OBJECT_SIZE + $K_CACHE_INDEXOBJECT_SIZE))
	echo "setting ${TUNING_BUFFER}% tuning pattern: MySQl-Buffers:${TOTAL_INODB}MB Kopano-Buffers:${TOTAL_KOPANO}MB aka total ${TOTAL_PERCENT}% of ${SYNO_MEMG}GB"
	SET_MYSQL_BUFFER
	SET_KOPANO_BUFFER
	SET_PKG_CFG_BUFFER
	exit 0
fi
echo "no valid parameters provided: kopano4s-tuning 10 | 20 | 40 | 60 (% of memory)"
exit 1