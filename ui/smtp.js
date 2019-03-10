	function pwdObfuscate() {
		var pwd2obf = document.getElementById('pwd').value;
		if ( pwd2obf.length > 2 && pwd2obf.substr(0, 2) != "PW" ) { // already obfuscaded as string wiht PW
			document.getElementById('pwd').value = "PW" + btoa(pwd2obf + "P");
		}
	}
