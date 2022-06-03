#!/bin/bash

#DB info
USERNAME="root"
PASSWORD="myadmin"
MYSQL_CNF="/data/db/mysql3676/my.cnf"
MYSQL_SOC="/data/db/mysql3676/mysql3676.sock"
MYSQL_CONNECT="--socket=${MYSQL_SOC} --user=${USERNAME} --password=${PASSWORD}"

#Mysql Tools
MYSQL_ADMIN="/usr/local/mysql/bin/mysqladmin"
MYSQL_CLI="/usr/local/mysql/bin/mysql"
BACKUP_TOOL="/usr/bin/innobackupex --defaults-file=$MYSQL_CNF --compress --compress-threads=2 --slave-info  --parallel=2"

#Other tools
ECHO="/bin/echo"
AWK="/bin/awk"

#Limitations
FULL_BACKUP_GAP=518400 # Lifetime of the latest full backup in seconds (6天)

#Runtime variables
TIME_START=`date +"%s"`
DATE_TODAY=`date +"%Y%m%d"`

#All Directories or Files
DIR_DATABASE=""
DIR_BACKUP_BASE="/data/backup"
DIR_BACKUP_FULL=$DIR_BACKUP_BASE/full # Full backups directory
DIR_BACKUP_INCR=$DIR_BACKUP_BASE/incr # Incremental backups directory
EXECUTE_LOG="/var/log/xtra-mysql-backup-${DATE_TODAY}.log"
TMPFILE="/tmp/xtra-mysql_runner.$$.tmp"

#put the variables
back_data=$1


verbose() {
    $ECHO "$1"
}

dolog() {
    $ECHO "$1"  >> $EXECUTE_LOG
}

inform() {
    dolog "`date +%F_%T` [INFO]  $1"
    verbose "`date +%F_%T` [INFO]  $1"
}

error() {
    verbose "`date +%F_%T` [ERROR]  $1"
    dolog "`date +%F_%T` [ERROR]  $1"
    exit 1;
}

calc_size_available() {
    echo `/bin/df -PT $DIR_BACKUP_BASE | /usr/bin/column -t | /usr/bin/tail -1 | $AWK {'print $5'}`
}

calc_size_directory() {
    echo `/usr/bin/du --max-depth=0 $1 | /usr/bin/column -t | $AWK {'print $1'}`
}

prepare() {
    if [ ! -d $DIR_BACKUP_BASE ]; then
        error "${DIR_BACKUP_BASE} does not exist."
    fi
    
    if [ -z "`$MYSQL_ADMIN $MYSQL_CONNECT status | grep 'Uptime'`" ] ; then
 	      error "HALTED: MySQL does not appear to be running."
    fi

    if ! `echo 'exit' | $MYSQL_CLI $MYSQL_CONNECT` ; then
        error "HALTED: Supplied mysql username or password appears to be incorrect (not copied here for security, see script)."
    fi
}

do_backup() {
    # Find latest full backup
    LATEST_FULL=`find $DIR_BACKUP_FULL -mindepth 1 -maxdepth 1 -type d -printf "%P\n" | sort -nr | head -1`
    
    # Get latest backup last modification time
    LATEST_FULL_CREATED_AT=`stat -c %Y $DIR_BACKUP_FULL/$LATEST_FULL`

#    if [ "${back_date}" == "full_back" ] ; then
#        FORCE_FULL_BACKUP=1
#    fi

    if [ "${back_data}" == "full_back" ] ; then
            #Running new full backup
            inform "do full backup!"
            $BACKUP_TOOL  $MYSQL_CONNECT $DIR_BACKUP_FULL > $TMPFILE 2>&1
    else
        # Run an incremental backup if latest full is still valid. Otherwise, run a new full one.
        if [ "$LATEST_FULL" -a `expr $LATEST_FULL_CREATED_AT + $FULL_BACKUP_GAP + 5` -ge $TIME_START ] ; then
            inform "do incremental backup!"
            # Create incremental backups dir if not exists.
            TMPINCRDIR=$DIR_BACKUP_INCR/$LATEST_FULL
            mkdir -p $TMPINCRDIR

            # Find latest incremental backup.
            LATEST_INCR=`find $TMPINCRDIR -mindepth 1 -maxdepth 1 -type d | sort -nr | head -1`
            

            # If this is the first incremental, use the full as base. Otherwise, use the latest incremental as base.
            if [ ! $LATEST_INCR ] ; then
              INCRBASEDIR=$DIR_BACKUP_FULL/$LATEST_FULL
            else
              INCRBASEDIR=$LATEST_INCR
            fi

            #Running new incremental backup using $INCRBASEDIR as base
            $BACKUP_TOOL  $MYSQL_CONNECT --incremental $TMPINCRDIR --incremental-basedir $INCRBASEDIR > $TMPFILE 2>&1
        else
            #Running new full backup
            inform "do full backup!"
            $BACKUP_TOOL  $MYSQL_CONNECT $DIR_BACKUP_FULL > $TMPFILE 2>&1
        fi
    fi
    
    if [ -z "`tail -1 $TMPFILE | grep 'completed OK!'`" ] ; then
        error "Backup failed, pls check $TMPFILE"
    fi
}
do_clean(){
  find $DIR_BACKUP_FULL -mindepth 1 -maxdepth 1 -type d -mtime +$KEEP | xargs rm -rf
  find $DIR_BACKUP_INCR -mindepth 1 -maxdepth 1 -type d -mtime +$KEEP | xargs rm -rf
}
do_rotate(){
    if [ `find $DIR_BACKUP_FULL -mindepth 1 -maxdepth 1 -type d  -printf "%P\n" | wc -l` -gt 1 ] ; then
        OLDEST_FULL=`find $DIR_BACKUP_FULL -mindepth 1 -maxdepth 1 -type d  -printf "%P\n" | sort -n | head -1`
        `rm -rf $DIR_BACKUP_FULL/$OLDEST_FULL`
        `rm -rf $DIR_BACKUP_INCR/$OLDEST_FULL`
    fi
}
KEEP=90
inform "Start to backup database!"
inform "DIR: Base is ${DIR_BACKUP_BASE}, FULL is ${DIR_BACKUP_FULL}, INCR is ${DIR_BACKUP_INCR}"
inform "Log: ${EXECUTE_LOG}"
inform "Output: ${TMPFILE}"
prepare
mkdir -p $DIR_BACKUP_FULL
mkdir -p $DIR_BACKUP_INCR
do_backup
if [ "${back_data}" == "full_back" ] ; then
tar zcf $DIR_BACKUP_FULL/`date +"%Y-%m-%d"`.tar.gz $DIR_BACKUP_FULL/`date +"%Y-%m-%d"`*
s3cmd put --multipart-chunk-size-mb=250 ${DIR_BACKUP_FULL}/`date +"%Y-%m-%d"`.tar.gz s3://sinpay-s3-bucket/yida/full/
#s3cmd sync ${DIR_BACKUP_BASE}/ s3://sinpay-s3-bucket/yida/
do_rotate
fi
inform "Backup completed!"


