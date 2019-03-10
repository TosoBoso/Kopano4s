	function pwdObfuscate() {
		var pwd2obf = document.getElementById('pwd').value;
		if ( pwd2obf.length > 2 && pwd2obf.substr(0, 2) != "PW" ) { // already obfuscaded as string wiht PW
			document.getElementById('pwd').value = "PW" + btoa(pwd2obf + "P");
		}
	}
	function addFetch() {
		document.getElementById('frmFetch').style.display = "block";
		document.getElementById('frmShost').style.display = "none";
		document.getElementById('btnModFetch').value = "Add";
	}
	function deleteFetch() {
		document.getElementById('frmFetch').style.display = "block";
		document.getElementById('frmShost').style.display = "none";
		document.getElementById('btnModFetch').value = "Delete";
	}
	function addShost() {
		document.getElementById('frmFetch').style.display = "none";
		document.getElementById('frmShost').style.display = "block";
		document.getElementById('btnModHost').value = "Add";
	}
	function deleteShost() {
		document.getElementById('frmFetch').style.display = "none";
		document.getElementById('frmShost').style.display = "block";
		document.getElementById('btnModHost').value = "Delete";
	}
