# Contributing
## How to Clone, Test & Collaborate
For testing you clone this GitHub repository and via build_spk.sh script build the Synology package file. More details on structure and purpose of each files see section below.
As manual alternative to SPK build script copy the SPK file from [here](https://wiki.z-hub.io/display/K4S) and modify the Kopano4s-xxx.spk using 7zip: 
remove the syno_signature.asc and replace the modified files at the respective location (see also the Structure chapter below). 
Finally you use the Synology Package Managers manual install feature for testing.

The modified and tested files can then be pushed to this Github repository. There is a pragmatic fastrack for testing without rolling out 
For testing you clone this GitHub repository and via build_spk.sh script build the Synology package file. Fot information on structure see below.
As manual alternative copy the SPK file from [here](https://wiki.z-hub.io/display/K4S) and modify the Kopano4s-xxx.spk using 7zip: 
remove the syno_signature.asc and replace the modified files at the respective location (see also the Structure chapter below). 
Finally you use the Synology Package Managers manual install feature for testing.
The modified and tested files can then be pushed to this Github repository. There is a pragmatic fastrack for testing without rolling out the SPK each time: replace respective files in Synology package area (see also the Synology Specifics chapter below).

## Structure: Areas and Purpose of Files
This repository reflects the Synology Package files [SPK](https://www.synology.com/en-global/knowledgebase/DSM/tutorial/Service_Application/How_to_install_applications_with_Package_Center) hosted on the the [Community Package Hub](https://www.cphub.net/?p=k4s) with Synology and [Docker](https://hub.docker.com/r/tosoboso/) specific components. 
As per Synology SPK convention in the SPK root there are information files, package images and the scripts all other directories, aka ui (admin-gui), merge (files, cfg etc. to merge in) and log (empty) are in a tar file package.tgz adn found in the APP directory (the build_spk .sh script will pus this part into the tgz). 

1. SPK-core files in PKG (spk root):  
* INFO (name of package, version, description etc., dependencies, beta yes when report_url is activeated)
* CHANGELOG (the changelog where you aslo see the live before hosted on github plus outline of roadmap)
* LICENSE (License as shown when installing the package on Synology; this part is under GNU and Kopano under Affero)
* PACKAGE_ICON.PNG / PACKAGE_ICON_120.PNG (the icons shown by Synology Package manager and on SPK repository)

2. PKG-WIZARD_UIFILES
* install_uifile & uninstall_uifile (json formatted files representing GUI menu parameters "PKGWIZ_*" passed to spk-scripts)

3. PKG-Scripts
* common (all script functions and certain configuration is collected here to keep the other scripts readable)
* preinst (check for environment incl. valid downloads and SNRs, loading of Docker-image via Synology Docker-GUI)
* postinst (main install logic also for upgrades, gets wizzard-cfg, sets cfg, database, directories, mounts, softlinks)
* postuninst (main un-install logic for removing database, directories, softlinks, docker container, images)
* preupgrade (actions before upgrading, essentially saving logs, etc-files and dropping old docker images)
* start-stop-status (package control sues by Synology GUI and on cmd-cline interacting with Dcoker container)
* preuninst & postupgrade (empty as not needed for k4s, but exisits to satisfy the synology (un-)install structure)

4. Docker-Container-Skripts (in PKG/scripts/container)
* Dockerfile (the main docker build file with intermediate container building debian repo relative to selected edition)
* init.sh (the heart of kopano4s services control incl. initialisation, restart, acl reset logic; see help)
* kopano-postfix.sh (core script to control postfix which is exposed to admin-UI. Postfix in not part of Kopano build)
* kopano-fetchmail.sh (core script to control postfix which is exposed to admin-UI. Postfix in not part of Kopano build)
* dpkg-remove (list of debian packages that can be removed pot image build to keep the Docker image / container lean)

5. Wrapper-Container-Skripts (in PKG/scripts/wrapper)
* kopano-userlist.sh & kopano-grouplist.sh (helper scritpts for admin-UI to list users and groups)
* kopano-devicelist.sh (helper scritpts for admin-UI to list mobile devices vi z-push-admin similar to Kopano mdm) 
* kopano-status.sh & kopano-restart.sh (entry to init.sh container script to perform the respective functions)
* kopano-cmdline.sh (also via alias k4s the script to get into the kopano4s containers command-line)
* all other kopano-* cmd-line scripts in container need to get passed via Docker exec command and a return; simple magic

6. Addon-Skripts (in PKG/scripts/addon)
* kopano4s-backup.sh (alternative to Kopano's brick level backup as full backup using mysqldump and tar for attachments)
* kopano4s-replication.sh (database replication control script to syncronize Kopano4s for disaster recovery)
* kopano4s-init.sh (helper script to resfresh with new images; also downgrade / defresh ossible and reset container or ACLs)
* kopano4s-optionals.sh (helper script to en/disableoptinal Kopano komponents for use on cmd-line or admin-UI)
* kopano4s-hubtag.sh (helper script to get latest tag from Docker Hub TosoBoso repository Kopano4s with cmd-line or admin-UI)
* kopano4s-autoblock.sh (access to Synology IP autoblock function to facilitate a fail2ban which is work in progress)
* kopano4s-migration-zarafa.sh (automated migration from synolog zarafa(4h) via Kopano-migration edition which is WIP)

7. Merge-Files (in APP/merge and sub.dirs postfix, web, z-push)
* postbuild.sh (target: /etc/kopano/custom for user to have additional steps performed to the container post build from image)
* dpkg-add (debian packages e.g. vim-tiny that can be added to the container post build from image and be customized by user)
* server.cfg.init, default.init, dagent.cfg.init (target: /etc/kopano configuration files customized and different to Kopano distro)
* kinit.tgz (init.d services control files; as Kopano no longer ships init.d files focusing on systemd which Docker does not 'like')
* fetchmailrc (target: /etc/kopano templte file for fetchmail)

8. UI-Perl-Skripts, JS, HTML, Pics (in APP/ui and APP/ui/images)
* config (Synology soecific file for the UI to define URLs and icons like webapp and the name of admin UI index.cgi)
* index.cgi (main perl script which reads in html and js sources adding them to the output)
* syno_cgi.pl (helper file for validating token and login of admin and base logic for html-get paramaters)
* dsm.css, images (stylesheet file and images sub-directory)
* menu.htm (menu structure for all pages redered by index.cgi)
* alias, cfg, cmd, devices, fetch, intro, log, queue, report, smtp, spamav, tools, user.htm (pages redered by index.cgi with layout, fileds, combos etc.)
* alias, cfg, cmd, devices, fetch, intro, log, queue, report, smtp, spamav, tools, user.js (JavaScript files to respective pages)

