#!/bin/bash

# Make release (flashable ZIP) ZIP

source ./bin/common_functions.sh

echo ""
echo "------------------------------------------"
echo "[i] make_release started."
echo ""

deviceId=UNKNOWNDEVICE
portId=UNKNOWNDEVICE
verIncremental=UNKNOWNVERSION
buildTimestamp=UNKNOWNTIMESTAMP
verHost=UNKNOWNHOST

refreshBuildInfo
zipFileName="miui-${deviceId}_${verIncremental}_${buildTimestamp}_${buildType}_${verHost}_${portId}-port.zip"
echo "[#] Starting release ZIP build..."
echo "    [i] ZIP filename:"
echo "        ${zipFileName}"

checkAndMakeTmp
rm -rf ./target/release
rm -f ./target/release.log
mkdir ./target/release
echo "[#] Building system|vendor.new.dat..."
./bin/img2sdat/img2sdat.py -o ./target/release/ -p system -v 4 ./target/system.img >> ./target/release.log &
./bin/img2sdat/img2sdat.py -o ./target/release/ -p vendor -v 4 ./target/vendor.img >> ./target/release.log &
wait
echo "[#] Compressing system|vendor.new.dat.br..."
brotli -j -v -q 5 ./target/release/system.new.dat &
brotli -j -v -q 5 ./target/release/vendor.new.dat &
wait
echo "[#] Copying boot.img..."
cp ./target/boot.img ./target/release/boot.img
echo "[#] Copying build.cfg..."
cp ./target/build.cfg ./target/release/build.cfg
echo "[#] Adding base_device files... (I hope it's a flashable-complete source!)"
rsync -a --ignore-existing \
	--exclude '*.txt' \
	--exclude 'system*' \
	--exclude 'vendor*' \
	--exclude 'file_contexts' \
	"./base_device/" "./target/release/"
echo "[#] Adding branding to updater-script..."
echo "ui_print(\" \");" > ./tmp/updater-script-header
echo "ui_print(\"##########################\");" >> ./tmp/updater-script-header
echo "ui_print(\"#  Built by CosmicDan's  #\");" >> ./tmp/updater-script-header
echo "ui_print(\"#      MIUI Kitchen      #\");" >> ./tmp/updater-script-header
echo "ui_print(\"##########################\");" >> ./tmp/updater-script-header
echo "ui_print(\" \");" >> ./tmp/updater-script-header
echo "ui_print(\"Target device: ${deviceId}\");" >> ./tmp/updater-script-header
echo "ui_print(\"Ported from: ${portId}\");" >> ./tmp/updater-script-header
echo "ui_print(\"MIUI flavor: ${verHost}\");" >> ./tmp/updater-script-header
echo "ui_print(\"MIUI version: ${verIncremental}\");" >> ./tmp/updater-script-header
echo "ui_print(\"Kitchen build: ${buildTimestamp}\");" >> ./tmp/updater-script-header
echo "ui_print(\"Build flavor: ${buildType}\");" >> ./tmp/updater-script-header
echo "ui_print(\" \");" >> ./tmp/updater-script-header

echo "ui_print(\" \");" >> ./tmp/updater-script-footer
echo "ui_print(\"All done! Remember:\");" >> ./tmp/updater-script-footer
echo "ui_print(\"1) Flash Magisk to avoid fastboot-kick!\");" >> ./tmp/updater-script-footer
echo "ui_print(\"2) Flash FBE-Disable ZIP to REMOVE\");" >> ./tmp/updater-script-footer
echo "ui_print(\"   file-based encryption (optional)\");" >> ./tmp/updater-script-footer
echo "ui_print(\" \");" >> ./tmp/updater-script-footer

cat ./tmp/updater-script-header ./base_device/META-INF/com/google/android/updater-script ./tmp/updater-script-footer > ./target/release/META-INF/com/google/android/updater-script

echo "[#] Zipping to ./${zipFileName} ..."
cd ./target/release
rm -f "../../${zipFileName}"
zip -r2 "../../${zipFileName}" . >> ../release.log
cd ../..


echo ""
echo "[i] make_release finished."
echo "------------------------------------------"
echo ""

cleanupTmp