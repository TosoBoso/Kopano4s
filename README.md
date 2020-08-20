[![Build Status](https://travis-ci.org/TosoBoso/Kopano4s.svg?branch=master)](https://travis-ci.org/TosoBoso/Kopano4s)
# Kopano4s
[Kopano mail & collaboration SW](https://kopano.com/) integration for the [Synology NAS](https://www.synology.com/) using [Docker](https://hub.docker.com) wrapped in a [SPK for the Package Manager](https://www.synology.com/en-global/knowledgebase/DSM/tutorial/Service_Application/How_to_install_applications_with_Package_Center).
## Intro
Kopano is an open e-mail and groupware platform that can be used as an alternative for MS Exchange. It comes via Docker using pre-packaged binaries (e.g. Debian/Ubuntu DPKG) to ease installation. With Webmeetings and Mattermost Kopano enters into Unified Communications.

Kopano4S is available as free community beta edition based on nightly builds or two types of tested versions which are easier to use with less surprises than the beta: an also free default edition which is 3-9 months old or the up to date supported edition. The latter requires a subscription serial-number (SNR).
The signed package is available via [Community Package Hub](https://www.cphub.net/?p=k4s) which can be linked into Synology Package Center for automatic updates etc. There is no need to git-clone and build the package unless contributing and testing is planned.
A project overview incl. FAQ's, package center integration, installation, Zarafa migration advise, screenshots etc are found on [Z-Hub.io](https://wiki.z-hub.io/display/K4S).

## Contributing: How to Clone, Test & Collaborate
For testing you clone this GitHub repository and via build_spk.sh script build the Synology package file or maintain downloaded SPK via 7zip. 
For detailed instructions including structure and purpose of each files see [CONTRIBUTING.md](https://github.com/TosoBoso/Kopano4s/blob/master/CONTRIBUTING.md).

## Synology Specifics
### Package Target Areas & Testing
When the SPK is rolled out during install Synology copies over the script directory and extracts package.tgz to the target area in this case /var/packages/Kopano4s/target as base directory. Therefore the scripts are found in /var/packages/Kopano4s/scripts/ and the GUI in /var/packages/Kopano4s/target/ui/ and its sub-directories. Running and testing the scripts is by calling them from the cmd-line however note that the main kopano(4s) commands have been set as softlink in /usr/local/bin to make usage more conveniant.
Pragmatic and fastrack testing can be done by copying over a script 
It is also possible to run the main install script from cmd-line via > sudo /var/packages/Kopano4s/scripts/postinst providing the MySql root password. This is because all settings usually coming from package.wizard are set to default.
The same applies for testing the perl ui vi sudo perl index.cgi which has to be run from /var/packages/Kopano4s/target/ui/.
### Admin-UI via Perl and Java-Script
### Reverse Proxy as webapp virtual directory
### Synology IP autoblock as customized fail2ban

## Kopano Docker Specifics 
### Client access via Outlook (mapi/active-sync), mobile device (z-push active sync)
### Passing real-IP into container to enable sensible access log and error-log for fail2ban tailored to Synology.
### Using docker tiny init and init.d scripts to control the services ('multi-microservices approach')

## Future Planning Roadmap
### Decomposing single container in multiple for core, mail, web, meet ('almost-single-microservices approach')
### Ajax in Admin UI enhancing responsiveness, look and feel etc.
