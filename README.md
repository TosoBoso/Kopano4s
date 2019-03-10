# Kopano4s
[Kopano mail & collaboration SW](https://kopano.com/) integration for the [Synology NAS](https://www.synology.com/) using [Docker](https://hub.docker.com) wrapped in a [SPK for Synology Package Manager](https://www.synology.com/en-global/knowledgebase/DSM/tutorial/Service_Application/How_to_install_applications_with_Package_Center).

Kopano is an open e-mail and groupware platform that can be used as an alternative for MS Exchange. It comes via pre-packaged binaries (e.g. Debian/Ubuntu DPKG,) to ease installation. With Webmeetings and Mattermost Kopano enters into Unified Communications.

This repository reflects the Synology Package files [SPK](https://www.synology.com/en-global/knowledgebase/DSM/tutorial/Service_Application/How_to_install_applications_with_Package_Center) hosted on the the [Community Package Hub](https://www.cphub.net/?p=k4s) with Synology and [Docker](https://hub.docker.com/r/tosoboso/) specific components. An overview to the project incl. FAQ, installation, migration advise, screenshots etc are found on [Z-Hub.io](https://wiki.z-hub.io/display/K4S).

1. SPK-core files in root:  
* INFO (name of package, version, description etc., dependencies, beta yes when report_url is activeated)
* CHANGELOG (the changelog where you aslo see the live before hosted on github plus outline of roadmap)
* LICENSE (License as shown when installing the package on Synology; this part is under GNU and Kopano under Affero)
* PACKAGE_ICON.PNG / PACKAGE_ICON_120.PNG (the icons shown by Synology Package manager and on SPK repository cph.net)
2. SPK-WIZARD_UIFILES
* install_uifile & uninstall_uifile (json formatted files representing GUI menu parameters "PKGWIZ_*" passed to spk-scripts)
3. SPK-Scripts
*
4. Docker-Container-Skripts (in scripts/container)
'
