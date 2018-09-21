#!/bin/bash

deviceDoRoots() {
	echo "    [#] Modify vendor for file-based encryption (a compatible TWRP is required) ..."
	verifyFilesExist "${miuiOutPath}/vendor/etc/fstab.qcom"
	sed -i -e '/userdata/ s/forceencrypt=footer/fileencryption=ice/' "${miuiOutPath}/vendor/etc/fstab.qcom"
	sed -i -e '/userdata/ s/encryptable=footer/fileencryption=ice/' "${miuiOutPath}/vendor/etc/fstab.qcom"
}

updaterScriptFooter() {
	echo "ui_print(\" \");"
	echo "ui_print(\"All done! Remember:\");"
	echo "ui_print(\" - Flash FBE-Disable ZIP to REMOVE\");"
	echo "ui_print(\"   file-based encryption (optional)\");"
	echo "ui_print(\" \");"
}