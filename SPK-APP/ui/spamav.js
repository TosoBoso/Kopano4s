// getSPF JS from spfwizard.net and openspf.org
function getSPF()
{
    var str;
    var domain;
    var mx_O;
    var ip_O;
    var host_O;
    var ips;
    var ips_arr;
    var hosts;
    var hosts_arr;
    var domains;
    var domains_arr;
    var restrict_O;
    domain = document.getElementById('domain').value;
    mx_O = document.getElementById('mx_allow').value;
    host_O = document.getElementById('host_allow').value;
    ips = document.getElementById('ip_additional').value;
    hosts = document.getElementById('host_additional').value;
    domains = document.getElementById('domain_additional').value;
    restrict_O = document.getElementById('restrict').value;
    str = domain + '.' + ' IN TXT "v=spf1';
    switch (mx_O)
    {
        case "0":
            break;
        case "1":
            str = str + ' mx';
            break;
    }
    switch (host_O)
    {
        case "0":
            break;
        case "1":
            str = str + ' ptr';
            break;
    }
    ips_arr = ips.split(" ");
    if (ips_arr.length == 1)
    {
        if (ips == "")
        {
        }
        else
        {
            str = str + ' ip4:' + ips;
        }
    }
    else
    {
        for (a=0; a<ips_arr.length; a++)
        {
            if (ips_arr[a] != "")
            {
                str = str + ' ip4:' + ips_arr[a];
            }
        }
    }
    hosts_arr = hosts.split(" ");
    if (hosts_arr.length == 1)
    {
        if (hosts == "")
        {
        }
        else
        {
            str = str + ' a:' + hosts;
        }
    }
    else
    {
        for (a=0; a<hosts_arr.length; a++)
        {
            if (hosts_arr[a] != "")
            {
                str = str + ' a:' + hosts_arr[a];
            }
        }
    }
    domains_arr = domains.split(" ");
    if (domains_arr.length == 1)
    {
        if (domains == "")
        {
        }
        else
        {
            str = str + ' include:' + domains;
        }
    }
    else
    {
        for (a=0; a<domains_arr.length; a++)
        {
            if (domains_arr[a] != "")
            {
                str = str + ' include:' + domains_arr[a];
            }
        }
    }
    switch (restrict_O)
    {
        case "0":
            break;
        case "1":
            str = str + ' -all';
            break;
        case "2":
            str = str + ' ~all';
            break;
        case "3":
            str = str + ' ?all';
            break;
    }
    str = str + '"';
    document.getElementById('dnsentry').value = str;
}
// on load get tab element with id="defaultOpen" and click on it from w3schools.com/howto/howto_js_tabs.asp
document.getElementById("defaultTab").click();