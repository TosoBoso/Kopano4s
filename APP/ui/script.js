	var windowResizeTo = window.resizeTo; // In case we want to put it back later
	window.resizeTo = function() {}; // disable resizing by dummy function

	window.addEventListener("resize", myResize);
	var x = 0;
	var w = window.top.innerWidth;
	var h = window.top.innerHeight;
	
	function myResize() {
		var txt = x += 1;
		document.getElementById("demo").innerHTML = txt;
		txt = w;
		document.getElementById("width").innerHTML = txt;
		txt = h;
		document.getElementById("height").innerHTML = txt;
	}
	
	
		var size = [window.width,window.height];  //public variable captured window size
		console.log("Startup w/h: " + size[0] + " / " + size[1]);
		//console.log(´Startup w/h: ${size[0]} ${size[1]}´);
		
	Ext.onReady(function() { // main event handler once loaded
		
		
		var size = [window.width,window.height];  //public variable captured window size
		Ext.EventManager.onWindowResize(function() {
		Ext.resizeTo(size[0],size[1]);
		//form.doLayout();
		//form.setHeight(estimateHeight());
		});
	}); // end of Ext.onReady



***********************************************************************
function estimateHeight() {
	var myWidth = 0, myHeight = 0;
	if( typeof( window.innerWidth ) == 'number' ) {
		//Non-IE
		myHeight = window.innerHeight;
	} else if( document.documentElement && ( document.documentElement.clientWidth || document.documentElement.clientHeight ) ) {
		//IE 6+ in 'standards compliant mode'
		myHeight = document.documentElement.clientHeight;
	} else if( document.body && ( document.body.clientWidth || document.body.clientHeight ) ) {
		//IE 4 compatible
		myHeight = document.body.clientHeight;
	}
	return myHeight;
}


Ext.onReady(function() {

    var conn = new Ext.data.Connection();

    function onComboClick(item){
		conn.request({
			url: 'getfile.cgi?'+Ext.urlEncode({action: combo.value}),
			success: function(responseObject) {
				texta.setValue(responseObject.responseText);
			}
		});
	}


	var combo = new Ext.form.ComboBox ({
		store: [==:names:==],
		name: 'file',
		shadow: true,
		editable: false,
		mode: 'local',
		triggerAction: 'all',
		emptyText: 'Choose Zarafa user',
		selectOnFocus: true
	});


	Ext.EventManager.onWindowResize(function() {
		form.doLayout();
		form.setHeight(estimateHeight());
	});

});
