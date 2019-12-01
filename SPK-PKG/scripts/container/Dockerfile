# multistaged dockerfile with options to stop build at iterim container or use web-repo running interim in dummy mode
# start with itermediate container to build the kopano local repo so we do not expose SNR and URL and keep the target slim
# this interim is no slim container as we need to collect locale kopano.mo LC_MESSAGES in /usr/share/locale/lang to copy over
# default build with copy repo from intermediate for tuning once web-repo is extracted call it with --build-arg ENV_BUILD=web-repo
ARG ENV_BUILD=copy-repo
FROM debian:stretch as k4s-intermediate
ARG EDITION
ARG PHP_VER
ARG ENV_BUILD
ARG	DEFAULT_BUILD
ARG	MIGRATION_BUILD
ARG	SUPPORTED_BUILD
ARG	COMMUNITY_BUILD
ARG	K_SNR
ARG	DOCKER_HOST
ENV TERM=ansi
ENV DEBIAN_FRONTEND=noninteractive
ENV PHP_VER=${PHP_VER:-7.0}
# set dependent on build arguments the urls + if arg switch was set and - is if null; build staggered and if all null set default community
ENV ENV_BUILD=${ENV_BUILD}
ENV EDITION=${DEFAULT_BUILD:+Default}
ENV EDITION=${EDITION:-${MIGRATION_BUILD:+Migration}}
ENV EDITION=${EDITION:-${SUPPORTED_BUILD:+Supported}}
ENV EDITION=${EDITION:-Community}
ENV URL_Z_PUSH=${MIGRATION_BUILD:+http://repo.z-hub.io/z-push:/old-final/Debian_9.0/all/}
ENV URL_Z_PUSH=${URL_Z_PUSH:-http://repo.z-hub.io/z-push:/final/Debian_9.0/all/}
ENV	URL_CORE=${DEFAULT_BUILD:+https://serial:${K_SNR}@download.kopano.io/supported/core:/final/tarballs/archives/}
ENV URL_CORE=${URL_CORE:-${MIGRATION_BUILD:+https://serial:${K_SNR}@download.kopano.io/supported/core:/final/tarballs/archives/}}
ENV URL_CORE=${URL_CORE:-${SUPPORTED_BUILD:+https://serial:${K_SNR}@download.kopano.io/supported/core:/final/tarballs/}}
ENV URL_CORE=${URL_CORE:-https://download.kopano.io/community/core:/}
ENV NAME_CORE=${DEFAULT_BUILD:+8.7.1.0_0+1-Debian_9.0-amd64.tar.gz}
ENV NAME_CORE=${NAME_CORE:-${MIGRATION_BUILD:+8.4.5.0_0+33-Debian_9.0-amd64.tar.gz}}
ENV NAME_CORE=${NAME_CORE:-Debian_9.0-amd64.tar.gz}
ENV URL_WEBAPP=${DEFAULT_BUILD:+https://serial:${K_SNR}@download.kopano.io/supported/webapp:/final/tarballs/archives/}
ENV URL_WEBAPP=${URL_WEBAPP:-${MIGRATION_BUILD:+https://serial:${K_SNR}@download.kopano.io/supported/webapp:/final/tarballs/archives/}}
ENV URL_WEBAPP=${URL_WEBAPP:-${SUPPORTED_BUILD:+https://serial:${K_SNR}@download.kopano.io/supported/webapp:/final/tarballs/}}
ENV URL_WEBAPP=${URL_WEBAPP:-https://download.kopano.io/community/webapp:/}
ENV NAME_WEBAPP=${DEFAULT_BUILD:+3.5.6.2298+94-Debian_9.0-all.tar.gz}
ENV NAME_WEBAPP=${NAME_WEBAPP:-${MIGRATION_BUILD:+3.4.24.1929+84-Debian_9.0-all.tar.gz}}
ENV NAME_WEBAPP=${NAME_WEBAPP:-Debian_9.0-all.tar.gz}
ENV URL_MDM=${DEFAULT_BUILD:+https://serial:${K_SNR}@download.kopano.io/supported/mdm:/final/tarballs/}
ENV URL_MDM=${URL_MDM:-${SUPPORTED_BUILD:+https://serial:${K_SNR}@download.kopano.io/supported/mdm:/final/tarballs/}}
ENV URL_MDM=${URL_MDM:-https://download.kopano.io/community/mdm:/}
ENV NAME_MDM="Debian_9.0-all.tar.gz"
ENV URL_SMIME=${DEFAULT_BUILD:+https://serial:${K_SNR}@download.kopano.io/supported/smime:/final/tarballs/}
ENV URL_SMIME=${URL_SMIME:-${SUPPORTED_BUILD:+https://serial:${K_SNR}@download.kopano.io/supported/smime:/final/tarballs/}}
ENV URL_SMIME=${URL_SMIME:-https://download.kopano.io/community/smime:/}
ENV NAME_SMIME="Debian_9.0-amd64.tar.gz"
ENV	URL_UBCORE=${DEFAULT_BUILD:+https://serial:${K_SNR}@download.kopano.io/supported/core:/final/tarballs/archives/}
ENV URL_UBCORE=${URL_UBCORE:-${URL_CORE:-${SUPPORTED_BUILD:+https://serial:${K_SNR}@download.kopano.io/supported/core:/final/tarballs/}}}
ENV URL_UBCORE=${URL_UBCORE:-https://download.kopano.io/community/core:/}
ENV NAME_UBCORE=${DEFAULT_BUILD:+8.6.9.0_0+24-Ubuntu_18.04-amd64.tar.gz}
ENV NAME_UBCORE=${NAME_UBCORE:-Ubuntu_18.04-amd64.tar.gz}
ENV URL_UBSMIME=${DEFAULT_BUILD:+https://serial:${K_SNR}@download.kopano.io/supported/smime:/final/tarballs/}
ENV URL_UBSMIME=${URL_UBSMIME:-${SUPPORTED_BUILD:+https://serial:${K_SNR}@download.kopano.io/supported/smime:/final/tarballs/}}
ENV URL_UBSMIME=${URL_UBSMIME:-https://download.kopano.io/community/smime:/}
ENV NAME_UBSMIME="Ubuntu_18.04-all.tar.gz"
ENV URL_WEBMEET=${DEFAULT_BUILD:+https://serial:${K_SNR}@download.kopano.io/supported/webmeetings:/final/tarballs/}
ENV URL_WEBMEET=${URL_WEBMEET:-${SUPPORTED_BUILD:+https://serial:${K_SNR}@download.kopano.io/supported/webmeetings:/final/tarballs/}}
ENV URL_WEBMEET=${URL_WEBMEET:-https://download.kopano.io/community/webmeetings:/}
ENV NAME_WEBMEET="Debian_9.0-amd64.tar.gz"
ENV URL_FILES=${DEFAULT_BUILD:+https://serial:${K_SNR}@download.kopano.io/supported/files:/final/tarballs/archives/}
ENV URL_FILES=${URL_FILES:-${SUPPORTED_BUILD:+https://serial:${K_SNR}@download.kopano.io/supported/files:/final/tarballs/}}
ENV URL_FILES=${URL_FILES:-https://download.kopano.io/community/files:/}
ENV NAME_FILES=${DEFAULT_BUILD:+2.1.4.293-Debian_9.0-all.tar.gz}
ENV NAME_FILES=${NAME_FILES:-Debian_9.0-all.tar.gz}
ENV URL_MATMOST=""
ENV NAME_MATMOST=""
ENV URL_DOCED=""
ENV NAME_DOCED=""
ENV URL_PASSWD="https://github.com/dducret/kopano-webapp-passwd/raw/master/builds/passwd-1.5.zip"
ENV URL_G2FA="https://www.familiethimm.de/download/2525/"
ENV URL_PFETCHM="https://github.com/olia-dev/kopano-webapp-fetchmail/raw/master/builds/fetchmail-1.0.2.zip"

# layer 1 steps 3-18 or 19: create trusted local kopano repository
RUN echo "** use an interim container to build trusted local repo for kopano $EDITION to tranfer into main container.."
# debug only RUN echo "** $EDITION C: $URL_CORE $NAME_CORE W: $URL_WEBAPP $NAME_WEBAPP M: $URL_MDM $NAME_MDM S: $URL_SMIME $NAME_SMIME WM: $URL_WEBMEET $NAME_WEBMEET F: $URL_FILES $NAME_FILES"
RUN apt-get update -y > /etc/update.list && apt-get install -y --no-install-recommends wget apt-utils locales unzip
# stretch-security: prepare repo standad structure with main for creating hashed packages and release files
RUN	chmod 711 /root && mkdir -p /root/repo &&  mkdir -p /root/repo/dists && mkdir -p /root/repo/dists/kopano && \ 
	mkdir -p /root/repo/dists/kopano/main && mkdir -p /root/repo/dists/kopano/main/binary-amd64 && \
	echo "Dir::ArchiveDir \"/root/repo\"; Dir::CacheDir \"/root/repo\";" >/root/repo/aptgenerate.conf && \
	echo "Default::Packages::Extensions \".deb\"; Default::Packages::Compress \". gzip\";" >>/root/repo/aptgenerate.conf && \
	echo "Default::Sources::Compress \"gzip\"; Default::Contents::Compress \"gzip\";" >>/root/repo/aptgenerate.conf && \
	echo "BinDirectory \"/root/repo/dists/kopano/main/binary-amd64\" { Packages \"/root/repo/dists/kopano/main/binary-amd64/Packages\"; Contents \"/root/repo/dists/kopano/main/Contents-amd64\"; };" >>/root/repo/aptgenerate.conf && \
	echo "Tree \"/root/repo/dists/kopano\" { Sections \"main\"; Architectures \"amd64\"; };" >>/root/repo/aptgenerate.conf && \
	echo "APT::FTPArchive::Release {" >/root/repo/aptftp.conf && \
	echo " Origin \"Kopano\"; Label \"Kopano core\"; Suite \"kopano\"; Components \"main\"; Architectures \"amd64\"; };" >>/root/repo/aptftp.conf
# copy config and init.d files as on latest versions they are missing (KC-681)
COPY /container/*.tgz /root/repo/
RUN tar -zxvf /root/repo/kinit.tgz -C /root/repo && tar -zxvf /root/repo/kopano-cfg.tgz -C /root/repo && rm /root/repo/*.tgz
WORKDIR /root/repo
RUN if [ ! -e /usr/share/locale/locale.alias ] ; then ln -s /etc/locale.alias /usr/share/locale/locale.alias ; fi
RUN sed -i -e "s~# en_US.UTF-8~en_US.UTF-8~" /etc/locale.gen && dpkg-reconfigure locales 
# downloading packages and packing everything into a local apt repository incl. deb [trusted=yes]
RUN echo "Env-build: $ENV_BUILD"
RUN if [ "$ENV_BUILD" != "web-repo" ] ; then wget --no-check-certificate --quiet -p -r -nc -nd -l 1 -e robots=off -A deb $URL_Z_PUSH ; fi
# download tar.gz file via recursive and named file end then extract the gz file to archive
RUN if [ "$ENV_BUILD" != "web-repo" ] ; then wget --no-check-certificate --quiet -p -r -nc -nd -l 1 -e robots=off -A $NAME_CORE $URL_CORE && \
	tar -zxvf *.gz -C /root/repo/dists/kopano/main/binary-amd64 --strip-components=1 && rm *.gz ; fi
RUN if [ "$ENV_BUILD" != "web-repo" ] ; then wget --no-check-certificate --quiet -p -r -nc -nd -l 1 -e robots=off -A $NAME_WEBAPP $URL_WEBAPP && \
	tar -zxvf *.gz -C /root/repo/dists/kopano/main/binary-amd64 --strip-components=1 && rm *.gz ; fi
RUN if [ "$ENV_BUILD" != "web-repo" ] ; then wget --no-check-certificate --quiet -p -r -nc -nd -l 1 -e robots=off -A $NAME_MDM $URL_MDM && \
	tar -zxvf *.gz -C /root/repo/dists/kopano/main/binary-amd64 --strip-components=1 && rm *.gz ; fi
RUN if [ "$ENV_BUILD" != "web-repo" ] ; then echo "wget --no-check-certificate --quiet -p -r -nc -nd -l 1 -e robots=off -A $NAME_MDM $URL_MDM" ; fi
RUN if [ "$ENV_BUILD" != "web-repo" ] ; then wget --no-check-certificate --quiet -p -r -nc -nd -l 1 -e robots=off -A $NAME_MDM $URL_MDM && \
	tar -zxvf *.gz -C /root/repo/dists/kopano/main/binary-amd64 --strip-components=1 && rm *.gz ; fi
RUN if [ "$ENV_BUILD" != "web-repo" ] ; then wget --no-check-certificate --quiet -p -r -nc -nd -l 1 -e robots=off -A $NAME_SMIME $URL_SMIME && \
	tar -zxvf *.gz -C /root/repo/dists/kopano/main/binary-amd64 --strip-components=1 && rm *.gz ; fi
RUN if [ "$ENV_BUILD" != "web-repo" ] && [ "$PHP_VER" != "7.0" ] ; then wget --no-check-certificate --quiet -p -r -nc -nd -l 1 -e robots=off -A $NAME_UBCORE $URL_UBCORE && \
	tar -zxvf *.gz -C /root/repo/dists --strip-components=1 && rm *.gz ; fi
RUN if [ "$ENV_BUILD" != "web-repo" ] && [ "$PHP_VER" != "7.0" ] ; then rm /root/repo/dists/kopano/main/binary-amd64/php7-mapi* && cp /root/repo/dists/php7-mapi* /root/repo/dists/kopano/main/binary-amd64 && rm /root/repo/dists/*.deb ; fi
RUN wget --no-check-certificate --quiet -p -r -nc -nd -l 1 -e robots=off -A $NAME_SMIME $URL_SMIME && \
	tar -zxvf *.gz -C /root/repo/dists --strip-components=1 && rm *.gz  ; fi
RUN if [ "$ENV_BUILD" != "web-repo" ] && [ "$PHP_VER" != "7.0" ] ; then rm /root/repo/dists/kopano/main/binary-amd64/*plugin-smime* && cp /root/repo/dists/*plugin-smime* /root/repo/dists/kopano/main/binary-amd64 && rm /root/repo/dists/*.deb ; fi
RUN if [ "$ENV_BUILD" != "web-repo" ] ; then wget --no-check-certificate --quiet -p -r -nc -nd -l 1 -e robots=off -A $NAME_WEBMEET $URL_WEBMEET && \
	tar -zxvf *.gz -C /root/repo/dists/kopano/main/binary-amd64 --strip-components=1 && rm *.gz ; fi
RUN if [ "$ENV_BUILD" != "web-repo" ] ; then wget --no-check-certificate --quiet -p -r -nc -nd -l 1 -e robots=off -A $NAME_FILES $URL_FILES && \
	tar -zxvf *.gz -C /root/repo/dists/kopano/main/binary-amd64 --strip-components=1 && rm *.gz ; fi
RUN if [ "$ENV_BUILD" != "web-repo" ] ; then mv -f *.deb /root/repo/dists/kopano/main/binary-amd64 ; fi
# now get non core kopano plugins from github and familiethimm.de: passwd, fetchmail, google2fa
RUN if [ "$ENV_BUILD" != "web-repo" ] ; then mkdir -p /root/repo/plugins && wget --no-check-certificate --quiet $URL_PASSWD -O /root/repo/plugins/passwd.zip && \
	unzip /root/repo/plugins/passwd.zip -d /root/repo/plugins/passwd && sed -i -e "s~>1.3~>1.5~" /root/repo/plugins/passwd/manifest.xml && rm /root/repo/plugins/passwd.zip ; fi
RUN if [ "$ENV_BUILD" != "web-repo" ] ; then wget --no-check-certificate --quiet $URL_G2FA -O /root/repo/plugins/google2fa.zip && \
	unzip /root/repo/plugins/google2fa.zip -d /root/repo/plugins && rm /root/repo/plugins/google2fa.zip && \
	mv /root/repo/plugins/google2fa/config_default.php /root/repo/plugins/google2fa/config.php && \
	#sed -i -e "s~define('PLUGIN_GOOGLE2FA_ENABLE'.*~define('PLUGIN_GOOGLE2FA_ENABLE', false);"~ /root/repo/plugins/google2fa/config.php && \
	sed -i -e "s~define('PLUGIN_GOOGLE2FA_WHITELIST'.*~define('PLUGIN_GOOGLE2FA_WHITELIST', '192.168.0.0/16,127.0.0.1');"~ /root/repo/plugins/google2fa/config.php ; fi
RUN if [ "$ENV_BUILD" != "web-repo" ] ; then wget --no-check-certificate --quiet $URL_PFETCHM -O /root/repo/plugins/fetchmail.zip && \
	unzip /root/repo/plugins/fetchmail.zip -d /root/repo/plugins && rm /root/repo/plugins/fetchmail.zip && \
	mv /root/repo/plugins/fetchmail/example.config.php /root/repo/plugins/fetchmail/config.php && \
	mv /root/repo/plugins/fetchmail/kopano_fetchmail.service.example /root/repo/plugins/fetchmail/kopano_fetchmail.service ; fi
RUN	echo "** create trusted local repository to comply with stretch-security which takes some time.." && \
	apt-ftparchive generate -c=/root/repo/aptftp.conf /root/repo/aptgenerate.conf && \
	apt-ftparchive release -c=/root/repo/aptftp.conf /root/repo/dists/kopano/main >/root/repo/dists/kopano/main/Release
RUN echo "now do minimal build to collect kopano.mo in LC_MESSAGES of /usr/share/locale/lang used in target slim container.."
RUN chmod 711 /root && echo "deb [trusted=yes] file:/root/repo kopano main" > /etc/apt/sources.list.d/kopano.list
RUN if [ "$ENV_BUILD" != "web-repo" ] ; then apt-get update -y > /etc/update.list && apt-get install --allow-unauthenticated --assume-yes kopano-lang ; fi
RUN if [ "$ENV_BUILD" != "web-repo" ] ; then LANGS="de fr es it nl" && for L in $LANGS ; do mkdir -p /root/repo/locale/$L/LC_MESSAGES && \
	cp /usr/share/locale/$L/LC_MESSAGES/kopano.mo /root/repo/locale/$L/LC_MESSAGES; done ; fi
WORKDIR /root
RUN rm /root/repo/dists/kopano/main/Contents-amd64.gz && rm /root/repo/packages-amd64.db
RUN tar -zcvf k4s-${EDITION}-repo.tgz repo/
RUN	echo "** completed interim build for ${EDITION} edition **"

# Two different containers as baseline for main container: 1st one uses copy from intermediate other uses web-repo which saves ~50MB
FROM debian:stretch-slim as k4s-copy-repo
ARG EDITION
ENV EDITION=${EDITION:-Community}
ONBUILD COPY --from=k4s-intermediate /root/k4s-${EDITION}-repo.tgz /root/k4s-${EDITION}-repo.tgz

FROM debian:stretch-slim as k4s-web-repo
ARG EDITION
ONBUILD RUN echo "No copy of repo from intermediate container but using web-repo"

# now the main container in which we copy the local repo from interim container
FROM k4s-${ENV_BUILD} as k4s-main
MAINTAINER vbettag "tosoboso@web.de"
# set arg and env variables plus DEBIAN_FRONTEND to noninteractive
ARG EDITION
ARG	BUILD
ARG TAG
ARG	PARENT
ARG	WEBREPO
ARG	PHP_VER
ENV BUILD=${Build} \
	EDITION=${EDITION:-Community} \
	TAG="$TAG" \
	PHP_VER=${PHP_VER:-7.0} \
	PARENT="$PARENT" \
	WEBREPO="$WEBREPO" \
	LANG="en_GB.UTF-8" \
	LANGUAGE="en_GB.UTF-8" \
	LC_ALL="en_GB.UTF-8" \
	TIMEZONE="CET" \
	TERM=ansi \
	DEBIAN_FRONTEND=noninteractive
WORKDIR /root
COPY /container/dpkg-remove /root/dpkg-remove
COPY /container/*.png /root/
COPY /container/*.sh /usr/local/bin/
RUN PASSWD="openssl rand -base64 32"
# layer 2 step 16 or 17: merging run layers to save space in nested docker file system
RUN echo "** setup debian system basics incl. nginx, php-${PHP_VER} then postfix, fetchmail, amavisd, spamassassin, clamav, postgrey...." && \ 
	apt-get update -y > /etc/update.list && apt-get install -y --no-install-recommends --assume-yes \ 
	wget locales apt-transport-https ssl-cert ca-certificates rsyslog dialog nginx-light && \
	# remove nginx files and prepare for php7.x-fpm instead of php-fpm which is 7.0 EOL
	rm /etc/nginx/sites-enabled/default && rm /var/www/html/index.nginx-debian.html && \
	wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg && \
	if [ "$PHP_VER" != "7.0" ] ; then echo "deb https://packages.sury.org/php/ stretch main" > /etc/apt/sources.list.d/php.list ; fi && \
	apt-get update -y > /etc/update.list && apt-get install -y --no-install-recommends php${PHP_VER}-fpm && \
	# set locales GB/US UTF-8 and DE plus CET timezone plus optional other locale at build time
	sed -i -e "s~# en_GB.UTF-8~en_GB.UTF-8~" /etc/locale.gen && sed -i -e "s~# en_US.UTF-8~en_US.UTF-8~" /etc/locale.gen && \
	sed -i -e "s~# de_DE.UTF-8~de_DE.UTF-8~" /etc/locale.gen && \
	if [ ! -e /usr/share/locale/locale.alias ] ; then ln -s /etc/locale.alias /usr/share/locale/locale.alias ; fi && \
	ln -sf /usr/share/zoneinfo/"$TIMEZONE" /etc/localtime && dpkg-reconfigure locales && dpkg-reconfigure tzdata && \
	if echo $EDITION | grep -q "Supported" ; then touch /etc/K_SUPPORTED ; else touch /etc/K_COMMUNITY ; fi && \
	groupmod -g 1023 www-data && usermod -u 1023 -g 1023 www-data && mkdir -p /var/lib/postgrey/ && \ 
	apt-get install -y --allow-unauthenticated --no-install-recommends --assume-yes \
	postfix pflogsumm libsasl2-modules fetchmail amavisd-new spamassassin postgrey clamav-daemon clamav-freshclam \
	# more perl and zip libraries for scanning
	libnet-dns-perl libmail-spf-perl pyzor razor arj bzip2 cabextract cpio file gzip nomarch pax unzip zoo zip zoo && rm -rf /var/lib/apt/lists/* && \
# if web-repo arg is provided do wget instead of copying from interactive container which is saving ~100MB image size
	if [ -n "$WEBREPO" ] ; then wget "$WEBREPO"/k4s-${EDITION}-repo.tgz ; fi && \ 
# layer 2 step 8 or 9 prepare, download and install kopano
	echo "** setup kopano: user, download, install core, licensed, webmeetings incl. add-ons, z-push incl. autodiscover...." && \
	groupadd -g 65540 kopano && useradd -u 1030 -g 65540 -p$PASSWD -M kopano && \
	usermod -d/usr/share/kopano kopano -s/bin/false -c'kopano demon with Synology UID' && usermod -Gkopano -a root && \
	# change usr-grp-ids and add scanner users to respective groups to allow file handling for amavis under kopano
	groupmod -g 130 amavis && usermod -u 130 -g 130 amavis && groupmod -g 129 clamav && usermod -u 129 -g 129 clamav && \
	groupmod -g 128 debian-spamd && usermod -u 128 -g 128 debian-spamd && groupmod -g 127 postgrey && usermod -u 127 -g 127 postgrey && \
	usermod -u 126 fetchmail && groupmod -g 125 postfix && usermod -u 125 -g 125 postfix && \
	adduser clamav amavis && adduser amavis clamav && adduser amavis debian-spamd && adduser debian-spamd amavis && \
	adduser clamav kopano && adduser amavis kopano && adduser debian-spamd kopano && \ 
# create z-push directories for etc and state plus and set the ownership
	mkdir -p /var/log/kopano && mkdir -p /var/log/kopano/z-push && ln -sf /var/log/kopano/z-push /var/log/z-push && \
	mkdir -p /etc/kopano && mkdir -p /etc/kopano/web && mkdir -p /etc/z-push  && mkdir -p /var/lib/z-push && \
	chown -R www-data.kopano /var/log/kopano/z-push && chown -R www-data.kopano /etc/z-push && chown -R www-data.www-data /var/lib/z-push && \
# install kopano, z-push, webapp and plugins using pepo from interim build incl. kopano.mo locales for localized mail-folders
	chmod 711 /root && echo "deb [trusted=yes] file:/root/repo kopano main" > /etc/apt/sources.list.d/kopano.list && \
	tar -zxvf /root/k4s-${EDITION}-repo.tgz -C /root && rm /root/k4s-${EDITION}-repo.tgz && \
# copy config and init.d files as on latest versions they are missing (KC-681); dual-cfg triggers error so not for old Migration
	if [ "$EDITION" != "Migration" ] ; then cp /root/repo/kinit.d/* /etc/init.d/ && mkdir -p /etc/kopano && cp /root/repo/kopano.cfg/* /etc/kopano ; fi && \
# presence and webmeetings still have cfg and init shiped so delete them, for search as default version also delete it
	#if [ "$EDITION" = "Default" ] && [ -e /etc/init.d/kopano-spooler ] ; then rm /etc/init.d/kopano-spooler ; fi && \
	#if [ "$EDITION" = "Default" ] && [ -e /etc/kopano/spooler.cfg ] ; then rm /etc/kopano/spooler.cfg ; fi && \
	#if [ "$EDITION" = "Default" ] && [ -e /etc/init.d/kopano-search ] ; then rm /etc/init.d/kopano-search ; fi && \
	#if [ "$EDITION" = "Default" ] && [ -e /etc/kopano/search.cfg ] ; then rm /etc/kopano/search.cfg ; fi && \
	#if [ "$EDITION" = "Default" ] && [ -e /etc/init.d/kopano-presence ] ; then rm /etc/init.d/kopano-presence ; fi && \
	#if [ "$EDITION" = "Default" ] && [ -e /etc/kopano/presence.cfg ] ; then rm /etc/kopano/presence.cfg ; fi && \
	if [ -e /etc/init.d/kopano-webmeetings ] ; then rm /etc/init.d/kopano-webmeetings ; fi && \
	if [ -e /etc/kopano/webmeetings.cfg ] ; then rm /etc/kopano/webmeetings.cfg ; fi && \
	if [ -e /root/repo/locale/de ] ; then cp -R /root/repo/locale/* /usr/share/locale ; fi && \
	apt-get update -y > /etc/update.list && apt-get install --no-install-recommends --allow-unauthenticated --assume-yes \ 
	kopano-server-packages kopano-migration-imap kopano-migration-pst \
	z-push-kopano z-push-kopano-gabsync z-push-kopano-gab2contacts z-push-autodiscover \
	kopano-webapp \
	kopano-webapp-plugin-contactfax \
	kopano-webapp-plugin-desktopnotifications \
	kopano-webapp-plugin-filepreviewer \
	kopano-webapp-plugin-folderwidgets \
	kopano-webapp-plugin-gmaps \
	kopano-webapp-plugin-intranet \
	kopano-webapp-plugin-mdm \
	kopano-webapp-plugin-pimfolder \
	kopano-webapp-plugin-quickitems \
	kopano-webapp-plugin-smime \
	kopano-webapp-plugin-spell-en \
	kopano-webapp-plugin-spell-de-de \
	kopano-webapp-plugin-spell-es \
	kopano-webapp-plugin-spell-fr \
	kopano-webapp-plugin-spell-it \
	kopano-webapp-plugin-spell-nl \
	kopano-webapp-plugin-titlecounter \
	kopano-webapp-plugin-webappmanual && \
# full package installs not part of migration package
	if [ "$EDITION" != "Migration" ] ; then apt-get install --no-install-recommends --allow-unauthenticated --assume-yes kopano-spamd kopano-presence kopano-webmeetings kopano-webapp-plugin-meetings ; fi && \
# 4later	mattermost-server kopano-webapp-plugin-mattermost \
	if [ "$EDITION" != "Migration" ] ; then apt-get install --no-install-recommends --allow-unauthenticated --assume-yes kopano-webapp-plugin-files kopano-webapp-plugin-filesbackend-smb kopano-webapp-plugin-filesbackend-owncloud ; fi && \
# copy over non core kopano plugins
	if [ -e /root/repo/plugins ] ; then cp -R /root/repo/plugins /usr/share/kopano-webapp ; fi && \
# layer 3 upgrade and cleanup: remove obsolete packages and config, autoremove, move and softlink stuff
	apt-get upgrade --no-install-recommends --allow-unauthenticated --assume-yes && \
	rm -rf /var/lib/apt/lists/* /root/repo && \
	#if [ "$PHP_VER" != "7.0" ] ; then dpkg-query -Wf '${Package}\n' | grep php7.0 >> dpkg-remove ; fi && \
	apt-get remove -y --assume-yes $(grep -vE "^\s*#" dpkg-remove | tr "\n" " ") && \
	apt-get autoremove -y  && \
	dpkg --list | grep "^rc" | cut -d " " -f 3 | xargs --no-run-if-empty dpkg --purge  && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /etc/apt/sources.list.d/kopano.list /root/dpkg-remove && chmod 755 /etc/init.d/kopano-* && \
# add touch, chmod PIDFILE to kopano service init files and change stop on name instead of exec, special case: search, spamd with pyton
	if [ "$EDITION" != "Community" ] ; then K_SRVS=`ls /etc/init.d/kopano-*` && for S in $K_SRVS; do sed -i -e "s~start-stop-daemon --start \$QUIETDAEMON~touch \$PIDFILE \&\& chown kopano.kopano \$PIDFILE \n\tstart-stop-daemon --start \$QUIETDAEMON~" $S && \
	sed -i -e "s~start-stop-daemon --stop \$QUIETDAEMON.*~start-stop-daemon --stop \$QUIETDAEMON --pidfile \$PIDFILE --name \$NAME --retry TERM/15/KILL >/dev/null~g" $S ; done ; fi && \
# new 'bug/feature' community edition: spooler etc hang unless -b = background is used in init.d file have to remoce -d falg for dagent in default
	if [ "$EDITION" = "Community" ] ; then K_SRVS="kopano-server kopano-spooler kopano-dagent kopano-gateway kopano-ical kopano-monitor" && for S in $K_SRVS; do sed -i -e "s~start-stop-daemon --start~start-stop-daemon --start -b~" /etc/init.d/$S && \ 
    sed -i -e "s~start-stop-daemon --stop \$QUIETDAEMON.*~start-stop-daemon --stop \$QUIETDAEMON --pidfile \$PIDFILE --name \$NAME --retry TERM/15/KILL >/dev/null~g" /etc/init.d/$S ; done ; fi && \
# new 'bug/feature' supported & community edition: search, spamd config paramter flipped from -c to -C
	if [ "$EDITION" = "Community" ] ; then sed -i -e "s~-c \$SEARCH_CONFIG~-C \$SEARCH_CONFIG~" /etc/init.d/kopano-search ; fi && \
	if [ "$EDITION" = "Community" ] ; then sed -i -e "s~-c \$SPAMD_CONFIG~-C \$SPAMD_CONFIG~" /etc/init.d/kopano-spamd ; fi && \
	if [ "$EDITION" = "Community" ] ; then sed -i -e "s~-c \$PRESENCE_CONFIG~-C \$PRESENCE_CONFIG~" /etc/init.d/kopano-presence ; fi && \
# search, spamd presence now running with /usr/bin/python3 hence replace --exec /usr/bin/python $SEARCH by --name $NAME
# search add searchm.pid as it take quite long until search writes search.pid (same applies for spamd, presence)
	if [ -e /etc/init.d/kopano-search ] ; then sed -i -e "s~/usr/bin/python ~~" /etc/init.d/kopano-search ; fi && \
	if [ -e /etc/init.d/kopano-search ] ; then sed -i -e "s~search.pid~searchm.pid~" /etc/init.d/kopano-search && sed -i -e "s~--name \$NAME ~~g" /etc/init.d/kopano-search ; fi && \
	if [ -e /etc/init.d/kopano-search ] ; then sed -i -e "s~unset LC_ALL~PID=\`ps -ef | grep \$SEARCH | head -1 | awk '{print \$2}'\` \&\& echo \$PID > \$PIDFILE\n\tunset LC_ALL~" /etc/init.d/kopano-search ; fi && \
	if [ -e /etc/init.d/kopano-search ] ; then sed -i -e "s~start-stop-daemon --stop \$QUIETDAEMON.*~start-stop-daemon --stop \$QUIETDAEMON --pidfile \$PIDFILE --name \$NAME --retry TERM/15/KILL >/dev/null~g" /etc/init.d/kopano-search ; fi && \
	if [ -e /etc/init.d/kopano-spamd ] ; then sed -i -e "s~/usr/bin/python ~~" /etc/init.d/kopano-spamd ; fi && \
	if [ -e /etc/init.d/kopano-spamd ] ; then sed -i -e "s~spamd.pid~spamdm.pid~" /etc/init.d/kopano-spamd && sed -i -e "s~--name \$NAME ~~g" /etc/init.d/kopano-spamd ; fi && \
	if [ -e /etc/init.d/kopano-spamd ] ; then sed -i -e "s~unset LC_ALL LANG~PID=\`ps -ef | grep \$SPAMD | head -1 | awk '{print \$2}'\` \&\& echo \$PID > \$PIDFILE\n\tunset LC_ALL LANG~" /etc/init.d/kopano-spamd ; fi && \
	if [ -e /etc/init.d/kopano-spamd ] ; then sed -i -e "s~start-stop-daemon --stop \$QUIETDAEMON.*~start-stop-daemon --stop \$QUIETDAEMON --pidfile \$PIDFILE --name \$NAME --retry TERM/15/KILL >/dev/null~g" /etc/init.d/kopano-spamd ; fi && \
	if [ -e /etc/init.d/kopano-presence ] ; then sed -i -e "s~/usr/bin/python ~~" /etc/init.d/kopano-presence ; fi && \
	if [ -e /etc/init.d/kopano-presence ] ; then sed -i -e "s~presence.pid~presencem.pid~" /etc/init.d/kopano-presence && sed -i -e "s~--name \$NAME ~~g" /etc/init.d/kopano-presence ; fi && \
	if [ -e /etc/init.d/kopano-presence ] ; then sed -i -e "s~unset LC_ALL~PID=\`ps -ef | grep \$PRESENCE | head -1 | awk '{print \$2}'\` \&\& echo \$PID > \$PIDFILE\n\tunset LC_ALL~" /etc/init.d/kopano-presence ; fi && \
	if [ -e /etc/init.d/kopano-presence ] ; then sed -i -e "s~start-stop-daemon --stop \$QUIETDAEMON.*~start-stop-daemon --stop \$QUIETDAEMON --pidfile \$PIDFILE --name \$NAME --retry TERM/15/KILL >/dev/null~g" /etc/init.d/kopano-presence ; fi && \
# exclude userscripts from exposed mountpoint in synology softlink it instead,
	mv /etc/kopano/userscripts /etc/kopano/k-userscripts && \
	cp -R /etc/kopano/k-userscripts /etc && rm -R /etc/kopano/k-userscripts && \
	ln -sf /etc/k-userscripts /etc/kopano/userscripts && \
# robot for got lost, softlink webapp and z-push fron /usr area into html area so no alias is needed
	mv /root/robot.png /var/www/html && ln -sf /usr/share/kopano-webapp /var/www/html/webapp && ln -sf /usr/share/z-push /var/www/html/z-push && \
# more softlink stuff copying over etc and etc-default files
	if [ ! -e /etc/kopano/default ] && [ -e /etc/default/kopano ] ; then cp /etc/default/kopano /etc/kopano/default ; fi && \
	ln -sf /etc/kopano/default /etc/default/kopano && \
	if [ ! -e /etc/kopano/default-webmeetings ] && [ -e /etc/default/kopano-webmeetings ] ; then cp /etc/default/kopano-webmeetings /etc/kopano/default-webmeetings && ln -sf /etc/kopano/default-webmeetings /etc/default/kopano-webmeetings ; fi && \
	if [ ! -e /etc/kopano/default-postgrey ] && [ -e /etc/default/postgrey ] ; then cp /etc/default/postgrey /etc/kopano/default-postgrey ; fi && \
	ln -sf /etc/kopano/default-postgrey /etc/default/postgrey && \
	if [ ! -e /etc/kopano/default-spamassassin ] && [ -e /etc/default/spamassassin ] ; then cp /etc/default/spamassassin /etc/kopano/default-spamassassin ; fi && \
	ln -sf /etc/kopano/default-spamassassin /etc/default/spamassassin && \
	if [ ! -e /etc/kopano/default-amavis-mc ] && [ -e /etc/default/amavis-mc ] ; then cp /etc/default/amavis-mc /etc/kopano/default-amavis-mc ; fi && \
	ln -sf /etc/kopano/default-amavis-mc /etc/default/amavis-mc && \
	if [ ! -e /etc/kopano/default-amavisd-snmp-subagent ] && [ -e /etc/default/amavisd-snmp-subagent ] ; then cp /etc/default/amavisd-snmp-subagent /etc/kopano/default-amavisd-snmp-subagent ; fi && \
	ln -sf /etc/kopano/default-amavisd-snmp-subagent /etc/default/amavisd-snmp-subagent && \
	if [ ! -e /etc/kopano/default-amavis ] && [ -e /etc/amavis/conf.d/20-debian_defaults ] ; then cp /etc/amavis/conf.d/20-debian_defaults /etc/kopano/default-amavis ; fi && \
	ln -sf /etc/kopano/default-amavis /etc/amavis/conf.d/20-debian_defaults && \
	if [ ! -e /etc/kopano/user-amavis ] && [ -e /etc/amavis/conf.d/50-user ] ; then cp /etc/amavis/conf.d/50-user /etc/kopano/user-amavis ; fi && \
	ln -sf /etc/kopano/user-amavis /etc/amavis/conf.d/50-user && \
	if [ ! -e /etc/kopano/content_filter_mode ] && [ -e /etc/amavis/conf.d/15-content_filter_mode ] ; then cp /etc/amavis/conf.d/15-content_filter_mode /etc/kopano/content_filter_mode ; fi && \
	ln -sf /etc/kopano/content_filter_mode /etc/amavis/conf.d/15-content_filter_mode && \
	if [ ! -e /etc/kopano/default-fetchmail ] && [ -e /etc/default/fetchmail ] ; then cp /etc/default/fetchmail /etc/kopano/default-fetchmail ; fi && \
	ln -sf /etc/kopano/default-fetchmail /etc/default/fetchmail && \
	ln -sf /etc/kopano/fetchmailrc /etc/fetchmailrc && \
	ln -sf /etc/kopano/postfix/main.cf /etc/postfix/main.cf && \
	ln -sf /etc/kopano/postfix/master.cf /etc/postfix/master.cf && \
# create and softlink kopanos cron.daily and weekly 
	mkdir -p /etc/kopano/custom && echo '#!/bin/sh' > /etc/kopano/custom/cron.hourly && echo "# put your kopnao cron jobs here" >> /etc/kopano/custom/cron.hourly && \	
	cp /etc/kopano/custom/cron.hourly /etc/kopano/custom/cron.daily && cp /etc/kopano/custom/cron.daily /etc/kopano/custom/cron.weekly && chmod 750 /etc/kopano/custom/cron.* && chown root.kopano /etc/kopano/custom/cron.* && \
	ln -sf /etc/kopano/custom/cron.hourly /etc/cron.hourly/kopano && ln -sf /etc/kopano/custom/cron.daily /etc/cron.daily/kopano && ln -sf /etc/kopano/custom/cron.weekly /etc/cron.weekly/kopano && \
# prevent syslog logrotate warnings
	sed -i -e 's/\(printerror "could not determine current runlevel"\)/#\1/' /usr/sbin/invoke-rc.d && \
	sed -i -e 's/^\(POLICYHELPER=\).*/\1/' /usr/sbin/invoke-rc.d && \
# create logrotate in /etc/logrotate.d/ for amavis, daemon, fetchmail, messages, mail.*, php7*, spamassassin
	echo "/var/log/kopano/amavis.log {" > /etc/logrotate.d/amavis && \
	echo "su amavis kopano\nweekly\nmissingok\nrotate 4\ncompress\ndelaycompress\n}" >> /etc/logrotate.d/amavis && \
	echo "/var/log/kopano/daemon.log {" > /etc/logrotate.d/daemon && \
	echo "su root kopano\nweekly\nmissingok\nrotate 4\ncompress\ndelaycompress\n}" >> /etc/logrotate.d/daemon && \
	echo "/var/log/kopano/fetchmail.log {" > /etc/logrotate.d/fetchmail && \
	echo "su root kopano\nweekly\nmissingok\nrotate 4\ncompress\ndelaycompress\n}" >> /etc/logrotate.d/fetchmail && \
	echo "/var/log/kopano/messages.log {" > /etc/logrotate.d/messages && \
	echo "su root kopano\nweekly\nmissingok\nrotate 4\ncompress\ndelaycompress\n}" >> /etc/logrotate.d/messages && \
	echo "/var/log/kopano/mail.* {" > /etc/logrotate.d/mail && \
	echo "su root kopano\nweekly\nmissingok\nrotate 4\ncompress\ndelaycompress\n}" >> /etc/logrotate.d/mail && \
	echo "/var/log/kopano/php7*.log {" > /etc/logrotate.d/php7 && \
	echo "su root kopano\nweekly\nmissingok\nrotate 4\ncompress\ndelaycompress\n}" >> /etc/logrotate.d/php7 && \
	echo "/var/log/kopano/spamassassin.log {" > /etc/logrotate.d/spamassassin && \
	echo "su root kopano\nweekly\nmissingok\nrotate 4\ncompress\ndelaycompress\n}" >> /etc/logrotate.d/spamassassin && \
# now we set the logrotate path and permission via su user group in existing files in /etc/logrotate.d/
	sed -i -e "s~log {~log {\n\tsu kopano kopano~g"  /etc/logrotate.d/kopano && \
	sed -i -e "s~/var/log/~/var/log/kopano/~"  /etc/logrotate.d/z-push.lr && \
	sed -i -e "s~log {~log {\n\tsu www-data kopano~"  /etc/logrotate.d/z-push.lr && \
	sed -i -e "s~www-data www-data~www-data kopano~g"  /etc/logrotate.d/z-push.lr && \
	sed -i -e "s~log {~log {\n\tsu root kopano~"  /etc/logrotate.d/fetchmail && \
	sed -i -e "s~log {~log {\n\tsu root kopano~"  /etc/logrotate.d/clamav-daemon && \
	sed -i -e "s~log {~log {\n\tsu root kopano~"  /etc/logrotate.d/clamav-freshclam && \
	sed -i -e "s~/var/log/nginx/~/var/log/kopano/nginx~"  /etc/logrotate.d/nginx && \
	sed -i -e "s~log {~log {\n\tsu root kopano~"  /etc/logrotate.d/nginx && \
	sed -i -e "s~www-data adm~root kopano~"  /etc/logrotate.d/nginx && \
	sed -i -e "s~/var/log/syslog~/var/log/kopano/syslog~"  /etc/logrotate.d/rsyslog && \
	sed -i -e "s~{~{\n\tsu root kopano~"  /etc/logrotate.d/rsyslog && \
# expose postfix, nginx and other log files to kopano folder
	ln -sf /var/log/kopano/mail.log /var/log/mail.log && ln -sf /var/log/kopano/mail.info /var/log/mail.info  && \
	ln -sf /var/log/kopano/mail.warn /var/log/mail.warn && ln -sf /var/log/kopano/mail.err /var/log/mail.err && \
	if [ -e /var/log/clamav ] ; then rm -R /var/log/clamav ; fi  && ln -sf /var/log/kopano /var/log/clamav && \
	ln -sf /var/log/kopano/messages /var/log/messages && ln -sf /var/log/kopano/syslog /var/log/syslog && \
	ln -sf /var/log/kopano/daemon.log /var/log/daemon.log && ln -sf /var/log/kopano /var/log/spamassassin && \
	ln -sf /var/log/kopano/php${PHP_VER}-fpm.log /var/log/php${PHP_VER}-fpm.log && \
	ln -sf /var/log/kopano/nginx-access.log /var/log/nginx/access.log && ln -sf /var/log/kopano/nginx-error.log /var/log/nginx/error.log && \
# copy and softlink for webapp and all plugins by plugin-dir/config.php to /etc/kopano/webapp/plg.conf-pluginname.php
	if [ -e /usr/share/kopano-webapp/config.php ] && [ ! -e /etc/kopano/webapp/webapp.conf.php ] ; then cp /usr/share/kopano-webapp/config.php /etc/kopano/webapp/webapp.conf.php ; fi && \
	if [ -e /etc/kopano/webapp/webapp.conf.php ] ; then ln -sf /etc/kopano/webapp/webapp.conf.php /usr/share/kopano-webapp/config.php ; fi && \
	PDIR=`find /usr/share/kopano-webapp/plugins/* -maxdepth 0 -type d -exec basename "{}" ";"` && for P in $PDIR ; do if [ -e /usr/share/kopano-webapp/plugins/$P/config.php ] && [ ! -e /etc/kopano/webapp/plg.conf-${P}.php ] ; then cp /usr/share/kopano-webapp/plugins/$P/config.php /etc/kopano/webapp/plg.conf-${P}.php ; fi ; done && \ 
	for P in $PDIR ; do if [ -e /etc/kopano/webapp/plg.conf-${P}.php ] ; then ln -sf /etc/kopano/webapp/plg.conf-${P}.php /usr/share/kopano-webapp/plugins/$P/config.php ; fi ; done && \
# copy and softlink files for web server note php.ini gets overwritten and softlink re-estabilsiched via init
	cp /etc/php/$PHP_VER/fpm/php.ini /etc/kopano/web && \
	ln -sf /etc/kopano/web/php.ini /etc/php/$PHP_VER/fpm && \
	if [ -e /etc/php/$PHP_VER/mods-available/kopano.ini ] ; then cp /etc/php/$PHP_VER/mods-available/kopano.ini /etc/kopano/web ; fi && \
	ln -sf /etc/kopano/web/kopano.ini /etc/php/$PHP_VER/mods-available && \
	if [ -e /etc/php/$PHP_VER/mods-available/kopano_smime.ini ] ; then cp /etc/php/$PHP_VER/mods-available/kopano_smime.ini /etc/kopano/web ; fi && \
	ln -sf /etc/kopano/web/kopano_smime.ini /etc/php/$PHP_VER/mods-available && \
	cp /etc/php/$PHP_VER/fpm/pool.d/www.conf /etc/kopano/web && \
	ln -sf /etc/kopano/web/www.conf /etc/php/$PHP_VER/fpm/pool.d && \
	ln -sf /etc/kopano/web/kopano-web.conf /etc/nginx/conf.d/ && \
	ln -sf /etc/kopano/web/nginx.conf /etc/nginx && \
# move files to be exposed and mounted via synology to be copied over by init-script
	mv /etc/kopano /etc/kopano2copy && \
	mv /etc/z-push /etc/z-push2copy && \
	mv /var/spool/postfix /var/spool/postfix2copy && \
	mv /var/lib/amavis /var/lib/amavis2copy && \
	mv /var/lib/clamav /var/lib/clamav2copy && \
	mv /var/lib/postgrey /var/lib/postgrey2copy && \
	mv /var/lib/spamassassin /var/lib/spamassassin2copy && \
# remove kopano-logs as they will be mounted and initialised later
	rm -R /var/log/kopano && \
# entry-script, kopano scripts made executable
	chmod 700 /usr/local/bin/init.sh && \
	chmod 700 /usr/local/bin/kopano-postfix.sh && \
	chmod 700 /usr/local/bin/kopano-fetchmail.sh && \
	echo "** completed building ${EDITION}-${TAG} **"
# layer 4 steps 17,18 or 18,19: set workdir for backups later, entrypoint and expose ports
WORKDIR /var/lib/kopano/backup
ENTRYPOINT ["/usr/local/bin/init.sh"]
CMD ["alive"]
# ports kopano(s): 236/237, dagent-lmtp 2003, postfix 25, imap(s) 143/144/993/994, pop3(s) 110/995, ical(s) 8080/8443, webmeetings 8090, Spreed 1935, STUN 3478
EXPOSE 236 237 2003 25 110 143 144 993 994 995 8080 8443 9080 9443 8090 1935 3478
