#!/bin/bash

# Make release (flashable ZIP) ZIP

source ./bin/common_functions.sh

echo ""
echo "------------------------------------------"
echo "[i] 95_make_release started."
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
echo "[#] Building system.new.dat..."
./bin/img2sdat/img2sdat.py -o ./target/release/ -p system -v 4 ./target/system.img >> ./target/release.log
echo "    [#] Compressing to system.new.dat.br..."
brotli -j -v -q 5 ./target/release/system.new.dat
echo "[#] Building vendor.new.dat..."
./bin/img2sdat/img2sdat.py -o ./target/release/ -p vendor -v 4 ./target/vendor.img >> ./target/release.log
echo "    [#] Compressing to vendor.new.dat.br..."
brotli -j -v -q 5 ./target/release/vendor.new.dat
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
echo "ui_print(\" \");" > ./tmp/header
echo "ui_print(\"##########################\");" >> ./tmp/header
echo "ui_print(\"#  Built by CosmicDan's  #\");" >> ./tmp/header
echo "ui_print(\"#      MIUI Kitchen      #\");" >> ./tmp/header
echo "ui_print(\"##########################\");" >> ./tmp/header
echo "ui_print(\" \");" >> ./tmp/header
echo "ui_print(\"Target device: ${deviceId}\");" >> ./tmp/header
echo "ui_print(\"Ported from: ${portId}\");" >> ./tmp/header
echo "ui_print(\"MIUI flavor: ${verHost}\");" >> ./tmp/header
echo "ui_print(\"MIUI version: ${verIncremental}\");" >> ./tmp/header
echo "ui_print(\"Kitchen build: ${buildTimestamp}\");" >> ./tmp/header
echo "ui_print(\" \");" >> ./tmp/header
cat ./tmp/header ./base_device/META-INF/com/google/android/updater-script > ./target/release/META-INF/com/google/android/updater-script

echo "[#] Zipping to ./${zipFileName} ..."
cd ./target/release
zip -r9 "../../${zipFileName}" . >> ../release.log
cd ../..


echo ""
echo "[i] 95_make_release finished."
echo "------------------------------------------"
echo ""

cleanupTmp