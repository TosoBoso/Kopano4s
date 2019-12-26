#!/usr/bin/perl
use Time::Local;
use MIME::Base64; # for obfuscation decode_base64 eq atb in JS
use strict;
use warnings;
require "syno_cgi.pl"; # base cgi functions incl. get params
# helper functions
sub getCfgValue { # get key value from unix file via syno utility
    my $cfg = shift; # the cfg-file parameter
    my $key = shift; # the key parameter
    my $ret = `/bin/get_key_value $cfg $key`;
    chomp($ret);
    $ret = '' if (!$ret);
    return $ret;
}
sub setCfgValue { # set key value to unix file via sed utility
    my $cfg = shift; # the cfg-file parameter
    my $key = shift; # the key parameter
    my $val = shift; # the value parameter
    my $opt = shift; # options: shell or shstring empty is cfg file mode with spaces
    my $ret='';
    if ( $opt eq 'shstring' ) {
        $ret = `/bin/sed -i -e 's~$key.*~$key="$val"~' $cfg`;
    }
    elsif ( $opt eq 'shell' ) {
        $ret = `/bin/sed -i -e 's~$key.*~$key=$val~' $cfg`;
    }
    else {
        if ($cfg =~ /server.cfg/) { # kopano server.cfg loves space + tabs
            $ret = `/bin/sed -i -e "s~$key.*~$key 	= $val~" $cfg`;
        }
        else {
            $ret = `/bin/sed -i -e 's~$key.*~$key = $val~' $cfg`;
        }
        # debug: $ret = "run: /bin/sed -i -e 's~$key.*~$key = $val~' $cfg";
        #$key .= " 	" if ($scfg =~ /server.cfg/); # kopano loves space + tabs
    }
    #eq to perl -i -p -e "s/^($key[]*=[ ]*).*$/\1$value/" config.file 
    chomp($ret);
    return $ret;
}
sub getPatternValue { # get the 1st line per pattern from unix file via grep utility
    my $cfg = shift; # the cfg-file parameter
    my $key = shift; # the pattern key parameter
    my $ret = `/bin/grep $key $cfg`;
    chomp($ret);
    $ret = '' if (!$ret);
    return $ret;
}
sub setPatternValue { # set key value per pattern to unix file via sed utility
    my $cfg = shift; # the cfg-file parameter
    my $key = shift; # the key parameter
    my $val = shift; # the value parameter
    my $opt = shift; # options: shell empty is cfg file mode with spaces
    my $ret;
    if ( $opt eq 'shell' ) {
        $ret = `/bin/sed -i -e 's~$key.*~${key}${val}~' $cfg`;
    }
    else {
        $ret = `/bin/sed -i -e 's~$key.*~$key $val~' $cfg`;
    }
    chomp($ret);
    return $ret;
}
sub replacePatternValue { # replace key pattern by full line value to unix file via sed utility
    my $cfg = shift; # the cfg-file parameter
    my $key = shift; # the key parameter
    my $val = shift; # the value parameter
    my $opt = shift; # options: doublequotes; empty default is singlequotes
    my $ret;
    if ( $opt ne 'doublequotes' ) {
        $ret = `/bin/sed -i -e "s~$key.*~${val}~" $cfg`;
    }
    else {
        $ret = `/bin/sed -i -e 's~$key.*~${val}~' $cfg`;
    }
    chomp($ret);
    return $ret;
}
sub setComment { # set comments on / off for pattern via sed utility
    my $cfg = shift; # the cfg-file parameter
    my $key = shift; # the key parameter
    my $cmt = shift; # the on / off value parameter
    my $ret;
    if ( $cmt eq 'off' ) {
        $ret = `/bin/sed -i -e 's~#$key~$key~g' $cfg`;
    }
    else {
        $ret = `/bin/sed -i -e 's~$key~#$key~g' $cfg`;
    }
    chomp($ret);
    return $ret;
}

my $isDebug = 1; # debug modus
my $debug = ""; # debug text
my $isAdmin = 0; # part of administrators group
my $isDocker = 0; # part of docker group
my $isKopano = 0; # part of kopano group
my $cgiUser = $ENV{LOGNAME} || getpwuid($<) || $ENV{USER};
my $uiUser =''; # user running ui session
my $xsToken = !$ENV{'X-SYNO-TOKEN'} ? 'null' : $ENV{'X-SYNO-TOKEN'}; # synology token against xss in header
my $dsmToken =''; #  synology dsm token against xss from dsm login.cgi
my %tmplhtml; # array to capture all dynamic entries
my $jscript = ''; # java script per page
my $menu = ''; # menu html text highlighted with current page
my $page = ''; # page to process from query string
my $action = ''; # action to process from query string
my $form = ''; # multi form submit e.g. for z-admin page
my $status = ''; # status field
my $cmdline=''; # command to pass to system
my @rawDataCmd; #  command reply from system
my $startTime = timegm(gmtime());
my $dsmbuild = getCfgValue('/etc.defaults/VERSION', 'buildnumber');

# *** common head: set html context, verify login, get global parameters, javascript, menu
print "Content-type: text/html\n\n";
# get the users priviledges and synotoken to verify login
($isAdmin,$uiUser,$dsmToken) = usr_priv();
# app_priv used post usr_priv for non admin and is not yet working for older dsm versions b4 6.1
($isAdmin,$uiUser,$dsmToken) = app_priv('SYNO.SDS._ThirdParty.App.kopano4s') if !$isAdmin;

# autheticate in usr/app_priv returns uiUser null if it does not work e.g. in c,d-line mode
if ($uiUser eq 'null' && $isDebug) { # tweak for debugging from cmd-line
   $isAdmin = 1;
   $uiUser = $cgiUser;
}
$isDocker = usr_ingrp($uiUser, 'docker'); 
$isKopano = usr_ingrp($uiUser, 'kopano'); 
$ENV{'QUERY_STRING'} = '' if !$ENV{'QUERY_STRING'} && $isDebug;
$debug = "CGI-User: $cgiUser, UI-User: $uiUser isAdmin: $isAdmin, isDocker: $isDocker, isKopano: $isKopano, dsmToken: $dsmToken, QueryStr: $ENV{'QUERY_STRING'}" if $isDebug;
# exit with warning if not admin or in admin group
if ( !$isAdmin ) {
    print "<HTML><HEAD><TITLE>Login Required</TITLE></HEAD><BODY><H3><BR>&nbsp;Please login as priviledged app user or admin first before using this webpage (user cgi / ui: $cgiUser / $uiUser, token: $dsmToken)</H3></BODY></HTML>\n";
    die;
}

$page = param ('page');
$page = 'intro' if ! $page;
$action = param('action');
# get javascript for main, page and navigation menu
if (open(IN,"main.js")) {
    while (<IN>) {
        $jscript .= $_;
    }
    close(IN);
}
if (open(IN,"$page.js")) {
    while (<IN>) {
        $jscript .= $_;
    }
    close(IN);
}
if (open(IN,"menu.htm")) {
    while (<IN>) {
        # replace line with active page adding class active
        s/href=/class=\"active\" href=/g if ($_ =~ /page=$page/);
        $menu .= $_;
    }
    close(IN);
}
$tmplhtml{'jscript'} = "<script type=\"text/javascript\">\n" . $jscript . "\n	</script>";
$tmplhtml{'menu'} = $menu;
# *** end of common head
# *** process body: the page specific parts
if ($page eq 'intro') 
{
    my $pkgcfg = '/var/packages/Kopano4s/etc/package.cfg'; # package cfg file location
    my $kvertag = getCfgValue($pkgcfg, "VER_TAG");
    my $hubvertag = '';
    my $kupdate = '';
    my $kStatus = '';
    my $status = 'Kopano health status OK';
    #$status = 'Warning user $uiUser must be part of docker group to make the GUI cmds work' if ! $isDocker;
    $status = "Debug: $debug" if $isDebug;

    $cmdline = '/var/packages/Kopano4s/scripts/addon/kopano4s-hubtag.sh |';
    if (open(DAT, $cmdline))
    {
        @rawDataCmd = <DAT>;
        close(DAT);
        foreach my $reply (@rawDataCmd) {
            chomp($reply);
            $hubvertag = $reply;
        }
    }
    if ( $kvertag lt $hubvertag ) {
        $kupdate = '<form action="index.cgi" method="get"> <input type="hidden" name="page" value="cmd"/>&nbsp;';
        $kupdate .= '<input type="hidden" name="rcmd" value="kopano4s-init"/> <input type="hidden" name="rcmd" value="kopano4s-init"/> ';
        $kupdate .= '<input type="hidden" name="params" value="refresh"/> <input type="hidden" name="rcmd" value="kopano4s-init"/> ';
        $kupdate .= '<input type="submit" name="action" value="Run"/>&nbsp;image refresh to <B>' . $hubvertag . '</B></form>';
    }
    $cmdline = '/var/packages/Kopano4s/scripts/wrapper/kopano-status.sh |';
    if (open(DAT, $cmdline))
    {
        @rawDataCmd = <DAT>;
        close(DAT);
        foreach my $reply (@rawDataCmd) {
            chomp($reply);
            $kStatus .= $reply;
        }
    }
    $status = 'Error returned by kopano-status. Check if container is running.' if ($kStatus =~ /Error/);
    $status = 'Warning returned by kopano-status. Check which services are Not running.' if ($kStatus =~ /Not Running/);

    # todo: health status e.g. all services running, nothing in hold / defer queue
    $tmplhtml{'kvertag'} = $kvertag;
    $tmplhtml{'kupdate'} = $kupdate;
    $tmplhtml{'status'} = $status;
}
if ($page eq 'user') 
{
    my $usrtbl = ''; # collect the k-user table tr commands
    my $grptbl = ''; # collect the k-group table tr commands
    my $pkgcfg = '/var/packages/Kopano4s/etc/package.cfg'; # package cfg file location

    # process request to add, update, delete user first considering the input forms
    $form = param('form');
    if ($action eq 'Add' && $form eq 'user') {
        my $kuser = param ('kuser');
        my $passwd = param ('passwd');
        if ( length($passwd) > 2 ) { # happy deoding obfuscated pwd
            my $encoded = substr($passwd, 2); # from pos 2 to end, no need to give lenght
            $passwd = decode_base64($encoded);
            chop($passwd);
        }
        my $name = param ('name');
        my $email = param ('email');
        my $admin = param ('admin');
        $admin = "off" if ! $admin;
        if (! $kuser || ! $passwd || ! $name || ! $email ) {
            $status = "Error adding new user: parameters missing. ";
        }
        else {
            my $locale = getCfgValue($pkgcfg, 'LOCALE');
            my $edition = getCfgValue($pkgcfg, 'K_EDITION');
            my $admflag = $admin eq "on" ? 1 : 0;
            $status = "Adding $kuser with pwd $passwd.. ";
            # migration edition fails when create-strore is used
            if ($edition eq 'Migration') {
                $cmdline = "kopano-cli --create --user '$kuser' --fullname '$name' --email '$email' --password '$passwd' --admin-level $admflag --lang '$locale' |";                
            }
            else {
                $cmdline = "kopano-cli --create --create-store --user '$kuser' --fullname '$name' --email '$email' --password '$passwd' --admin-level $admflag --lang '$locale' |";
            }
            #$status = $cmdline;
            if (open(DAT, $cmdline)) {
                @rawDataCmd = <DAT>;
                close(DAT);
                foreach my $reply (@rawDataCmd) {
                    chomp($reply);
                    $status .=  $reply;
                }
                $status .= ". ";
                # add another kopano-localize-folders just in case
                system("/bin/sh /var/packages/Kopano4s/scripts/wrapper/kopano-localize-folders.sh -u $kuser --lang '$locale' > /dev/null");				
            }
            else {
                close(DAT);
            }
        }
    }
    if ( $action eq 'Update'  && $form eq 'user') {
        my $kuser = param ('kuser');
        my $passwd = param ('passwd');
        if ( $passwd && length($passwd) > 2 ) { # happy decoding obfuscated pwd
            my $encoded = substr($passwd, 2); # from pos 2 to end, no need to give lenght
            $passwd = decode_base64($encoded);
            chop($passwd);
        }
        my $name = param ('name');
        my $email = param ('email');
        my $admin = param ('admin');
        if (! $kuser || (! $passwd && ! $name && ! $email) ) {
            $status = "Error updating user: parameters missing. ";
        }
        else {
            $admin = "off" if ! $admin;
            $status = "Updating $kuser.. ";
            $cmdline = "/var/packages/Kopano4s/scripts/wrapper/kopano-cli.sh --user $kuser";
            $cmdline .= " --fullname='$name'" if $name;
            $cmdline .= " --email='$email'" if $email;
            $cmdline .= " --password='$passwd'" if $passwd;
            $cmdline .= " --admin-level=1" if $admin eq "on";
            $cmdline .= " |";
            if (open(DAT, $cmdline)) {
                @rawDataCmd = <DAT>;
                close(DAT);
                foreach my $reply (@rawDataCmd) {
                    chomp($reply);
                    $status .=  $reply;
                }
                $status .= ". ";
            }
            else {
                close(DAT);
            }
        }
    }
    # set imap and pop3 features with -enable-feature imap /pop3 or disable
    if ( ($action eq 'Add' || $action eq 'Update') && $form eq 'user') {
        my $kuser = param ('kuser');
        my $imap = param ('imap');
        $imap = "off" if ! $imap;
        my $pop3 = param ('pop3');
        $pop3 = "off" if ! $pop3;
        $cmdline = "/var/packages/Kopano4s/scripts/wrapper/kopano-cli.sh --user $kuser";
        if ($imap eq 'on') {
            $cmdline .= " --add-feature imap |";
        }
        else {
            $cmdline .= " --remove-feature imap |";
        }
        if (open(DAT, $cmdline)) {
            @rawDataCmd = <DAT>;
            close(DAT);
            foreach my $reply (@rawDataCmd) {
                chomp($reply);
                $status .=  $reply;
            }
            $status .= ". ";
        }
        else {
            close(DAT);
        }
        $cmdline = "/var/packages/Kopano4s/scripts/wrapper/kopano-cli.sh --user $kuser";
        if ($pop3 eq 'on') {
            $cmdline .= " --add-feature pop3 |";
        }
        else {
            $cmdline .= " --remove-feature pop3 |";
        }
        if (open(DAT, $cmdline)) {
            @rawDataCmd = <DAT>;
            close(DAT);
            foreach my $reply (@rawDataCmd) {
                chomp($reply);
                $status .=  $reply;
            }
            $status .= ". ";
        }
        else {
            close(DAT);
        }
    }
    if ( $action eq 'Delete'  && $form eq 'user') {
        my $kuser = param ('kuser');
        if (! $kuser ) {
            $status = "Error deleting user: parameters missing. ";
        }
        else {
            $status = "Deleting $kuser.. ";
            $cmdline = "/var/packages/Kopano4s/scripts/wrapper/kopano-cli.sh --user $kuser --delete |";
            if (open(DAT, $cmdline)) {
                @rawDataCmd = <DAT>;
                close(DAT);
                foreach my $reply (@rawDataCmd) {
                    chomp($reply);
                    $status .=  $reply;
                }
                $status .= ". ";
            }
            else {
                close(DAT);
            }
        }
    }
    if ($action eq 'Add' && $form eq 'group') {
        my $kgroup = param ('kgroup');
        my $email = param ('email');
        if (! $kgroup) {
            $status = "Error adding new group: parameters missing. ";
        }
        else {
            $status = "Adding $kgroup.. ";
            $cmdline = "/var/packages/Kopano4s/scripts/wrapper/kopano-cli.sh --create --group $kgroup";
            $cmdline .= " --email '$email'" if $email;
            $cmdline .= " |";
            if (open(DAT, $cmdline)) {
                @rawDataCmd = <DAT>;
                close(DAT);
                foreach my $reply (@rawDataCmd)	{
                    chomp($reply);
                    $status .=  $reply;
                }
                $status .= ". ";
            }
            else {
                close(DAT);
            }
        }
    }
    if ($action eq 'Update' && $form eq 'group') {
        my $kgroup = param ('kgroup');
        my $email = param ('email');
        if (! $kgroup) {
            $status = "Error adding new group: parameters missing. ";
        }
        else {
            $status = "Updating $kgroup.. ";
            $cmdline = "/var/packages/Kopano4s/scripts/wrapper/kopano-cli.sh --group $kgroup";
            $cmdline .= " --email='$email'" if $email;
            $cmdline .= " |";
            if (open(DAT, $cmdline)) {
                @rawDataCmd = <DAT>;
                close(DAT);
                foreach my $reply (@rawDataCmd)	{
                    chomp($reply);
                    $status .=  $reply;
                }
                $status .= ". ";
            }
            else {
                close(DAT);
            }
        }
    }
    if ($action eq 'Delete' && $form eq 'group') {
        my $kgroup = param ('kgroup');
        my $email = param ('email');
        if (! $kgroup) {
            $status = "Error deleting group: parameters missing. ";
        }
        else {
            $status = "Deleting $kgroup.. ";
            $cmdline = "/var/packages/Kopano4s/scripts/wrapper/kopano-cli.sh --group $kgroup --delete |";
            if (open(DAT, $cmdline)) {
                @rawDataCmd = <DAT>;
                close(DAT);
                foreach my $reply (@rawDataCmd) {
                    chomp($reply);
                    $status .=  $reply;
                }
                $status .= ". ";
            }
            else
            {
                close(DAT);
            }
        }
    }
    if ($action eq 'Added' && $form eq 'grp2usr') {
        my $kuser = param ('kuser');
        my $kgroup = param ('kgroup');
        if (! $kuser && ! $kgroup) {
            $status = "Error adding user to group: parameters missing. ";
        }
        else {
            $status = "Adding $kuser to $kgroup.. ";
            $cmdline = "/var/packages/Kopano4s/scripts/wrapper/kopano-cli.sh --group $kgroup --add-user $kuser |";
            if (open(DAT, $cmdline)) {
                @rawDataCmd = <DAT>;
                close(DAT);
                foreach my $reply (@rawDataCmd) 
                {
                    chomp($reply);
                    $status .=  $reply;
                }
                $status .= ". ";
            }
            else {
                close(DAT);
            }
        }
    }
    if ($action eq 'Removed' && $form eq 'grp2usr') {
        my $kuser = param ('kuser');
        my $kgroup = param ('kgroup');
        if (! $kuser && ! $kgroup) {
            $status = "Error removing user off from group: parameters missing. ";
        }
        else {
            $status = "Removing $kuser off from $kgroup.. ";
            $cmdline = "/var/packages/Kopano4s/scripts/wrapper/kopano-cli.sh --group $kgroup --remove-user $kuser |";
            if (open(DAT, $cmdline)) {
                @rawDataCmd = <DAT>;
                close(DAT);
                foreach my $reply (@rawDataCmd) 
                {
                    chomp($reply);
                    $status .=  $reply;
                }
                $status .= ". ";
            }
            else {
                close(DAT);
            }
        }
    }
    if ($action eq 'Added' && $form eq 'sendas') {
        my $kuser = param ('kuser');
        my $kgroup = param ('kgroup');
        my $delegate = param ('delegate');
        if (! $kuser && ! $kgroup) {
            $status = "Error adding users or group delegate: parameters missing. ";
        }
        else {
            if ($kuser) {
                $status = "Adding $kuser the send-as delegate $delegate.. ";
                $cmdline = "/var/packages/Kopano4s/scripts/wrapper/kopano-cli.sh --user $kuser --add-sendas $delegate |";
            }
            if ($kgroup) {
                $status = "Adding $kgroup the send-as delegate $delegate.. ";
                $cmdline = "/var/packages/Kopano4s/scripts/wrapper/kopano-cli.sh --group $kgroup --add-sendas $delegate |";
            }
            if (open(DAT, $cmdline)) {
                @rawDataCmd = <DAT>;
                close(DAT);
                foreach my $reply (@rawDataCmd)  {
                    chomp($reply);
                    $status .=  $reply;
                }
                $status .= ". ";
            }
            else {
                close(DAT);
            }
        }
    }
    if ($action eq 'Removed' && $form eq 'sendas') {
        my $kuser = param ('kuser');
        my $kgroup = param ('kgroup');
        my $delegate = param ('delegate');
        if (! $kuser && ! $kgroup) {
            $status = "Error removing users or groups delegate: parameters missing. ";
        }
        else {
            if ($kuser) {
                $status = "Deleting $kuser the send-as delegate $delegate.. ";
                $cmdline = "/var/packages/Kopano4s/scripts/wrapper/kopano-cli.sh --user $kuser --remove-sendas $delegate |";
            }
            if ($kgroup) {
                $status = "Deleting $kgroup the send-as delegate $delegate.. ";
                $cmdline = "/var/packages/Kopano4s/scripts/wrapper/kopano-cli.sh --group $kgroup --remove-sendas $delegate |";
            }
            if (open(DAT, $cmdline)) {
                @rawDataCmd = <DAT>;
                close(DAT);
                foreach my $reply (@rawDataCmd) {
                    chomp($reply);
                    $status .=  $reply;
                }
                $status .= ". ";
            }
            else {
                close(DAT);
            }
        }
    }
    #run script that wraps kopano admin command and strips of unneccessary tabs etc.
    $cmdline = '/var/packages/Kopano4s/scripts/wrapper/kopano-userlist.sh | grep -v k-user |';
    if (open(DAT, $cmdline))
    {
        @rawDataCmd = <DAT>;
        close(DAT);
        foreach my $reply (@rawDataCmd) {
            chomp($reply);
            #split up entries
            my ($uiUsername, $fullname, $email, $active, $admin, $features, $size, $groups, $sendas) = split(",",$reply);
            if(defined ($uiUsername))
            {
                $usrtbl .= "<tr>";
                $usrtbl .= "<td>$uiUsername</td>";
                $usrtbl .= "<td>$fullname</td>";
                $usrtbl .= "<td>$email</td>";
                $usrtbl .= "<td>$active</td>";
                $usrtbl .= "<td>$admin</td>";
                $usrtbl .= "<td>$features</td>";
                $usrtbl .= "<td>$size</td>";
                $usrtbl .= "<td>$groups</td>";
                $usrtbl .= "<td>$sendas</td>";
                $usrtbl .= "</tr>\n";
            }
        }
    }
    else
    {
        close(DAT);
        $status .= "Error reading z-users. ";
    }
    $cmdline = '/var/packages/Kopano4s/scripts/wrapper/kopano-grouplist.sh | grep -v k-group |';
    if (open(DAT, $cmdline))
    {
        @rawDataCmd = <DAT>;
        close(DAT);
        foreach my $reply (@rawDataCmd) {
            chomp($reply);
            #split up entries
            my ($groupname, $email, $sendas) = split(",",$reply);
            if(defined ($groupname))
            {
                $grptbl .= "<tr>";
                $grptbl .= "<td>$groupname</td>";
                $grptbl .= "<td>$email</td>";
                $grptbl .= "<td>$sendas</td>";
                $grptbl .= "</tr>\n";
            }
        }
    }
    else
    {
        close(DAT);
        $status .= "Error reading z-groups. ";
    }
    my $endTime = timegm(gmtime());
    my $sdiff = $endTime - $startTime;
    $status .= "Requests completed in $sdiff seconds.";
    # fill dynamic html array to be printed on pages
    $tmplhtml{'usrtbl'} = $usrtbl;
    $tmplhtml{'grptbl'} = $grptbl;
    $tmplhtml{'status'} = $status;
}
if ($page eq 'alias') 
{
    my $valiases = "/etc/kopano/postfix/valiases";
    my $rcpbcc = "/etc/kopano/postfix/recipient_bcc";
    my $sdrbcc = "/etc/kopano/postfix/sender_bcc";
    my $bounce = "/etc/kopano/postfix/bounce.cf";
    $tmplhtml{'aliastxt'} = '';
    $tmplhtml{'bcctxt'} = ''; 
    $tmplhtml{'bouncetxt'} = '';
    $tmplhtml{'status'} = '';
    # process request to add, update, delete user first considering the input forms
    $form = param('form');
    if ($action eq 'Add' && $form eq 'alias') { 
        my $valias = param('valias');
        my $aliasrcpt = param('aliasrcpt');
        if ( $valias && $aliasrcpt ) {
           my $ret = `/bin/grep $valias	$valiases`;
           if ( $ret ne '' ) {
               $tmplhtml{'status'} .= "Error alias $valias already exists. ";
           }
           else {
               $ret = `/bin/echo "$valias	$aliasrcpt" >> $valiases`;
               $ret = `kopano-postfix map /etc/kopano/postfix/valiases`;
               $tmplhtml{'status'} .= "Created alias $valias->$aliasrcpt $ret";
            }
        }
    }
    if ($action eq 'Update' && $form eq 'alias') { 
        my $valias = param('valias');
        my $aliasrcpt = param('aliasrcpt');
        if ( $valias && $aliasrcpt ) {
           my $ret = `/bin/grep $valias	$valiases`;
           if ( $ret eq '' ) {
               $tmplhtml{'status'} .= "Error alias $valias to update does not exists. ";
           }
           else {
               $ret = `/bin/sed -i -e 's~$valias.*~$valias	$aliasrcpt~' $valiases`;
               $ret = `kopano-postfix map /etc/kopano/postfix/valiases`;
               $tmplhtml{'status'} .= "Updated alias $valias->$aliasrcpt $ret";
            }
        }
    }
    if ($action eq 'Delete' && $form eq 'alias') { 
        my $valias = param('valias');
        if ( $valias ) {
           my $ret = `/bin/sed -i '/$valias/d' $valiases`; # delete line with pattern
           $ret = `kopano-postfix map /etc/kopano/postfix/valiases`;
           $tmplhtml{'status'} .= "Deleted alias $valias $ret";
        }
    }
    if ($action eq 'Add' && $form eq 'rcpBcc') {
        my $inrcp = param('inrcp');
        my $rcprcp = param('rcprcp');
        if ( $inrcp && $rcprcp ) {
           my $ret = `/bin/grep $inrcp	$rcpbcc`;
           if ( $ret ne '' ) {
               $tmplhtml{'status'} .= "Error alias $inrcp already exists. ";
           }
           else {
               $ret = `/bin/echo "$inrcp	$rcprcp" >> $rcpbcc`;
               $ret = `kopano-postfix map /etc/kopano/postfix/recipient_bcc`;
               $tmplhtml{'status'} .= "Added alias $inrcp->$rcprcp $ret";
           }
        }
    }
    if ($action eq 'Update' && $form eq 'rcpBcc') { 
        my $inrcp = param('inrcp');
        my $rcprcp = param('rcprcp');
        if ( $inrcp && $rcprcp ) {
           my $ret = `/bin/grep $inrcp	$rcpbcc`;
           if ( $ret eq '' ) {
               $tmplhtml{'status'} .= "Error alias $inrcp to update does not exists. ";
           }
           else {
               $ret = `/bin/sed -i -e 's~$inrcp.*~$inrcp	$rcprcp~' $rcpbcc`;
               $ret = `kopano-postfix map /etc/kopano/postfix/recipient_bcc`;
               $tmplhtml{'status'} .= "Updated alias $inrcp->$rcprcp $ret";
            }
        }
    }
    if ($action eq 'Delete' && $form eq 'rcpBcc') { 
        my $inrcp = param('inrcp');
        if ( $inrcp ) {
           my $ret = `/bin/sed -i '/$inrcp/d' $rcpbcc`; # delete line with pattern
           $ret = `kopano-postfix map /etc/kopano/postfix/recipient_bcc`;
           $tmplhtml{'status'} .= "Deleted alias $inrcp $ret";
        }
    }
    if ($action eq 'Add' && $form eq 'sdrBcc') { 
        my $outsdr = param('outsdr');
        my $sdrrcp = param('sdrrcp');
        if ( $outsdr && $sdrrcp ) {
           my $ret = `/bin/grep $outsdr	$sdrbcc`;
           if ( $ret ne '' ) {
               $tmplhtml{'status'} .= "Error alias $outsdr already exists. ";
           }
           else {
               $ret = `/bin/echo "$outsdr	$sdrrcp" >> $sdrbcc`;
               $ret = `kopano-postfix map /etc/kopano/postfix/sender_bcc`;
               $tmplhtml{'status'} .= "Added alias $outsdr->$sdrrcp incl. $ret";
           }
        }
    }
    if ($action eq 'Update' && $form eq 'sdrBcc') { 
        my $outsdr = param('outsdr');
        my $sdrrcp = param('sdrrcp');
        if ( $outsdr && $sdrrcp ) {
           my $ret = `/bin/grep $outsdr	$sdrbcc`;
           if ( $ret eq '' ) {
               $tmplhtml{'status'} .= "Error alias $outsdr to update does not exists. ";
           }
           else {
               $ret = `/bin/sed -i -e 's~$outsdr.*~$outsdr	$sdrrcp~' $sdrbcc`;
               $ret = `kopano-postfix map /etc/kopano/postfix/sender_bcc`;
               $tmplhtml{'status'} .= "Updated alias $outsdr->$sdrrcp incl. $ret";
            }
        }
    }
    if ($action eq 'Delete' && $form eq 'sdrBcc') { 
        my $outsdr = param('outsdr');
        if ( $outsdr ) {
           my $ret = `/bin/sed -i '/$outsdr/d' $sdrbcc`; # delete line with pattern
           $ret = `kopano-postfix map /etc/kopano/postfix/sender_bcc`;
           $tmplhtml{'status'} .= "Deleted alias $outsdr $ret";
        }
    }
    if ($action eq 'Update' && $form eq 'bounce') { 
        my $bline1 = param('bline1');
        my $bline2 = param('bline2');
        if ( $bline1 && $bline2 ) {
           my $ret = `/bin/sed -i -e 's~$bline1~$bline2~g' $bounce`;
           $tmplhtml{'status'} .= 'Updated bounce template for <$bline2>';
        }
    }
    # collect from files
    $tmplhtml{'aliastxt'} .= "		Alias				|				Recipient\n ";
    if (open(IN,"$valiases")) {
        while (<IN>) {
            chomp;
            my ($a,$r) = split /\s*	\s*/, $_;
            # replace 1 tab gainst 3-5 x 3 with | in middle
            if ( length ($a) > 22 ) {
                s/\t/\t\t\t|\t\t\t/g;
            }
            elsif ( length ($a) > 18 ) {
                s/\t/\t\t\t\t|\t\t\t/g;
            }
            elsif ( length ($a) > 14 ) {
                s/\t/\t\t\t\t|\t\t\t/g;
            }
            else {
                s/\t/\t\t\t\t\t|\t\t\t/g;
            }
            $tmplhtml{'aliastxt'} .= "$_\n ";
        }
        close(IN);
    }
    $tmplhtml{'bcctxt'} .= "	Inbox-Receiver				|				BCC-Recipient\n ";
    if (open(IN,"$rcpbcc")) {
        while (<IN>) {
            chomp;
            my ($a,$r) = split /\s*	\s*/, $_;
            # replace 1 tab gainst 3-5 x 3 with | in middle
            if ( length ($a) > 22 ) {
                s/\t/\t\t\t|\t\t\t/g;
            }
            elsif ( length ($a) > 18 ) {
                s/\t/\t\t\t\t|\t\t\t/g;
            }
            elsif ( length ($a) > 14 ) {
                s/\t/\t\t\t\t|\t\t\t/g;
            }
            else {
                s/\t/\t\t\t\t\t|\t\t\t/g;
            }
            $tmplhtml{'bcctxt'} .= "$_\n ";
        }
        close(IN);
    }
    $tmplhtml{'bcctxt'} .= "	Outbox-Sender				|				BCC-Recipient\n ";
    if (open(IN,"$sdrbcc")) {
        while (<IN>) {
            chomp;
            my ($a,$r) = split /\s*	\s*/, $_;
            # replace 1 tab gainst 3-5 x 3 with | in middle
            if ( length ($a) > 22 ) {
                s/\t/\t\t\t|\t\t\t/g;
            }
            elsif ( length ($a) > 18 ) {
                s/\t/\t\t\t\t|\t\t\t/g;
            }
            elsif ( length ($a) > 14 ) {
                s/\t/\t\t\t\t|\t\t\t/g;
            }
            else {
                s/\t/\t\t\t\t\t|\t\t\t/g;
            }
            $tmplhtml{'bcctxt'} .= "$_\n ";
        }
        close(IN);
    }
    $tmplhtml{'bouncetxt'} .= "		Bounce-Mail-Template\n ";
    if (open(IN,"$bounce")) {
        while (<IN>) {
            chomp;
            $tmplhtml{'bouncetxt'} .= "$_\n ";
        }
        close(IN);
    }

}
if ($page eq 'smtp') 
{
    my $maincfg = '/etc/kopano/postfix/main.cf';
    my $hdrcfg = '/etc/kopano/postfix/header_checks';
    my $relayhost;
    my $relaysvr;
    my $portcmb;
    my $relayport = 587;
    my $relayusr = '';
    my $relaypwd = '';
    my $tlson = 'OFF'; # when checked set to on
    my $tlscheck = ''; # when checked set to checked
    my $tlsname;
    my $domains;
    my $maxsize = getCfgValue($maincfg, 'message_size_limit'); # max attachemt size
    my $blocktype = getPatternValue($hdrcfg, "^/name"); # of attachments
    my $entry = '';
    my @ports = ('587', '465', '25', 'via:');
    my $cfgtxt = '';
    # get timestamp
    my $start_time = timegm(gmtime());
    # convert message maxsite to MB
    $maxsize = $maxsize / 1024 / 1024 if ( $maxsize ne '');
    # get the value from blocksize in between the brackets ()
    if ( $blocktype =~ /\((.*?)\)/ )
    {
        $blocktype = $1;
    }
    else {
        $blocktype = '';
    }

    # collect relay server with trim spaces and split off the port
    $cmdline = "grep '^relayhost =' /etc/kopano/postfix/main.cf | cut -d'=' -f2- |";
    if (open(DAT, $cmdline)) {
        @rawDataCmd = <DAT>;
        close(DAT);
        foreach my $reply (@rawDataCmd) {
            chomp($reply);
            $relayhost .=  "$reply";
            # remove white space left / right
            $relayhost =~ s/^\s+|\s+$//g;
            ( $relaysvr, $relayport ) = split /\s*:\s*/, $relayhost;
        }
    }
    if ( $relayhost ne "" ) {
        $cmdline = "grep $relayhost /etc/kopano/postfix/sasl_passwd |";
        if (open(DAT, $cmdline)) {
            @rawDataCmd = <DAT>;
            close(DAT);
            foreach my $reply (@rawDataCmd) {
                chomp($reply);
                my ( $skip, $usrpwd ) = split /\s*	\s*/, $reply;
                ( $relayusr, $relaypwd ) = split /\s*:\s*/, $usrpwd;
            }
        }
    }
    # collect tls setting, hostname and mail domains
    $cmdline = "grep '^smtpd_use_tls' /etc/kopano/postfix/main.cf | cut -d'=' -f2- |";
    if (open(DAT, $cmdline)) {
        @rawDataCmd = <DAT>;
        close(DAT);
        foreach my $reply (@rawDataCmd) {
            chomp($reply);
            if ( $reply =~ /yes/) {
                $tlson = "ON";
                $tlscheck = "checked";
            }
        }
    }
    $cmdline = "grep '^myhostname =' /etc/kopano/postfix/main.cf | cut -d'=' -f2- |";
    if (open(DAT, $cmdline)) {
        @rawDataCmd = <DAT>;
        close(DAT);
        foreach my $reply (@rawDataCmd) {
            chomp($reply);
            $tlsname = $reply;
            # remove white space left / right
            $tlsname =~ s/^\s+|\s+$//g;
        }
    }
    if (open(IN, "/etc/kopano/postfix/vdomains"))
    {
        while (<IN>) {
            $domains .= $_;
            # remove white space left / right
            $domains =~ s/^\s+|\s+$//g;
        }
        close(IN);
    }
    # process commands first: update is for main.cf entries
    if ( $action eq 'Save' ) {
        my $new_relayhost = param ('relaysvr') eq '' ? '' : param ('relaysvr') . ":" . param ('port');
        my $new_relayusr = param ('relayusr');
        my $new_relaypwd = param ('relaypwd');
        if ( length($new_relaypwd) > 2 ) { # happy deoding obfuscat3ed pwd
            my $encoded = substr($new_relaypwd, 2); # from pos 2 to end, no need to give lenght
            $new_relaypwd = decode_base64($encoded);
            chop($new_relaypwd);
            $status .= $encoded . "->" . $new_relaypwd; # show obfuscated and decoded pwd
        }
        my $new_tlsname = param ('tlsname');
        my $new_tlsdomains = param ('domains');
        my $new_maxsize = param ('maxsize');
        my $new_blocktype = param ('blocktype');
        if ( $new_relayhost ne $relayhost || $new_relayusr ne $relayusr || $new_relaypwd ne $relaypwd ) {
            if ( $new_relayhost eq '' ) {
                system("/bin/sh /var/packages/Kopano4s/scripts/wrapper/kopano-postfix.sh relay off > /dev/null");
                $new_relayusr = '';
                $new_relaypwd = '';
            }
            else {
                system("/bin/sh /var/packages/Kopano4s/scripts/wrapper/kopano-postfix.sh relay '$new_relayhost' '$new_relayusr' '$new_relaypwd' > /dev/null");
            }
            $relayhost = $new_relayhost;
            ( $relaysvr, $relayport ) = split /\s*:\s*/, $relayhost;
            $relayusr = $new_relayusr;
            $relaypwd = $new_relaypwd;
        }
        if ( $new_tlsname ne $tlsname ) {
            my $host_entry = "myhostname = $new_tlsname";
            system("/bin/sh /var/packages/Kopano4s/scripts/wrapper/kopano-postfix.sh edit '$host_entry' > /dev/null");
            $tlsname = $new_tlsname;
        }
        if ( $new_tlsdomains ne $domains ) {
            my $main_domain;
            if (open(DAT, '>', "/etc/kopano/postfix/vdomains")) {
                print DAT "$new_tlsdomains";
                close(DAT);
            }
            if ( $new_tlsdomains =~ /,/) {
                # use shift to get 1st entry
                my @domains = split /\s*,\s*/, $new_tlsdomains;
                $main_domain = shift(@domains);
            }
            else {
                $main_domain = $new_tlsdomains;
            }
            my $domain_entry = "mydomain = $main_domain";
            system("/bin/sh /var/packages/Kopano4s/scripts/wrapper/kopano-postfix.sh edit '$domain_entry' > /dev/null");
            $domains = $new_tlsdomains;
        }
        if ( $new_maxsize ne $maxsize ) {
            my $maxsizeBytes = $new_maxsize * 1024 * 1024;
            my $ret = setCfgValue($maincfg, 'message_size_limit', $maxsizeBytes);
            $maxsize = $new_maxsize;
        }
        if ( $new_blocktype ne $blocktype ) {
            # recreate '/name ?= "?.*\. (a|b|c)"?/ REJECT'
            my $blockstr = '"?.*\. (' . $new_blocktype . ')"?/ REJECT"';
            my $ret = setPatternValue($hdrcfg, '/name ?=', $blockstr);
            $blocktype = $new_blocktype;
        }
    }
    if ( $action eq 'Update' ) {
        $entry = param ('entry');
        if ( $entry ne "" ) {
            system("/bin/sh /var/packages/Kopano4s/scripts/wrapper/kopano-postfix.sh edit '$entry' > /dev/null");
        }
    }
    $cmdline = "/var/packages/Kopano4s/scripts/wrapper/kopano-postfix.sh config |";
    if (open(DAT, $cmdline)) {
        @rawDataCmd = <DAT>;
        close(DAT);
        foreach my $reply (@rawDataCmd) {
            chomp($reply);
            $cfgtxt .=  "$reply\n ";
        }
    }
    else {
        close(DAT);
    }
    if ( $cfgtxt eq '') {
        $cfgtxt .= "ERROR in validating main.cf via postconf -n (consider repair or init): \n";
        # 2>&1 to get error messages of postconf
        $cmdline = "";
        system("/bin/sh /var/packages/Kopano4s/scripts/wrapper/kopano-postfix.sh config >/tmp/postconf 2>&1");
        if (open(IN,"/tmp/postconf")) {
            while (<IN>) {
                chomp();
                $cfgtxt .= " $_ \n";
            }
        }
    }
    foreach my $port (@ports) {
        $portcmb .= "<option value=\"$port\"";
        $portcmb .= "selected" if $port eq $relayport;
        $portcmb .= ">$port</option>\n";
    }
    # fill dynamic html array to be printed on pages
    $tmplhtml{'tlsname'} = $tlsname;
    $tmplhtml{'domains'} = $domains;
    $tmplhtml{'tlson'} = $tlson;
    $tmplhtml{'tlscheck'} = $tlscheck;
    $tmplhtml{'relaysvr'} = $relaysvr;
    $tmplhtml{'portcmb'} = $portcmb;
    $tmplhtml{'relayusr'} = $relayusr;
    $tmplhtml{'relaypwd'} = $relaypwd;
    $tmplhtml{'maxsize'} = $maxsize;
    $tmplhtml{'blocktype'} = $blocktype;
    $tmplhtml{'entry'} = $entry;
    $tmplhtml{'cfgtxt'} = $cfgtxt;
    $tmplhtml{'status'} = $status;
    #$debug .= "\n\n" if $isDebug;
}
if ($page eq 'fetch') 
{
    my $fetchcfg = '/etc/kopano/fetchmailrc';
    my $fetchdef = '/etc/kopano/default-fetchmail';
    my $kopanodef = '/etc/kopano/default';
    my $fetchtbl = ''; # collect the fetch-user table tr commands
    my $chkactive = getCfgValue($fetchdef, 'START_DAEMON') eq 'yes' ? 'checked' : ''; # enabled?
    my $chkkeep = getPatternValue($fetchcfg, 'keep') =~ /#/ ? '' : 'checked'; # no commented out is keep true
    my $chkmda = getPatternValue($fetchcfg, '#mda=') =~ /on/ ? 'checked' : ''; # mda modus on?
    my ($c1, $cycle, $c3) = split("	",getPatternValue($fetchcfg, 'set daemon')); # tab seperated
	$cycle = $cycle / 60;
    # process request to add, update, delete entries first considering the input forms
    $form = param('form');
    if ($action eq 'Save' && $form eq 'config') {
        my $new_chkactive = param('active') eq 'on' ? 'checked' : '';
        if ( $new_chkactive ne $chkactive ) {
            $chkactive = $new_chkactive;
            if ( $chkactive eq 'checked' ) {
                setCfgValue($fetchdef, 'START_DAEMON', 'yes', 'shell');
                setCfgValue($kopanodef, 'FETCHMAIL_ENABLED', 'yes', 'shell');
                system("/bin/sh /var/packages/Kopano4s/scripts/wrapper/kopano-fetchmail.sh start >/dev/null");
            }
            else {
                setCfgValue($fetchdef, 'START_DAEMON', 'no', 'shell');
                setCfgValue($kopanodef, 'FETCHMAIL_ENABLED', 'no', 'shell');
                system("/bin/sh /var/packages/Kopano4s/scripts/wrapper/kopano-fetchmail.sh stop force >/dev/null");
            }
        }
        my $new_cycle = param('cycle');
        if ( $new_cycle ne $cycle ) {
            $cycle = $new_cycle;
            my $cyclesec = $new_cycle * 60;
            my $cyclestr = "$cyclesec	# run every $new_cycle minutes";
            my $ret = setPatternValue($fetchcfg, 'set daemon	', $cyclestr);
            $status .= "Cycle ${new_cycle}m set. ";
        }
        my $new_chkkeep = param('keep') eq 'on' ? 'checked' : '';
        if ( $new_chkkeep ne $chkkeep ) {
            $chkkeep = $new_chkkeep;
            if ( $new_chkkeep eq 'checked' ) {
                setComment($fetchcfg, 'keep', 'off');
                setComment($fetchcfg, 'fetchall', 'on');
            }
            else {
                setComment($fetchcfg, 'keep', 'on');
                setComment($fetchcfg, 'fetchall', 'off');
            }
        }
        my $new_chkmda = param('mda') eq 'on' ? 'checked' : '';
        if ( $new_chkmda ne $chkmda ) {
            $chkmda = $new_chkmda;
            if ( $new_chkmda eq 'checked' ) {
                setPatternValue($fetchcfg, '#mda=', 'on', 'shell');
            }
            else {
                setPatternValue($fetchcfg, '#mda=', 'of', 'shell');
            }
        }
    }
    if ($action eq 'Add' && $form eq 'fetch') {
        my $kuser = param('kuser');
        my $ruser = param('ruser');
        my $passwd = param('passwd');
        if ( $passwd && length($passwd) > 2 ) { # happy deoding obfuscated pwd
            my $encoded = substr($passwd, 2); # from pos 2 to end, no need to give lenght
            $passwd = decode_base64($encoded);
            chop($passwd);
        }
        my $server = param('server');
        my $sproto = param('sproto');
        my $port = param('port');
        my $ssl = param('ssl');
        my $folders = param('folders');
        $ssl = 'no-ssl' if (! $ssl ); 
        $folders = 'n/a' if (! $folders || $folders eq 'INBOX' );
        if (! $kuser || ! $ruser || ! $passwd || ! $server || ! $sproto || ! $sproto || ! $port ) {
            $status = "Error adding new user: parameters missing. ";
        }
        else {
            $cmdline = "/var/packages/Kopano4s/scripts/wrapper/kopano-fetchmail.sh add $kuser $ruser '${passwd}' $server $sproto $port $ssl $folders |";
            if (open(DAT, $cmdline)) {
                @rawDataCmd = <DAT>;
                close(DAT);
                foreach my $reply (@rawDataCmd) {
                    chomp($reply);
                    if ( $reply =~ 'init') {
                        system("/bin/sh /var/packages/Kopano4s/scripts/wrapper/kopano-fetchmail.sh init >/dev/null");
                        $reply = 'Fetchmail initialized for 1st entry. ';
                    }
                    $status .=  $reply;
                }
            }
            else {
                close(DAT);
            }
        }
    }
    if ($action eq 'Delete' && $form eq 'fetch') {
        my $kuser = param('kuser');
        my $ruser = param('ruser');
        if (! $kuser || ! $ruser ) {
            $status = "Error deleting user: parameters missing. ";
        }
        else {
            $cmdline = "/var/packages/Kopano4s/scripts/wrapper/kopano-fetchmail.sh remove $kuser $ruser |";
            if (open(DAT, $cmdline)) {
                @rawDataCmd = <DAT>;
                close(DAT);
                foreach my $reply (@rawDataCmd) {
                    chomp($reply);
                    $status .=  $reply;
                }
            }
            else {
                close(DAT);
            }
        }
        $status .= "";
    }
    if ($action eq 'Add' && $form eq 'shost') {
        
        $status .= "";
    }
    if ($action eq 'Delete' && $form eq 'shost') {
        
        $status .= "";
    }
    #run script that wraps kopano admin command and strips of unneccessary tabs etc.
    $cmdline = '/var/packages/Kopano4s/scripts/wrapper/kopano-fetchmail.sh list | grep -v z-user |';
    if (open(DAT, $cmdline))
    {
        @rawDataCmd = <DAT>;
        close(DAT);
        foreach my $reply (@rawDataCmd) {
            chomp($reply);
            # split up entries and skip header with k-user eq k-user
            my ($kuser, $ruser, $rpwd, $server, $protocol, $port, $ssl, $folders) = split(";",$reply);
            if( defined ($kuser) && $kuser ne 'k-user' )
            {
                $fetchtbl .= "<tr>";
                $fetchtbl .= "<td>$kuser</td>";
                $fetchtbl .= "<td>$ruser</td>";
                if ($isDebug) {
                   $fetchtbl .= "<td>$rpwd</td>";
                }
                else {
                   $fetchtbl .= "<td>****</td>";
                }
                $fetchtbl .= "<td>$server</td>";
                $fetchtbl .= "<td>$protocol</td>";
                $fetchtbl .= "<td>$port</td>";
                $fetchtbl .= "<td>$ssl</td>";
                $fetchtbl .= "<td>$folders</td>";
                $fetchtbl .= "</tr>\n";
            }
        }
    }
    else
    {
        close(DAT);
        $status .= "Error reading fetchmail-users. ";
    }    
    my $endTime = timegm(gmtime());
    my $sdiff = $endTime - $startTime;
    $status .= "Requests completed in $sdiff seconds.";
    # fill dynamic html array to be printed on pages
    $tmplhtml{'chkactive'} = $chkactive;
    $tmplhtml{'cycle'} = $cycle;
    $tmplhtml{'chkkeep'} = $chkkeep;
    $tmplhtml{'chkmda'} = $chkmda;
    $tmplhtml{'fetchtbl'} = $fetchtbl;
    $tmplhtml{'status'} = $status;
    #$debug .= "\n\n" if $isDebug;
}
if ($page eq 'spamav') 
{
    
}
if ($page eq 'report') 
{
    my $rptcmb='';
    my $rselect='';
    my $params='';
    my @trange = ('today', 'yesterday', 'full week');
    if ( $action ne '' ) {
        $rselect = param ('range');
        $params = param('params');
    }
    $tmplhtml{'status'} = '';
    $tmplhtml{'params'} = $params;
    
    foreach my $entry (@trange) {
        $rptcmb .= "<option value=\"$entry\"";
        $rptcmb .= "selected" if $entry eq $rselect;
        $rptcmb .= ">$entry</option>\n";
    }
    $tmplhtml{'rptcmb'} = $rptcmb;

    if ( $action eq 'Run' ) {
        $cmdline = "/var/packages/Kopano4s/scripts/wrapper/kopano-postfix.sh logsumm $params";
        if ( $rselect eq 'today' || $rselect eq 'yesterday' ) {
            $cmdline .= " -d $rselect /var/log/mail.log |";
        }
        else {
            # todo: add the week-x rotated logs
            $cmdline .= " /var/log/mail.log |";
        }
        if (open(DAT, $cmdline)) {
            @rawDataCmd = <DAT>;
            close(DAT);
            foreach my $reply (@rawDataCmd) {
                chomp($reply);
                $tmplhtml{'rpttxt'} .=  "$reply\n";
            }
            if ( $params eq '--help' ) {
                $tmplhtml{'rpttxt'} .= "\n see also PflogSumm manual at https://linux.die.net/man/1/pflogsumm.";
            }
        }
        else {
            close(DAT);
        }
    }

}
if ($page eq 'queue') 
{
    $tmplhtml{'status'} = '';
    $tmplhtml{'queuetxt'} = '';
    $tmplhtml{'qmsgstxt'} = '';
    my $msgid;
    # process commands first: update is for main.cf entries
    if ( $action ne '' ) {
        $msgid = param ('msgid');
        $tmplhtml{'msgid'} = $msgid;
    }
    if ( $action eq 'Release' || $action eq 'ReleaseA' ) {
        $msgid = 'ALL' if ( $action eq 'ReleaseA' );
        $cmdline = "/var/packages/Kopano4s/scripts/wrapper/kopano-postfix.sh release $msgid |";
        if (open(DAT, $cmdline)) {
            @rawDataCmd = <DAT>;
            close(DAT);
            foreach my $reply (@rawDataCmd) {
                chomp($reply);
                $tmplhtml{'status'} .=  "$reply ";
            }
        }
        else {
            close(DAT);
        }
    }
    if ( $action eq 'Requeue' || $action eq 'RequeueA' ) {
        $msgid = 'ALL' if ( $action eq 'RequeueA' );
        $cmdline = "/var/packages/Kopano4s/scripts/wrapper/kopano-postfix.sh requeue $msgid |";
        if (open(DAT, $cmdline)) {
            @rawDataCmd = <DAT>;
            close(DAT);
            foreach my $reply (@rawDataCmd) {
                chomp($reply);
                $tmplhtml{'status'} .=  "$reply ";
            }
        }
        else {
            close(DAT);
        }
    }    
    if ( $action eq 'Resend' || $action eq 'ResendA' ) {
        $msgid = 'ALL' if ( $action eq 'ResendA' );
        $cmdline = "/var/packages/Kopano4s/scripts/wrapper/kopano-postfix.sh resend $msgid |";
        if (open(DAT, $cmdline)) {
            @rawDataCmd = <DAT>;
            close(DAT);
            foreach my $reply (@rawDataCmd) {
                chomp($reply);
                $tmplhtml{'status'} .=  "$reply ";
            }
        }
        else {
            close(DAT);
        }
    }
    if ( $action eq 'Delete' || $action eq 'DeleteA' ) {
        $msgid = 'ALL' if ( $action eq 'DeleteA' );
        $cmdline = "/var/packages/Kopano4s/scripts/wrapper/kopano-postfix.sh delete $msgid |";
        if (open(DAT, $cmdline)) {
            @rawDataCmd = <DAT>;
            close(DAT);
            foreach my $reply (@rawDataCmd) {
                chomp($reply);
                $tmplhtml{'status'} .=  "$reply ";
            }
        }
        else {
            close(DAT);
        }
    }
    if ( $action eq 'Flush-Q' ) {
        $cmdline = "/var/packages/Kopano4s/scripts/wrapper/kopano-postfix.sh flush |";
        if (open(DAT, $cmdline)) {
            @rawDataCmd = <DAT>;
            close(DAT);
            foreach my $reply (@rawDataCmd) {
                chomp($reply);
                $tmplhtml{'status'} .=  "$reply ";
            }
        }
        else {
            close(DAT);
        }
    }
    $cmdline = "/var/packages/Kopano4s/scripts/wrapper/kopano-postfix.sh queue |";
    if (open(DAT, $cmdline)) {
        @rawDataCmd = <DAT>;
        close(DAT);
        foreach my $reply (@rawDataCmd) {
            chomp($reply);
            if ( $reply !~ /^\w/ && $reply !~ /^\-/ ) { # 2nd line trim in
                $reply =~ s/^\s+//;
                $reply = " / $reply" if $reply;
                $reply .= "\n " if $reply;
            }
            $reply .= "\n " if ( $reply =~ /^\-/ ); # line break after header
            $tmplhtml{'queuetxt'} .=  $reply;
        }
    }
    else {
        close(DAT);
    }
    $cmdline = "/var/packages/Kopano4s/scripts/wrapper/kopano-postfix.sh queuemsgs |";
    if (open(DAT, $cmdline)) {
        @rawDataCmd = <DAT>;
        close(DAT);
        foreach my $reply (@rawDataCmd) {
            chomp($reply);
            $tmplhtml{'qmsgstxt'} .=  "$reply\n ";
        }
    }
    else {
        close(DAT);
    }
    my $endTime = timegm(gmtime());
    my $sdiff = $endTime - $startTime;
    $tmplhtml{'status'} .= "Completed in $sdiff seconds.";    
}
if ($page eq 'cfg') 
{
    my $pkgcfg = '/var/packages/Kopano4s/etc/package.cfg'; # package cfg file location
    my $svrcfg = '/etc/kopano/server.cfg'; # server cfg file location
    my $defcfg = '/etc/kopano/default'; # kopano default cfg file location
    my $mycfg = '/var/packages/MariaDB10/etc/my.cnf'; # MariaDB10 cfg file location
    my @pkgtags = ('kshare','kbackup','kfsattach','kgateway','kical','ksearch','kmonitor','dbname','dbuser','http','https','ical','icals',
                   'imap','imaps','pop3','pop3s','ksyncssl','kforcessl','kwrtc','wrtc','ksnr','slocale','stimezone','unblock','keep','knotify','ntarget','stuning');
    my @mytags = ('innobuff','mpacket'); # mysql cfg tags
    my %cfgparam; # key value tag to cfg paramater
    $cfgparam{'kshare'} = 'K_SHARE'; # path to kopano share
    $cfgparam{'kbackup'} = 'K_BACKUP_PATH'; # path to kopano backup
    $cfgparam{'kfsattach'} = 'ATTACHMENT_ON_FS'; # attchments on file system on or off sync also into zsvrcfg
    $cfgparam{'kgateway'} = 'K_GATEWAY';  # kopano-gateway on or off
    $cfgparam{'kical'} = 'K_ICAL'; # kopano-ical on or off
    $cfgparam{'ksearch'} = 'K_SEARCH'; # kopano-search on or off
    $cfgparam{'kmonitor'} = 'K_MONITOR'; # kopano-monitor on or off
    $cfgparam{'dbname'} = 'DB_NAME'; # kopano-database name
    $cfgparam{'dbuser'} = 'DB_USER'; # kopano-database user
    $cfgparam{'dbpass'} = 'DB_PASS'; # kopano-database pwd sync also into zsvrcfg
    $cfgparam{'http'} = 'HTTP_PORT'; # container http port
    $cfgparam{'https'} = 'HTTPS_PORT'; # container https port
    $cfgparam{'ical'} = 'ICAL_PORT'; # container ical port
    $cfgparam{'icals'} = 'ICALS_PORT'; # container icals port
    $cfgparam{'imap'} = 'IMAP_PORT'; # container imap port
    $cfgparam{'imaps'} = 'IMAPS_PORT'; # container imaps port
    $cfgparam{'pop3'} = 'POP3_PORT'; # container pop3 port
    $cfgparam{'pop3s'} = 'POP3S_PORT'; # container pop3s port
    $cfgparam{'ksyncssl'} = 'K_SYNC_SYNOCERT'; # sync with synology certificates on or off
    $cfgparam{'kforcessl'} = 'K_FORCE_SSL'; # enforce ssl by disabling other ports on or off
    $cfgparam{'kwrtc'} = 'K_WEBMEETINGS'; # kopano-webmeetings on or off
    $cfgparam{'wrtc'} = 'WRTC_PORT'; # container web-rtc port
    $cfgparam{'ksnr'} = 'K_SNR'; # kopano serial number
    $cfgparam{'slocale'} = 'LOCALE'; # kopano-locale language
    $cfgparam{'stimezone'} = 'TIMEZONE'; # kopano-timezone for container
    $cfgparam{'unblock'} = 'UNBLOCK_AFTERD'; # unblock / delete ip after
    $cfgparam{'keep'} = 'KEEP_BACKUPS'; # how many backups to keep
    $cfgparam{'knotify'} = 'NOTIFY';  # notification e.g. backup status on or off
    $cfgparam{'ntarget'} = 'NOTIFYTARGET'; # notification target
    $cfgparam{'stuning'} = 'TUNING_BUFFER'; # % tuning buffer to total memory
    $cfgparam{'innobuff'} = 'innodb_buffer_pool_size'; # mysql innodb buffer setting
    $cfgparam{'mpacket'} = 'max_allowed_packet';  # mysql max buffer setting e.g. for restore

    foreach my $tag (@pkgtags) { # collect values for cfg parameter per tag for package
        $tmplhtml{$tag} = getCfgValue($pkgcfg, $cfgparam{$tag});
    }
    foreach my $tag (@mytags) { # collect values for cfg parameter per tag in mysql
        $tmplhtml{$tag} = getCfgValue($mycfg, $cfgparam{$tag});
    }
    $tmplhtml{'innobuff'} = "16M" if ! $tmplhtml{'innobuff'};
    $tmplhtml{'mpacket'} = "1M" if ! $tmplhtml{'mpacket'};
    $tmplhtml{'status'} = '';
    my @locales = ('en_US.UTF-8', 'de_DE.UTF-8', 'fr_FR.UTF-8', 'es_ES.UTF-8', 'it_IT.UTF-8', 'nl_NL.UTF-8');
    my @timezones = ('CET', 'EET', 'EST', 'GB', 'GMT', 'HST', 'MET', 'MST', 'NZ', 'PRC', 'ROC', 'ROK', 'UCT', 'UTC', 'US', 'WET',
                     'Africa', 'America', 'Antarctica', 'Arctic', 'Asia', 'Atlantic', 'Australia', 'Brazil', 'Canada', 'Chile', 
                     'Cuba', 'Egypt', 'Eire', 'Europe', 'Hongkong', 'Iceland', 'Indian', 'Iran', 'Israel', 'Jamaica', 'Japan',
                     'Kwajalein', 'Libya', 'Mexico', 'Navajo', 'Pacific', 'Poland', 'Portugal', 'Singapore', 'Turkey', 'Zulu');
    my @tunings = ('0%', '20%', '40%', '60%');
    my $cfgtxt='';
    my $scfg='';
    my $cfgcmb='';
    my $ret='';
    my $cfgpath=''; 
    my @cfgfiles = ('default', 'server.cfg', 'spooler.cfg', 'dagent.cfg', 'licensed.cfg', 'search.cfg', 'monitor.cfg', 'gateway.cfg', 'ical.cfg',
                     'presence.cfg', 'webapp.conf.php', 'z-push.conf.php', 'autodiscover.conf.php', 'gabsync.conf.php', 'gab2contacts.conf.php',
                     'kopano.conf.php', 'policies.ini', 'user-amavis', 'content_filter_mode', 'default-amavis', 'default-amavis-mc',
                     'default-postgrey', 'webmeetings.cfg', 'default-webmeetings', 'kopano-web.conf', 'my.cnf', 'fpm-pool-target');
    my $splg='';
    my $plgcmb='';
    my @plgfiles = (); # now fill array with all plugin.phps in cfg dir 
    $cmdline = "ls /etc/kopano/webapp/plg.conf-* | cut -d '-' -f2- |";
    if (open(DAT, $cmdline))
    {
        @rawDataCmd = <DAT>;
        close(DAT);
        foreach my $reply (@rawDataCmd) {
            chomp($reply);
            push(@plgfiles, $reply);
         }
    }
    else
    {
        close(DAT);
        $tmplhtml{'status'} .= "Error reading plugin-cfg-phps. ";
    }

    # process command first and avoid uninitialized values
    $tmplhtml{'plgentry'} = '';
    $tmplhtml{'cfgentry'} = '';
    if ( $action eq 'Save' ) { 
        my %newtaghtml; # key value array to capture all tag values for html entries
        foreach my $tag (@pkgtags) { # collect values for all html tags
            $newtaghtml{$tag} = param ($tag);
        }
        foreach my $tag (@mytags) { # collect values for all html tags
            $newtaghtml{$tag} = param ($tag);
        }
        my @strtags = ('kshare','kbackup','kfsattach','kgateway','kical','ksearch','kmonitor',
                       'dbname','dbuser','kwrtc','ksyncssl','kforcessl','ksnr','slocale','stimezone','knotify','ntarget');
        my @numtags = ('http','https','ical','icals','imap','imaps','pop3','pop3s','wrtc','unblock','keep','stuning');
        $newtaghtml{'kfsattach'} = $newtaghtml{'kfsattach'} eq 'on' ? 'ON' : 'OFF'; # convert small into caps
        $newtaghtml{'kgateway'} = $newtaghtml{'kgateway'} eq 'on' ? 'ON' : 'OFF'; # convert small into caps
        $newtaghtml{'kical'} = $newtaghtml{'kical'} eq 'on' ? 'ON' : 'OFF'; # convert small into caps
        $newtaghtml{'ksearch'} = $newtaghtml{'ksearch'} eq 'on' ? 'ON' : 'OFF'; # convert small into caps
        $newtaghtml{'kmonitor'} = $newtaghtml{'kmonitor'} eq 'on' ? 'ON' : 'OFF'; # convert small into caps
        $newtaghtml{'knotify'} = $newtaghtml{'knotify'} eq 'on' ? 'ON' : 'OFF'; # convert small into caps
        $newtaghtml{'kwrtc'} = $newtaghtml{'kwrtc'} eq 'on' ? 'ON' : 'OFF'; # convert small into caps
        $newtaghtml{'ksyncssl'} = $newtaghtml{'ksyncssl'} eq 'on' ? 'ON' : 'OFF'; # convert small into caps
        $newtaghtml{'kforcessl'} = $newtaghtml{'kforcessl'} eq 'on' ? 'ON' : 'OFF'; # convert small into caps
        chop($newtaghtml{'stuning'}); # remove the %
        # special cases for attachments and k-services changed also update kopano-server.cfg / default 
        if ( $newtaghtml{'kfsattach'} ne $tmplhtml{'kfsattach'} ) {
            my $zval = $newtaghtml{'kfsattach'} eq 'ON' ? 'files' : 'database'; # convert to files/database for cfg
            $ret = setCfgValue($svrcfg, 'attachment_storage', $zval, '');
            if ( $zval eq 'files' ) {
                $tmplhtml{'status'} .= "Warning Kopano stops if attachments are not migrated out of database. ";
            }
        }
        my $doReset=0; # for exposed ports container reset has to be done
        if ( $newtaghtml{'kgateway'} ne $tmplhtml{'kgateway'} ) {
            $ret = setCfgValue($defcfg, 'GATEWAY_ENABLED', $newtaghtml{'kgateway'} eq 'ON' ? 'yes':'no', 'shell');
            $doReset=1;
        }
        if ( $newtaghtml{'kical'} ne $tmplhtml{'kical'} ) {
            $ret = setCfgValue($defcfg, 'ICAL_ENABLED', $newtaghtml{'kical'} eq 'ON' ? 'yes':'no', 'shell');
            $doReset=1;
        }
        if ( $newtaghtml{'ksearch'} ne $tmplhtml{'ksearch'} ) {
            $ret = setCfgValue($defcfg, 'SEARCH_ENABLED', $newtaghtml{'ksearch'} eq 'ON' ? 'yes':'no', 'shell');
            # search config is also found in server.cfg plus 1st time might be commented out to default
            $ret = setCfgValue($svrcfg, 'search_enabled', $newtaghtml{'ksearch'} eq 'ON' ? 'yes':'no', '');
            setComment($svrcfg, 'search_enabled', 'off');
            $doReset=1;
        }
        if ( $newtaghtml{'kmonitor'} ne $tmplhtml{'kmonitor'} ) {
            $ret = setCfgValue($defcfg, 'MONITOR_ENABLED', $newtaghtml{'kmonitor'} eq 'ON' ? 'yes':'no', 'shell');
            $doReset=1;
        }
        if ( $newtaghtml{'kwrtc'} ne $tmplhtml{'kwrtc'} ) {
            $ret = setCfgValue($defcfg, 'WEBMEETINGS_ENABLED', $newtaghtml{'kwrtc'} eq 'ON' ? 'yes':'no', 'shell');
            $ret = setCfgValue($defcfg, 'PRESENCE_ENABLED', $newtaghtml{'kwrtc'} eq 'ON' ? 'yes':'no', 'shell');
            $doReset=1;
        }
        foreach my $tag (@strtags) { # string tags to package cfg
            if ( $newtaghtml{$tag} ne $tmplhtml{$tag} ) {
                $ret = setCfgValue($pkgcfg, $cfgparam{$tag}, $newtaghtml{$tag}, 'shstring');
                $tmplhtml{$tag}= $newtaghtml{$tag};
                $tmplhtml{'status'} .= "$tag updated. ";
				if ( $tag eq 'ksnr' ) {
					# update /etc/kopano/license/base with ksnr, ensure directory exists
                    system("mkdir -p /etc/kopano/license");
                    open(DAT, '>', "/etc/kopano/license/base");
                    print DAT "$newtaghtml{$tag}\n";
                }
            }
        }
        foreach my $tag (@numtags) { # number tags to package cfg
            # set to 0 if value is empty
            $tmplhtml{$tag} = 0 if ! $tmplhtml{$tag};
            $newtaghtml{$tag} = 0 if ! $newtaghtml{$tag};
            if ( $newtaghtml{$tag} ne $tmplhtml{$tag} ) {
                $ret = setCfgValue($pkgcfg, $cfgparam{$tag}, $newtaghtml{$tag}, 'shell');
                $tmplhtml{$tag}= $newtaghtml{$tag};
            }
        }
        if ( $doReset ) {
            system("/usr/local/bin/kopano4s-init reset nowait >/tmp/reset");
            $tmplhtml{'status'} .= "Resetting container. ";
        }
    }
    if ( $action eq "Show" || $action eq "Update" || $action eq "Replace" || $action eq "Reset" ) {
        my $cfile = ''; # cfg or plg file to show or update or reset
        my $ifile = ''; # cfg or plg file to reset from or save copy
        my $section = param('section'); 
        if ( $section eq 'cfg') { # the section config or plugin
            $scfg = param('scfg'); # the cfg selected to show
            $cfgpath = '/etc/kopano';
            $cfgpath .= '/webapp' if ($scfg =~ /webapp/); 
            $cfgpath = '/var/packages/MariaDB10/etc/my.cnf' if ($scfg =~ /my.cnf/); 
            $cfgpath = '/etc/z-push' if ($scfg =~ /z-push/) || ($scfg =~ /autodiscover/) || ($scfg =~ /caldav/) || ($scfg =~ /gabsync/); 
            $cfgpath = '/etc/z-push' if ($scfg =~ /gab2contacts/) || ($scfg =~ /kopano.conf/) || ($scfg =~ /policies/); 
            $cfile = "$cfgpath/$scfg";
            $ifile = $scfg . '.init';
        }
        else { # now plugin
            $splg = param('splg'); # the cfg selected to show
            $cfile = "/etc/kopano/webapp/plg.conf-$splg";
            $ifile = "/etc/kopano/webapp/dist/plg.conf-$splg";
        }
        if ( $action eq "Update" ) {
            my $entry = param ('cfgentry');
            $tmplhtml{'cfgentry'} = $entry;
            if ( $entry ne '' ) {
                if ( ! -e "$ifile" ) { # create an init copy b4 update
                    system("/bin/cp $cfile $ifile");
                }
                if ( $cfgpath ne '/etc/z-push' && $cfgpath ne '/etc/kopano/webapp' ) {
                    my ($key,$val) = split('=', $entry);
                    if ( $key && $val ) {
                        $key =~ s/^\s+|\s+$//g; # trim whitespaces
                        $val =~ s/^\s+|\s+$//g;
                        $ret = setCfgValue("$cfile", $key, $val, '');
                        $tmplhtml{'status'} = "Updated $cfile for $key = $val. ";
                        #$tmplhtml{'status'} .= $ret;
                    }
                }
                else {
                    my $key = substr($entry, 0, -9) ; # take 10 chars from end usually it is true vs. false
                    $ret = replacePatternValue("$cfile", $key, $entry, 'doublequotes');
                    $tmplhtml{'status'} = "Replaced in $cfile for $entry. ";
                }
            }
        }
        if ( $action eq "Replace" ) { # plg replace line mode
            my $entry = param ('plgentry');
            $tmplhtml{'plgentry'} = $entry;
            if ( $entry ne '' ) {
                my $key = substr($entry, 0, -9) ; # take 10 chars from end usually it is true vs. false
                $ret = replacePatternValue("$cfile", $key, $entry, '');
                $tmplhtml{'status'} = "Replaced in $cfile for $entry. ";
                #$tmplhtml{'status'} .= $ret;
            }
        }
        if ( $action eq "Reset" ) {
            if ( -e "$ifile" ) {
                system("/bin/cp $ifile $cfile");
                $tmplhtml{'status'} = "Reset $cfile with init file. ";
            }
            else {
                $tmplhtml{'status'} = "No init file exists to reset $cfile.."; 
            }
        }
        if (open(IN,"$cfile")) 
        {
            while (<IN>) {
                chomp;
                $cfgtxt .= "$_\n ";
            }
            close(IN);
        }
    }
    # fill dynamic html array with tags to be printed on pages
    $tmplhtml{'stuning'} .= '%';
    $tmplhtml{'chkfsattach'} = $tmplhtml{'kfsattach'} eq 'ON' ? 'checked' : ''; # in svr cfg 'files'
    $tmplhtml{'chkgateway'} = $tmplhtml{'kgateway'} eq 'ON' ? 'checked' : '';
    $tmplhtml{'chkical'} = $tmplhtml{'kical'} eq 'ON' ? 'checked' : '';
    $tmplhtml{'chksearch'} = $tmplhtml{'ksearch'} eq 'ON' ? 'checked' : '';
    $tmplhtml{'chkmonitor'} = $tmplhtml{'kmonitor'} eq 'ON' ? 'checked' : '';
    $tmplhtml{'chkkwrtc'} = $tmplhtml{'kwrtc'} eq 'ON' ? 'checked' : '';
    $tmplhtml{'chksyncssl'} = $tmplhtml{'ksyncssl'} eq 'ON' ? 'checked' : '';
    $tmplhtml{'chkforcessl'} = $tmplhtml{'kforcessl'} eq 'ON' ? 'checked' : '';
    $tmplhtml{'chknotify'} = $tmplhtml{'knotify'} eq 'ON' ? 'checked' : '';
    $tmplhtml{'cfgtxt'} = $cfgtxt;
    $tmplhtml{'cfgcmb'} = '';

    foreach my $cfg (@cfgfiles) {
        $tmplhtml{'cfgcmb'} .= "<option value=\"$cfg\"";
        $tmplhtml{'cfgcmb'} .= "selected" if $cfg eq $scfg;
        $tmplhtml{'cfgcmb'} .= ">$cfg</option>\n";
    }
    $tmplhtml{'plgcmb'} = '';
    foreach my $plg (@plgfiles) {
        $tmplhtml{'plgcmb'} .= "<option value=\"$plg\"";
        $tmplhtml{'plgcmb'} .= "selected" if $plg eq $splg;
        $tmplhtml{'plgcmb'} .= ">$plg</option>\n";
    }
    $tmplhtml{'localecmb'} = '';
    foreach my $locale (@locales) {
        $tmplhtml{'localecmb'} .= "<option value=\"$locale\"";
        $tmplhtml{'localecmb'} .= "selected" if $locale eq $tmplhtml{'slocale'};
        $tmplhtml{'localecmb'} .= ">$locale</option>\n";
    }
    $tmplhtml{'timezonecmb'} = '';
    foreach my $timezone (@timezones) {
        $tmplhtml{'timezonecmb'} .= "<option value=\"$timezone\"";
        $tmplhtml{'timezonecmb'} .= "selected" if $timezone eq $tmplhtml{'stimezone'};
        $tmplhtml{'timezonecmb'} .= ">$timezone</option>\n";
    }
    $tmplhtml{'tuningcmb'} = '';
    foreach my $tuning (@tunings) {
        $tmplhtml{'tuningcmb'} .= "<option value=\"$tuning\"";
        $tmplhtml{'tuningcmb'} .= "selected" if $tuning eq $tmplhtml{'stuning'};
        $tmplhtml{'tuningcmb'} .= ">$tuning</option>\n";
    }
    my $endTime = timegm(gmtime());
    my $sdiff = $endTime - $startTime;
    $tmplhtml{'status'} .= "Completed in $sdiff seconds.";

}
if ($page eq 'devices') 
{
    my $devcmb='';
    my $devtxt='';
    my $skey = param('devid'); # the selected key
    my $sid = ''; # the selected device-id in key
    my $susr = ''; # the selected user-id in key
    ($sid, $susr) = split(":" , $skey) if $skey;
    $action = 'ListAll' if !$action;
    # collect the device list for combo and lookup
    $cmdline = "kopano-devicelist csv |";
    if (open(DAT, $cmdline)) {
        @rawDataCmd = <DAT>;
        close(DAT);
        foreach my $reply (@rawDataCmd) {
            chomp($reply);
            $reply = '' if $reply =~ /Switching/; #hack in cmd-mode
            if ( $reply ) {
                my ($kuser,$device,$sync,$attn,$id) = split("," , $reply);
                my $item = $kuser . "_" . $device . "_Id:" . $id;
                my $key = $id . ":" . $kuser;
                if ( $id ne ' device-id' ) { # skip header
                    $devcmb .= "<option value=\"$key\"";
                    $devcmb .= "selected" if $key eq $skey;
                    $devcmb .= ">$item</option>\n";
                 }
             }
         }
    }
    # process command first
    if ($action eq 'Details') {
        $cmdline = "z-push-admin -a list -u $susr -d $sid |";
        if (open(DAT, $cmdline)) {
            @rawDataCmd = <DAT>;
            close(DAT);
            foreach my $reply (@rawDataCmd) {
                chomp($reply);
                $devtxt .= "$reply\n " if $reply ne '';
            }
        }
    }
    if ($action eq 'ReSync') {
        $cmdline = "z-push-admin -a resync -u $susr -d $sid |";
        if (open(DAT, $cmdline)) {
            @rawDataCmd = <DAT>;
            close(DAT);
            foreach my $reply (@rawDataCmd) {
                chomp($reply);
                $devtxt .= "$reply\n " if $reply ne '';
            }
        }
    }
    if ($action eq 'UnLoop') {
        $cmdline = "z-push-admin -a clearloop -u $susr -d $sid |";
        if (open(DAT, $cmdline)) {
            @rawDataCmd = <DAT>;
            close(DAT);
            foreach my $reply (@rawDataCmd) {
                chomp($reply);
                $devtxt .= "$reply\n " if $reply ne '';
            }
        }
    }
    if ($action eq 'Wipe') {
        $cmdline = "z-push-admin -a wipe -u $susr -d $sid |";
        if (open(DAT, $cmdline)) {
            @rawDataCmd = <DAT>;
            close(DAT);
            foreach my $reply (@rawDataCmd) {
                chomp($reply);
                $devtxt .= "$reply\n " if $reply ne '';
            }
        }
    }
    if ($action eq 'Remove') {
        $cmdline = "z-push-admin -a remove -u $susr -d $sid |";
        if (open(DAT, $cmdline)) {
            @rawDataCmd = <DAT>;
            close(DAT);
            foreach my $reply (@rawDataCmd) {
                chomp($reply);
                $devtxt .= "$reply\n " if $reply ne '';
            }
        }
    }
    if ($action eq 'ListAll') {
        $cmdline = "kopano-devicelist |";
        if (open(DAT, $cmdline)) {
            @rawDataCmd = <DAT>;
            close(DAT);
            foreach my $reply (@rawDataCmd) {
                chomp($reply);
                $devtxt .= "$reply\n ";
            }
        }
    }
    if ($action eq 'FixState') {
        $cmdline = "z-push-admin -a fixstates |";
        if (open(DAT, $cmdline)) {
            @rawDataCmd = <DAT>;
            close(DAT);
            foreach my $reply (@rawDataCmd) {
                chomp($reply);
                $devtxt .= "$reply\n ";
            }
        }
    }
    my $endTime = timegm(gmtime());
    my $sdiff = $endTime - $startTime;
    $devtxt .= "Command requests completed in $sdiff seconds.";
    # fill dynamic html array to be printed on pages
    $tmplhtml{'devcmb'} = $devcmb;
    $tmplhtml{'devtxt'} = $devtxt;
    $tmplhtml{'status'} = $status;
}
if ($page eq 'tools') 
{
    if ( $action eq 'List-IPs' ) {
        $cmdline = "/var/packages/Kopano4s/scripts/addon/kopano4s-autoblock.sh list |";
        if (open(DAT, $cmdline)) {
            @rawDataCmd = <DAT>;
            close(DAT);
            foreach my $reply (@rawDataCmd) {
                chomp($reply);
                $tmplhtml{'toolstxt'} .= "$reply\n ";
            }
        }
    }
    if ( $action eq 'Activate' ) {
        $cmdline = "/var/packages/Kopano4s/scripts/addon/kopano4s-optionals.sh autoblock on |";
        if (open(DAT, $cmdline)) {
            @rawDataCmd = <DAT>;
            close(DAT);
            foreach my $reply (@rawDataCmd) {
                chomp($reply);
                $tmplhtml{'toolstxt'} .= "$reply\n ";
            }
        }
    }
    if ( $action eq 'Disable' ) {
        $cmdline = "/var/packages/Kopano4s/scripts/addon/kopano4s-optionals.sh autoblock off |";
        if (open(DAT, $cmdline)) {
            @rawDataCmd = <DAT>;
            close(DAT);
            foreach my $reply (@rawDataCmd) {
                chomp($reply);
                $tmplhtml{'toolstxt'} .= "$reply\n ";
            }
        }
    }
}
if ($page eq 'log') 
{
    my $logtxt = '';
    my $slog = '';
    my $logpath = '';
    my $pkgcfg = '/var/packages/Kopano4s/etc/package.cfg'; # package cfg file location
    my $buppath = getCfgValue($pkgcfg, "K_BACKUP_PATH");
    my $logcmb = '';
    my $mode = param('mode'); # last 100 entries or all
    my @logfiles = ('server.log','spooler.log','mail.log','mail.info','mail.warn','mail.err','amavis.log','dagent.log',
                    'monitor.log','search.log','gateway.log','ical.log','z-push.log','z-push-error.log',
                    'fetchmail.log','presence.log','webmeetings.log','nginx-error.log','nginx-access.log',
                    'php-fpm.log','syslog','messages','mySqlDump.log','backup-user.log','restore-user.log');
    # process command first
    if ($action eq "Truncate") {
        $slog = param('slog'); # the log selected to show
        $logpath = '/var/log/kopano';
        $logpath .= '/z-push' if ($slog =~ /z-push/);
        $logpath = $buppath if ($slog =~ /-user.log/) || ($slog =~ /mySqlDump.log/);
        if ( $mode eq 'all' ) {
            system("/bin/echo '*** log truncated to zero ***' > $logpath/$slog");
        }
        else { # only tail -100
            system("/bin/tail -100 $logpath/$slog > /tmp/trlog");
            system("/bin/cat /tmp/trlog > $logpath/$slog");
            system("/bin/rm /tmp/trlog");
            system("/bin/echo '*** log truncated to 100 entries***' >> $logpath/$slog");
        }
        sleep 1;
        $action = "Show";
    }
    if ($action eq "Show") {
        $slog = param('slog'); # the log selected to show
        $logpath = '/var/log/kopano';
        $logpath .= '/z-push' if ($slog =~ /z-push/);
        $logpath = $buppath if ($slog =~ /-user.log/) || ($slog =~ /mySqlDump.log/);
        if ( $mode eq 'all' ) {
            if (open(IN,"$logpath/$slog")) 
            {
                while (<IN>) {
                    chomp;
                    $logtxt .= "$_\n ";
                }
                close(IN);
            }
        }
        else { # only tail -100
            $cmdline = "tail -100 $logpath/$slog |";
            if (open(DAT, $cmdline)) {
                @rawDataCmd = <DAT>;
                close(DAT);
                foreach my $reply (@rawDataCmd) {
                    chomp($reply);
                    $logtxt .= "$reply\n ";
                }
            }
        }
    }
    foreach my $log (@logfiles) {
        $logcmb .= "<option value=\"$log\"";
        $logcmb .= "selected" if $log eq $slog;
        $logcmb .= ">$log</option>\n";
    }
    # fill dynamic html array to be printed on pages
    $tmplhtml{'logcmb'} = $logcmb;
    $tmplhtml{'logtxt'} = $logtxt;
    if ( $mode eq 'all' ) {
        $tmplhtml{'chkall'} = 'checked';
        $tmplhtml{'chklast'} = '';
    }
    else {
        $tmplhtml{'chkall'} = '';
        $tmplhtml{'chklast'} = 'checked';
    }
}
if ($page eq 'cmd') 
{
    my $cmdtxt='';
    my $rcmd='';
    my $params='';
    my $cmdcmb='';
    my $pkgcfg = '/var/packages/Kopano4s/etc/package.cfg'; # package cfg file location
    my $buppath = getCfgValue($pkgcfg, "K_BACKUP_PATH");
    my @commands = ('kopano-admin', 'kopano-cli', 'kopano-storeadm', 'kopano-status', 'kopano-restart', 'kopano4s-init', 'kopano4s-optionals', 'kopano-postfix', 'kopano-fetchmail', 'kopano-backup', 'kopano4s-restore-user', 
                    'kopano4s-backup', 'kopano4s-downgrade', 'kopano4s-upgrade', 'kopano4s-attachment-tofs', 'kopano4s-replication', 'kopano-localize-folders', 'kopano-set-oof', 'kopano-pubfolders', 'kopano-folderlist', 'kopano-devicelist', 'z-push-admin');
    # process command first
    if ($action eq "Run") {
        $rcmd = param('rcmd');
        $params = param('params');
        # kopano-admin: help = blank and run from script-dir to avoid legacy issue
        $params = "" if ( $rcmd eq "kopano-admin" && $params eq "help" );
        $rcmd = "/var/packages/Kopano4s/scripts/wrapper/kopano-admin.sh" if ( $rcmd eq "kopano-admin" );
		# kopano-storeadm / kopano-cli: blank or help = -h(elp)
        $params = "-h" if ( ( $rcmd eq "kopano-storeadm" || $rcmd eq "kopano-cli" ) && ( $params eq "" || $params eq "help" ) );

        if ( ($rcmd eq "kopano-backup" || $rcmd eq "kopano4s-backup") && $params ne "help" ) {
            if ( $rcmd eq "kopano4s-backup" ) {
               system("/var/packages/Kopano4s/scripts/addon/kopano4s-backup.sh $params &>/dev/null 2>&1 &");
               $cmdline = "$buppath/mySqlDump.log";
               $cmdtxt = "Initial output of $buppath/mySqlDump.log please check log later\n ";
            }
            else {
               $params .= " -w 5" if !($params =~ /-w/);
               $params .= " -l INFO" if !($params =~ /-l/);
               system("/bin/sh /var/packages/Kopano4s/scripts/wrapper/kopano-backup.sh $params &>$buppath/backup-user.log 2>&1 &");
               $cmdline = "$buppath/backup-user.log";
               $cmdtxt = "Initial output of $buppath/backup-user.log please check log later\n ";
            }
            sleep 3;
            if (open(DAT, $cmdline)) {
                @rawDataCmd = <DAT>;
                close(DAT);
                foreach my $reply (@rawDataCmd) {
                    chomp($reply);
                    $cmdtxt .= "$reply\n ";
                }
            }
            $cmdtxt .= "Started as long running background job; check notification and logs for backup completion..  "
        }
		elsif ( ($rcmd eq "kopano4s-restore-user" || $rcmd eq "kopano4s-downgrade"  || $rcmd eq "kopano4s-upgrade" || $rcmd eq "kopano4s-attachment-tofs" ) && ($params eq "start" || $params eq "all") ) {
            if ( $rcmd eq "kopano4s-restore-user" ) {
               system("/var/packages/Kopano4s/scripts/addon/kopano4s-restore-user.sh $params &>/dev/null 2>&1 &");
               $cmdline = "$buppath/restore-user.log";
               $cmdtxt = "Initial output of $buppath/restore-user.log please check log later\n ";
            }
            elsif ( $rcmd eq "kopano4s-downgrade" ) {
               system("/var/packages/Kopano4s/scripts/addon/kopano4s-downgrade.sh $params &>/dev/null 2>&1 &");
               $cmdline = "$buppath/downgrade-steps.log";
               $cmdtxt = "Initial output of $buppath/downgrade-steps.log please check log later\n ";
            }
            elsif ( $rcmd eq "kopano4s-upgrade" ) {
               system("/var/packages/Kopano4s/scripts/addon/kopano4s-upgrade.sh $params &>/dev/null 2>&1 &");
               $cmdline = "$buppath/upgrade-steps.log";
               $cmdtxt = "Initial output of $buppath/downgrade-steps.log please check log later\n ";
            }
            else {
               system("/var/packages/Kopano4s/scripts/addon/kopano4s-attachment-tofs.sh $params &>/dev/null 2>&1 &");
               $cmdline = "$buppath/attm2fs-steps.log";
               $cmdtxt = "Initial output of $buppath/attm2fs-steps.log please check log later\n ";
            }
            sleep 3;
            if (open(DAT, $cmdline)) {
                @rawDataCmd = <DAT>;
                close(DAT);
                foreach my $reply (@rawDataCmd) {
                    chomp($reply);
                    $cmdtxt .= "$reply\n ";
                }
            }
            $cmdtxt .= "Started as long running background job; check notification and logs for job completion..  "
        }
        else {
            $cmdline = "$rcmd $params |";
            if (open(DAT, $cmdline)) {
                @rawDataCmd = <DAT>;
                close(DAT);
                foreach my $reply (@rawDataCmd) {
                    chomp($reply);
                    $cmdtxt .= "$reply\n ";
                }
            }
        }
        my $endTime = timegm(gmtime());
        my $sdiff = $endTime - $startTime;
        $cmdtxt .= "Command requests completed in $sdiff seconds.";
    }
    foreach my $cmd (@commands) {
        $cmdcmb .= "<option value=\"$cmd\"";
        $cmdcmb .= "selected" if $cmd eq $rcmd;
        $cmdcmb .= ">$cmd</option>\n";
    }
    # fill dynamic html array to be printed on pages
    $tmplhtml{'cmdcmb'} = $cmdcmb;
    $tmplhtml{'cmdtxt'} = $cmdtxt;
    $tmplhtml{'params'} = $params;
}
$tmplhtml{'debug'} = "<!-- debug info:" . $debug . "-->";
# *** end of process body

# *** process common tail: print html page
if (open(IN,"$page.htm")) {
    while (<IN>) {
        # add dynamic template-html part before printing page
        s/<!--:([^:]+):-->/$tmplhtml{$1}/g;
        print $_;
    }
    print "\n";
    close(IN);
}