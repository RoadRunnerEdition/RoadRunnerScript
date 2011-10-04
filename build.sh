#!/bin/bash
# Static variables
EABI="${HOME}/android/system/prebuilt/linux-x86/toolchain/arm-eabi-4.4.3/bin"
storage_dir="$HOME/Kernel"
source_dir="$HOME"
script_dir="$source_dir/android/RoadRunnerScript"
start_dir="`pwd`"
cores="`grep processor /proc/cpuinfo | wc -l`"
now="`date +"%Y%m%d"`"

# Functions
function die () { echo $@; exit 1; }

echo "RoadRunnerKernel"
# Device variables
devices="St Ba"

# Device specific functions
function St_zip() {
	case $1 in
		"do")   
			cp $script_dir/mdfiles/update-binary $script_dir/update.zip/META-INF/com/google/android/
			cp $script_dir/mdfiles/unpackbootimg $script_dir/update.zip/tmp/REKernel/
			cp $script_dir/mdfiles/mkbootimg $script_dir/update.zip/tmp/REKernel/
			cp $script_dir/mdfiles/busybox $script_dir/update.zip/tmp/REKernel/
#			cp -r $script_dir/mdfiles/ril $script_dir/update.zip/tmp/REKernel/files                       
		;;
		"clean")
			rm $script_dir/update.zip/META-INF/com/google/android/update-binary
			rm $script_dir/update.zip/tmp/REKernel/unpackbootimg
			rm $script_dir/update.zip/tmp/REKernel/mkbootimg
			rm $script_dir/update.zip/tmp/REKernel/busybox
#			rm -r $script_dir/update.zip/tmp/REKernel/files/ril
		;;
	esac
}
function Ba_zip() {
	case $1 in
		"do")   
			cp $script_dir/mdfiles/update-binary $script_dir/update.zip/META-INF/com/google/android/
			cp $script_dir/mdfiles/unpackbootimg $script_dir/update.zip/tmp/REKernel/
			cp $script_dir/mdfiles/mkbootimg $script_dir/update.zip/tmp/REKernel/
#			cp $script_dir/mdfiles/busybox $script_dir/update.zip/tmp/REKernel/
#			cp -r $script_dir/mdfiles/ril $script_dir/update.zip/tmp/REKernel/files                       
		;;
		"clean")
			rm $script_dir/update.zip/META-INF/com/google/android/update-binary
			rm $script_dir/update.zip/tmp/REKernel/unpackbootimg
			rm $script_dir/update.zip/tmp/REKernel/mkbootimg
#			rm $script_dir/update.zip/tmp/REKernel/busybox
#			rm -r $script_dir/update.zip/tmp/REKernel/files/ril
		;;
	esac
}
# Cleanup
release=
build_device=

if [ $# -gt 0 ]; then
	input=$1
else
	i=1
	for device in $devices; do
		echo "$i) $device Release"
		i=$(($i+1))
		echo "$i) $device Test"
		i=$(($i+1))
	done
	echo "Choose a device:"
	read input
fi

i=1
for device in $devices; do
	if [ "$input" == $i ]; then # This is a release build
		release="release"
		build_device=$device
		break
	fi
	i=$(($i+1))
	
	if [ "$input" == $i ]; then # This is a test build
		release="test"
		build_device=$device
		break
	fi
	i=$(($i+1))
done

if [ "$release" == "release" ]; then
	zip_location=~/android/kernel-zip/Kernel-$build_device/RoadRunnerKernel-$build_device-$now.zip

elif [ "$release" == "test" ]; then
	zip_location=~/android/kernel-zip/Kernel-$build_device/REKernelTEST-$build_device-$now.zip
fi

echo "Setting up a LG build"

if [ "$release" == "" -o "$device" == "" ]; then # No device has been chosen
	die "ERROR: Please choose a device"
fi

#if [ "devices" == "RoadRunnerKernel" ]; then
if [ ! -d ~/android/RoadRunnerKernel-$build_device ]; then
	die "Could not find kernel source for $build_device"
fi

export CCOMPILER=${EABI}/arm-eabi-

cd ~/android/RoadRunnerKernel-$build_device || exit
${CCOMPILER}gcc --verbose || exit # show the cross compiler

echo "Pull RoadRunner Git..."
git pull

echo "Grabbing Defconf..."
cp arch/arm/configs/REkernel_defconfig .config

make ARCH=arm CROSS_COMPILE=$CCOMPILER oldconfig 

echo "Make build..."
make ARCH=arm CROSS_COMPILE=$CCOMPILER -j`grep 'processor' /proc/cpuinfo | wc -l`

echo "Grabbing zImage..."
cp $source_dir/android/RoadRunnerKernel-$build_device/arch/arm/boot/zImage $script_dir/update.zip/tmp/REKernel/zImage

echo "Grabbing kernel modules..."
for module in `find $source_dir/android/RoadRunnerKernel-$build_device -name *.ko`
do
    cp $module $script_dir/update.zip/tmp/REKernel/files/lib/modules/

echo "Grabbing Ramzswap modules..."
cp -r $source_dir/android/ramzswap/* $script_dir/update.zip/tmp/REKernel/files/
done

echo "Making update zip..."
echo "#!/sbin/sh" > $script_dir/update.zip/tmp/REKernel/installkernel.sh
cpp -D DEVICE_$build_device $script_dir/mdfiles/installkernel.pre.sh | awk '/# / { next; } { print; }' >> $script_dir/update.zip/tmp/REKernel/installkernel.sh
"$build_device"_zip do
cd $script_dir/update.zip/
zip -qr $zip_location *
cd -
"$build_device"_zip clean

cd $source_dir/android/RoadRunnerScript


