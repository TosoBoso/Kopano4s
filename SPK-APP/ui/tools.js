var queryString = (function(a) {
    if (a == "") return {};
    var b = {};
    for (var i = 0; i < a.length; ++i)
    {
        var p=a[i].split('=', 2);
        if (p.length == 1)
            b[p[0]] = "";
        else
            b[p[0]] = decodeURIComponent(p[1].replace(/\+/g, " "));
    }
    return b;
})(location.search.substr(1).split('&'));
// on load get tab element from queryString and click on it from w3schools.com/howto/howto_js_tabs.asp
if (queryString["tab"] == undefined) {
	document.getElementById('autoblock').click();
}
else {
	document.getElementById(queryString["tab"]).click();
}
