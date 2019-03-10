# Kopano4s
[Kopano mail & collaboration SW](https://kopano.com/) integration for the [Synology NAS](https://www.synology.com/) using [Docker](https://hub.docker.com) wrapped in a [SPK for Synology Package Manager](https://www.synology.com/en-global/knowledgebase/DSM/tutorial/Service_Application/How_to_install_applications_with_Package_Center).
## Intro
Kopano is an open e-mail and groupware platform that can be used as an alternative for MS Exchange. It comes via pre-packaged binaries (e.g. Debian/Ubuntu DPKG,) to ease installation. With Webmeetings and Mattermost Kopano enters into Unified Communications.

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
*

5. Customizing-Skripts (in merge/custom)
* 

## Kopano Specifics

