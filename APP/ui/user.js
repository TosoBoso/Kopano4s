	function pwdObfuscate() {
		var pwd2obf = document.getElementById('pwd').value;
		if ( pwd2obf.length > 2 && pwd2obf.substr(0, 2) != "PW" ) { // already obfuscaded as string wiht PW
			document.getElementById('pwd').value = "PW" + btoa(pwd2obf + "P");
		}
	}
	function newUser() {
		document.getElementById('frmUser').style.display = "block";
		document.getElementById('frmGroup').style.display = "none";
		document.getElementById('frmGroup2User').style.display = "none";
		document.getElementById('frmSendAs').style.display = "none";
		document.getElementById('btnModUsr').value = "Add";
		//document.getElementById('btnMod').style.visibility= "hidden";
	}
	function updateUser() {
		document.getElementById('frmUser').style.display = "block";
		document.getElementById('frmGroup').style.display = "none";
		document.getElementById('frmGroup2User').style.display = "none";
		document.getElementById('frmSendAs').style.display = "none";
		document.getElementById('btnModUsr').value = "Update";
	}
	function deleteUser() {
		document.getElementById('frmUser').style.display = "block";
		document.getElementById('frmGroup').style.display = "none";
		document.getElementById('frmGroup2User').style.display = "none";
		document.getElementById('frmSendAs').style.display = "none";
		document.getElementById('btnModUsr').value = "Delete";
	}
	function newGroup() {
		document.getElementById('frmUser').style.display = "none";
		document.getElementById('frmGroup').style.display = "block";
		document.getElementById('frmGroup2User').style.display = "none";
		document.getElementById('frmSendAs').style.display = "none";
		document.getElementById('btnModGrp').value = "Add";
	}
	function updateGroup() {
		document.getElementById('frmUser').style.display = "none";
		document.getElementById('frmGroup').style.display = "block";
		document.getElementById('frmGroup2User').style.display = "none";
		document.getElementById('frmSendAs').style.display = "none";
		document.getElementById('btnModGrp').value = "Update";
	}
	function deleteGroup() {
		document.getElementById('frmUser').style.display = "none";
		document.getElementById('frmGroup').style.display = "block";
		document.getElementById('frmGroup2User').style.display = "none";
		document.getElementById('frmSendAs').style.display = "none";
		document.getElementById('btnModGrp').value = "Delete";
	}
	function addUser() {
		document.getElementById('frmUser').style.display = "none";
		document.getElementById('frmGroup').style.display = "none";
		document.getElementById('frmGroup2User').style.display = "block";
		document.getElementById('frmSendAs').style.display = "none";
		document.getElementById('btnModGrp2Usr').value = "Added";
	}
	function removeUser() {
		document.getElementById('frmUser').style.display = "none";
		document.getElementById('frmGroup').style.display = "none";
		document.getElementById('frmGroup2User').style.display = "block";
		document.getElementById('frmSendAs').style.display = "none";
		document.getElementById('btnModGrp2Usr').value = "Removed";
	}
	function sendUser() {
		document.getElementById('frmUser').style.display = "none";
		document.getElementById('frmGroup').style.display = "none";
		document.getElementById('frmGroup2User').style.display = "none";
		document.getElementById('frmSendAs').style.display = "block";
		document.getElementById('lblSend').innerHTML = "Z-User:";
		document.getElementById('valSend').name = "zuser";
	}
	function sendGroup() {
		document.getElementById('frmUser').style.display = "none";
		document.getElementById('frmGroup').style.display = "none";
		document.getElementById('frmGroup2User').style.display = "none";
		document.getElementById('frmSendAs').style.display = "block";
		document.getElementById('lblSend').innerHTML = "Z-Group:";
		document.getElementById('valSend').name = "zgroup";		
	}
