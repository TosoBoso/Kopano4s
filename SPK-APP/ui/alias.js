	function newAlias() {
		document.getElementById('frmAlias').style.display = "block";
		document.getElementById('frmRcpBcc').style.display = "none";
		document.getElementById('frmSdrBcc').style.display = "none";
		document.getElementById('frmBonce').style.display = "none";
		document.getElementById('btnModAlias').value = "Add";
		//document.getElementById('btnMod').style.visibility= "hidden";
	}
	function updateAlias() {
		document.getElementById('frmAlias').style.display = "block";
		document.getElementById('frmRcpBcc').style.display = "none";
		document.getElementById('frmSdrBcc').style.display = "none";
		document.getElementById('frmBonce').style.display = "none";
		document.getElementById('btnModAlias').value = "Update";
	}
	function deleteAlias() {
		document.getElementById('frmAlias').style.display = "block";
		document.getElementById('frmRcpBcc').style.display = "none";
		document.getElementById('frmSdrBcc').style.display = "none";
		document.getElementById('frmBonce').style.display = "none";
		document.getElementById('btnModAlias').value = "Delete";
	}
	function newRcpBcc() {
		document.getElementById('frmAlias').style.display = "none";
		document.getElementById('frmRcpBcc').style.display = "block";
		document.getElementById('frmSdrBcc').style.display = "none";
		document.getElementById('frmBonce').style.display = "none";
		document.getElementById('btnModRcpBcc').value = "Add";
	}
	function updateRcpBcc() {
		document.getElementById('frmAlias').style.display = "none";
		document.getElementById('frmRcpBcc').style.display = "block";
		document.getElementById('frmSdrBcc').style.display = "none";
		document.getElementById('frmBonce').style.display = "none";
		document.getElementById('btnModRcpBcc').value = "Update";
	}
	function deleteRcpBcc() {
		document.getElementById('frmAlias').style.display = "none";
		document.getElementById('frmRcpBcc').style.display = "block";
		document.getElementById('frmSdrBcc').style.display = "none";
		document.getElementById('frmBonce').style.display = "none";
		document.getElementById('btnModRcpBcc').value = "Delete";
	}
	function newSdrBcc() {
		document.getElementById('frmAlias').style.display = "none";
		document.getElementById('frmRcpBcc').style.display = "none";
		document.getElementById('frmSdrBcc').style.display = "block";
		document.getElementById('frmBonce').style.display = "none";
		document.getElementById('btnModSdrBcc').value = "Add";
	}
	function updateSdrBcc() {
		document.getElementById('frmAlias').style.display = "none";
		document.getElementById('frmRcpBcc').style.display = "none";
		document.getElementById('frmSdrBcc').style.display = "block";
		document.getElementById('frmBonce').style.display = "none";
		document.getElementById('btnModSdrBcc').value = "Update";
	}
	function deleteSdrBcc() {
		document.getElementById('frmAlias').style.display = "none";
		document.getElementById('frmRcpBcc').style.display = "none";
		document.getElementById('frmSdrBcc').style.display = "block";
		document.getElementById('frmBonce').style.display = "none";
		document.getElementById('btnModSdrBcc').value = "Delete";
	}	
	function modifyBounce() {
		document.getElementById('frmAlias').style.display = "none";
		document.getElementById('frmRcpBcc').style.display = "none";
		document.getElementById('frmSdrBcc').style.display = "none";
		document.getElementById('frmBonce').style.display = "block";
	}
