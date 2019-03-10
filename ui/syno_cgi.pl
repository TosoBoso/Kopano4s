#**************************************************************************#
#  syno_cgi.pl                                                             #
#  Description: Script to get the query parameters and permissions of      #
#               active user for the calling perl 3rd party application.    #
#               Replaces the need for CGI.pm no longer shipped in DSM-6.   #
#               my $p = param ('foo') provides get parameter same as CGI.  #
#               my ($a,$u,$t) = usr_priv() provides user sys priviledges.  #
#               my ($a,$u,$t) = app_priv() provides user app priviledges.  #
#               $a=in admin grp, $u=name of active user, $t=syno token.    #
#  Author:      QTip & TosoBoso from the german Synology support forum.    #
#  Copyright:   2016-2017 by QTip & TosoBoso                               #
#  License:     GNU GPLv3 (see LICENSE)                                    #
#  ------------------------------------------------------------------- --  #
#  Version:     0.1 - 04/23/2017                                           #
#**************************************************************************#
my $rpInitialised = 0; # to have requestParams only loaded once
my $reqParams; # html query string captured from cgi

sub param { # only works for html-get parameters
    my $rp = shift; # the get request parameter
    return '' if ( !$rp || !$ENV{'REQUEST_METHOD'} ); # exit if no request set
    # parse once url params from query string this will catch anything after the "?"
    if( ($ENV{'REQUEST_METHOD'} eq 'GET') && $ENV{'QUERY_STRING'} && !$rpInitialised) {
        my @TempArray = split("&", $ENV{'QUERY_STRING'});
        foreach my $item (@TempArray) {
            my ($key, $value)=split("=", $item); # pragmatic will only work with one "=" in the value
            # now we do on the value uri_unescape equivalent without using the module incl. replacing + -> ' '
            $value =~ s/\+/ /g;
            $value =~ s/%([A-Fa-f\d]{2})/chr hex $1/eg;
            $reqParams->{lc($key)}=$value; # normalize to lower case
            $rpInitialised = 1;
        }
    }    
    return $reqParams->{$rp};
}
sub usr_priv { # old way: admin priviledge on system level via etc-group
     my $isAdmin = 0;
     my $user = '';
     my $token = '';
     # save http_get environment and restore later to get syno-cgi working for token and user
     my $tmpenv = $ENV{'QUERY_STRING'};
     my $tmpreq = $ENV{'REQUEST_METHOD'};
     $ENV{'QUERY_STRING'}="";
     $ENV{'REQUEST_METHOD'} = 'GET';
     # get the synotoken to verify login
     if (open (IN,"/usr/syno/synoman/webman/login.cgi|")) {
         while(<IN>) {
             if (/SynoToken/) { ($token)=/SynoToken" *: *"([^"]+)"/; }
         }
         close(IN);
     }
     if ( $token ne '' ) { # no token no query respecively in cmd-line mode
         $ENV{'QUERY_STRING'}="SynoToken=$token";
         $ENV{'X-SYNO-TOKEN'} = $token;
         if (open (IN,"/usr/syno/synoman/webman/modules/authenticate.cgi|")) {
             $user=<IN>;
             chop($user);
             close(IN);
         }
         $ENV{QUERY_STRING} = $tmpenv;
         $ENV{'REQUEST_METHOD'} = $tmpreq;
     }
     else
     {
         $ENV{QUERY_STRING} = $tmpenv;
         $ENV{'REQUEST_METHOD'} = $tmpreq;
         return (0,'','');
     }
     # verify if active user is part of administrators group
     if ( $user eq 'admin' ) { # that was easy
         $isAdmin = 1;
     }
     else { # verify user being part of system admin group
         if (open (IN,"/etc/group")) {
             while(<IN>) {
                 $isAdmin = 1 if ( /administrators:/ && /$user/ );
             }
             close(IN);
         }
     }     
     return ($isAdmin,$user,$token);
}
sub app_priv { # new way: admin priviledge on syno app level
     my $appName = shift;
     my $appPrivilege = 0;
     my $isAdmin = 0;
     my $user = '';
     my $token = '';
     my $rawData = '';
     use JSON::XS;
     use Data::Dumper;
     # save http_get environment and restore later to get syno-cgi working for token and user
     my $tmpenv = $ENV{'QUERY_STRING'};
     my $tmpreq = $ENV{'REQUEST_METHOD'};
     $ENV{'QUERY_STRING'}="";
     $ENV{'REQUEST_METHOD'} = 'GET';
     # get the synotoken to verify login
     if (open (IN,"/usr/syno/synoman/webman/login.cgi|")) {
         while(<IN>) {
             if (/SynoToken/) { ($token)=/SynoToken" *: *"([^"]+)"/; }
         }
         close(IN);
     }
     if ( $token ne '' ) { # no token no query respecively in cmd-line mode
         my $tmpenv = $ENV{'QUERY_STRING'};
         my $tmpreq = $ENV{'REQUEST_METHOD'};
         $ENV{'QUERY_STRING'}="SynoToken=$token";
         $ENV{'X-SYNO-TOKEN'} = $token;
         if (open (IN,"/usr/syno/synoman/webman/modules/authenticate.cgi|")) {
             $user=<IN>;
             chop($user);
             close(IN);
         }
         $ENV{QUERY_STRING} = $tmpenv;
         $ENV{'REQUEST_METHOD'} = $tmpreq;
     }
     else
     {
         $ENV{QUERY_STRING} = $tmpenv;
         $ENV{'REQUEST_METHOD'} = $tmpreq;
         return (0,'','');
     }
     # verify user allowed admin on application level
     # get dsm build
     my $dsmbuild = `/bin/get_key_value /etc.defaults/VERSION buildnumber`;
     chomp($dsmbuild);
     if ($dsmbuild >= 7307) {
          $rawData = `/usr/syno/bin/synowebapi --exec api=SYNO.Core.Desktop.Initdata method=get version=1 runner=$user`;
          $initdata = JSON::XS->new->decode($rawData);
          $appPrivilege = (defined $initdata->{'data'}->{'AppPrivilege'}->{$appname}) ? 1 : 0;
          $isAdmin = (defined $initdata->{'data'}->{'Session'}->{'is_admin'} && $initdata->{'data'}->{'Session'}->{'is_admin'} == 1) ? 1 : 0;
     } else {
          $rawData = `/usr/syno/synoman/webman/initdata.cgi`;
          $rawData = substr($rawData,index($rawData,"{")-1);
          $initdata = JSON::XS->new->decode($rawData);
          $appPrivilege = (defined $initdata->{'AppPrivilege'}->{$appname}) ? 1 : 0;
          $isAdmin = (defined $initdata->{'Session'}->{'is_admin'} && $initdata->{'Session'}->{'is_admin'} == 1) ? 1 : 0;
     }
     # if application not found or user not admin, return empty string
     return (0,'','') unless ($appPrivilege || $isAdmin);
     return ($isAdmin,$user,$token);
}
# return true for included libraries
1;
