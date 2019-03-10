# Kopano4s
[Kopano mail & collaboration SW](https://kopano.com/) integration for the [Synology NAS](https://www.synology.com/) using [Docker](https://hub.docker.com) wrapped in a [SPK for Synology Package Manager](https://www.synology.com/en-global/knowledgebase/DSM/tutorial/Service_Application/How_to_install_applications_with_Package_Center).
## Intro
Kopano is an open e-mail and groupware platform that can be used as an alternative for MS Exchange. It comes via Docker using pre-packaged binaries (e.g. Debian/Ubuntu DPKG) to ease installation. With Webmeetings and Mattermost Kopano enters into Unified Communications.

Kopano4S is available as free Community edition based on nightly builds or as Supported edition which reuires as subscriptoon serial-number (SNR).
A project overview incl. FAQ's, installation, migration advise, screenshots etc are found on [Z-Hub.io](https://wiki.z-hub.io/display/K4S).
## Structure
This repository reflects the Synology Package files [SPK](https://www.synology.com/en-global/knowledgebase/DSM/tutorial/Service_Application/How_to_install_applications_with_Package_Center) hosted on the the [Community Package Hub](https://www.cphub.net/?p=k4s) with Synology and [Docker](https://hub.docker.com/r/tosoboso/) specific components. 
As per Synology SPK convention the directories ui (admin-gui), merge (iles, cfg etc. to merge in) and log (empty) are in a tar file package.tgz. 

1. SPK-core files in root:  
* INFO (name of package, version, description etc., dependencies, beta yes when report_url is activeated)
* CHANGELOG (the changelog where you aslo see the live before hosted on github plus outline of roadmap)
* LICENSE (License as shown when installing the package on Synology; this part is under GNU and Kopano under Affero)
* PACKAGE_ICON.PNG / PACKAGE_ICON_120.PNG (the icons shown by Synology Package manager and on SPK repository)

2. SPK-WIZARD_UIFILES
* install_uifile & uninstall_uifile (json formatted files representing GUI menu parameters "PKGWIZ_*" passed to spk-scripts)

3. SPK-Scripts
* common (all script functions and certain configuration is collected here to keep the other scripts readable)
* preinst (check for environment incl. valid downloads and SNRs, loading of Docker-image via Synology Docker-GUI)
* postinst (main install logic also for upgrades, gets wizzard-cfg, sets cfg, database, directories, mounts, softlinks)
* postuninst (main un-install logic for removing database, directories, softlinks, docker container, images)
* preupgrade (actions before upgrading, essentially saving logs, etc-files and dropping old docker images)
* start-stop-status (package control sues by Synology GUI and on cmd-cline interacting with Dcoker container)
* preuninst & postupgrade (empty as not needed for k4s, but exisits to satisfy the synology (un-)install structure)

4. Docker-Container-Skripts (in scripts/container)
* Dockerfile (the main docker build file with intermediate container building debian repo relative to selected edition)
* init.sh (the heart of kopano4s services control incl. initialisation, restart, acl reset logic; see help)
* kopano-postfix.sh (core script to control postfix which is exposed to admin-UI. Postfix in not part of Kopano build)
* kopano-fetchmail.sh (core script to control postfix which is exposed to admin-UI. Postfix in not part of Kopano build)

5. Wrapper-Container-Skripts (in scripts/wrapper)
* kopano-userlist.sh & kopano-grouplist.sh (helper scritpts for admin-UI to list users and groups)
* kopano-devicelist.sh (helper scritpts for admin-UI to list mobile devices vi z-push-admin similar to Kopano mdm) 
* kopano-status.sh & kopano-restart.sh (entry to init.sh container script to perform the respective functions)
* kopano-cmdline.sh (also via alias k4s the script to get into the kopano4s containers command-line)
* all other kopano-* cmd-line scripts in container need to get passed via Docker exec command and a return; simple magic

6. Addon-Skripts (in scripts/addon)
* kopano4s-backup.sh (alternative to Kopano's brick level backup as full backup using mysqldump and tar for attachments)
* kopano4s-replication.sh (database replication control script to syncronize Kopano4s for disaster recovery)
* kopano4s-init.sh (helper script to resfresh with new images; also downgrade / defresh ossible and reset container or ACLs)
* kopano4s-optionals.sh (helper script to en/disableoptinal Kopano komponents for use on cmd-line or admin-UI)
* kopano4s-hubtag.sh (helper script to get latest tag from Docker Hub TosoBoso repository Kopano4s with cmd-line or admin-UI)
* kopano4s-autoblock.sh (access to Synology IP autoblock function to facilitate a fail2ban which is work in progress)
* kopano4s-migration-zarafa.sh (automated migration from synolog zarafa(4h) via Kopano-migration edition which is WIP)

7. Customizing-Skripts (in merge/custom)
* 

8. UI-Perl-Skripts, JS, HTML, Images (in ui)
* 


## Synology Specifics
* Admin-UI via Perl and Java-Script
* Reverse Proxy as webapp virtual directory
* Synology IP autoblock as customized fail2ban

## Kopano Docker Specifics 
* Client access via Outlook (mapi/active-sync), mobile device (z-push active sync)
* Pasing real-IP into container to enable sensible access log and error-log for fail2ban
* Unig docker tiny init and init.d scripts to control the services ('multi-microservices approach')

## Future Planning Roadmap
* Decomposing single container in multiple for core, mail, web, meet ('almost-single-microservices approach')
* Ajax in Admin UI nhanceing responsiveness, lokk and feel etc.
