if [ -n "$1" ]; then
        export EPICS_CA_ADDR_LIST=$1
else
        export EPICS_CA_ADDR_LIST=142.90.148.65
fi
#
#       CaPerl needs $EPICS_HOST_ARCH
#
export EPICS_CA_MAX_ARRAY_BYTES=5000000
export EPICS_HOST_ARCH=linux-x86
export EPICS_CA_AUTO_ADDR_LIST=YES
export EPICS_CA_REPEATER_PORT=9101
export EPICS_CA_SERVER_PORT=9102
export CA_PERL=/usr1/release_lib/perl
export PVconnections_PERL=/usr1/local/perllib/PVconnections
### Other EPICS stuff
export EPICS_TS_MIN_WEST=480
export EPICS_IOC_LOG_PORT=7004
export EPICS_IOC_LOG_INET=142.90.148.144
export EPICS_IOC_LOG_FILE_LIMIT=10000000
export EPICS_IOC_LOG_FILE_NAME=/usr1/isac/data/iocLog.text
export EPICS_AR_PORT=7002
export TRAR_ARCHIVE_DIRECTORY="/usr1/isac/data/arch"
