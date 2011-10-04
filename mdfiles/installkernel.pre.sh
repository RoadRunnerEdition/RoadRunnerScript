#ifdef DEVICE_LGP990

#define BOOT_PARTITION 		/dev/block/mmcblk0p5
#define SYSTEM_PARTITION	/dev/block/mmcblk0p1
#define DATA_PARTITION		/dev/block/mmcblk0p8

#define SECONDARY_INIT		init.p990.rc

#define BOOT_PAGESIZE 		0x800
#define BOOT_CMDLINE 		"mem=383M@0M nvmem=128M@384M loglevel=0 muic_state=1 lpj=9994240 CRC=3010002a8e458d7 vmalloc=256M brdrev=1.0 video=tegrafb console=ttyS0,115200n8 usbcore.old_scheme_first=1 tegraboot=sdmmc tegrapart=recovery:35e00:2800:800,linux:34700:1000:800,mbr:400:200:800,system:600:2bc00:800,cache:2c200:8000:800,misc:34200:400:800,userdata:38700:c0000:800 androidboot.hardware=p990"
#define BOOT_BASE			0x10000000

#define HAS_CM
#define HAS_MIUI

#define IS_PHONE

#define EXT4_RDY
#define USES_BITRATE
#define HAS_EPENIS_MODE

#endif // DEVICE_LGP990

#ifdef DEVICE_LGP990
device=LGP990
#endif

ui_print() {
    echo ui_print "$@" 1>&$UPDATE_CMD_PIPE;
    if [ -n "$@" ]; then
        echo ui_print 1>&$UPDATE_CMD_PIPE;
    fi
}
log () { echo "$@"; }
fatal() { ui_print "$@"; exit 1; }

basedir=`dirname $0`
BB=/sbin/busybox
awk="$BB awk"
chmod="$BB chmod"
gunzip="$BB gunzip"
cpio="$BB cpio"
find="$BB find"
gzip="$BB gzip"
warning=0
#ifdef DEVICE_LGP990
ril=0
#endif
#ifdef EXT4_RDY
ext4=0
#endif
#ifdef USES_BITRATE
bit=0
#endif
dvalue=0
#ifdef IS_PHONE
ring=0
#endif
#ifdef EXT4_RDY
extrdy=1
#endif
#ifdef DEVICE_LGP990
int2ext=0
#endif
#ifdef HAS_EPENIS_MODE
epenis=0
#endif

updatename=`echo $UPDATE_FILE | $awk '{ sub(/^.*\//,"",$0); sub(/.zip$/,"",$0); print }'`
kernelver=`echo $updatename | $awk 'BEGIN {RS="-"; ORS="-"}; NR<=2 {print; ORS=""}'`
args=`echo $updatename | $awk 'BEGIN {RS="-"}; NR>2 {print}'`

log ""
log "Kernel script started. Installing $UPDATE_FILE in $basedir"
log ""
ui_print ""
ui_print "Installing $kernelver"
ui_print "Developed by Benee and kiljacken"
ui_print ""
ui_print "Checking ROM..."

#ifdef HAS_CM
cymo=`cat /system/build.prop | $awk 'tolower($0) ~ /cyanogenmod/ { printf "1"; exit 0 }'`
#endif // HAS_CM

#ifdef HAS_MIUI
miui=`cat /system/build.prop | $awk 'tolower($0) ~ /miui/ { printf "1"; exit 0 }'`
#endif // HAS_MIUI


if [ "$cymo" == "1" ]; then
    log "Installing on CyanogenMod"
elif [ "$miui" == "1" ]; then
    log "Installing on Miui"
elif [ "$sense" == "1" ]; then
    log "Installing on Sense"
else
    fatal "Current ROM is not compatible with vorkKernel! Aborting..."
fi

ui_print "Packing kernel..."

cd $basedir

log "dumping previous kernel image to $basedir/boot.old"
$BB dd if=BOOT_PARTITION of=$basedir/boot.old
if [ ! -f $basedir/boot.old ]; then
	fatal "ERROR: Dumping old boot image failed"
fi

log "Unpacking boot image..."
log ""
ramdisk="$basedir/boot.old-ramdisk.gz"
$basedir/unpackbootimg -i $basedir/boot.old -o $basedir/ -p BOOT_PAGESIZE
if [ "$?" -ne 0 -o ! -f $ramdisk ]; then
    fatal "ERROR: Unpacking old boot image failed (ramdisk)"
fi

mkdir $basedir/ramdisk
cd $basedir/ramdisk
log "Extracting ramdisk"
$gunzip -c $basedir/boot.old-ramdisk.gz | $cpio -i

if [ ! -f init.rc ]; then
    fatal "ERROR: Unpacking ramdisk failed!"
elif [ ! -f SECONDARY_INIT ]; then
    fatal "ERROR: Invalid ramdisk!"
fi

log "Applying init.rc tweaks..."
cp init.rc ../init.rc.org
$awk -v device=$device -f $basedir/initrc.awk ../init.rc.org > ../init.rc.mod

FSIZE=`ls -l ../init.rc.mod | $awk '{ print $5 }'`
log "init.rc.mod filesize: $FSIZE"

if [[ -s ../init.rc.mod ]]; then
  mv ../init.rc.mod init.rc
else
  ui_print "Applying init.rc tweaks failed! Continue without tweaks"
  warning=$((warning + 1))
fi

log "Build new ramdisk..."
$BB find . | $BB cpio -o -H newc | $BB gzip > $basedir/boot.img-ramdisk.gz
if [ "$?" -ne 0 -o ! -f $basedir/boot.img-ramdisk.gz ]; then
	fatal "ERROR: Ramdisk repacking failed!"
fi

cd $basedir

log "Building boot.img..."
$basedir/mkbootimg --kernel $basedir/zImage --ramdisk $basedir/boot.img-ramdisk.gz --cmdline BOOT_CMDLINE -o $basedir/boot.img --base BOOT_BASE
if [ "$?" -ne 0 -o ! -f boot.img ]; then
    fatal "ERROR: Packing kernel failed!"
fi

ui_print ""
ui_print "Flashing the kernel..."
$BB dd if=/dev/zero of=BOOT_PARTITION
$BB dd if=$basedir/boot.img of=BOOT_PARTITION
if [ "$?" -ne 0 ]; then
    fatal "ERROR: Flashing kernel failed!"
fi

ui_print ""
ui_print "Installing kernel modules..."
rm -rf /system/lib/modules
cp -r files/lib/modules /system/lib/
if [ "$?" -ne 0 -o ! -d /system/lib/modules ]; then
    ui_print "WARNING: kernel modules not installed!"
    warning=$((warning + 1))
fi

ui_print ""
ui_print "Installing Ramzswap..."
rm system/bin/rzscontrol
cp files/bin/rzscontrol /system/bin/
if [ "$?" -ne 0 -o ! -f /system/bin/rzscontrol ]; then
    ui_print "WARNING: Ramzswap not installed! 1/3"
    warning=$((warning + 1))
fi

rm system/etc/init.d/02zramenabled
cp files/etc/init.d/02zramenabled /system/etc/init.d/
if [ "$?" -ne 0 -o ! -f /system/etc/init.d/02zramenabled ]; then
    ui_print "WARNING: Ramzswap not installed! 2/3"
    warning=$((warning + 1))
fi

rm system/etc/init.d/99complete
cp files/etc/init.d/99complete /system/etc/init.d/
if [ "$?" -ne 0 -o ! -f /system/etc/init.d/99complete ]; then
    ui_print "WARNING: Ramzswap not installed! 3/3"
    warning=$((warning + 1))
fi

ui_print ""
if [ $warning -gt 0 ]; then
    ui_print "$kernelver installed with $warning warnings."
else
    ui_print "$kernelver installed successfully. Enjoy"
fi
