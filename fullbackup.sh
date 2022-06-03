#!/bin/sh

proc_num=`cat /proc/cpuinfo |grep processor|wc -l`
thread_num=`expr $(($proc_num/2))`

platform="HQQ_CP_PRE"
schema=$1

uid=root
pwd='YJ5:01u3teELz:7=bbR1'
socket=/data/$1/run/mysql.sock

tmpdir=/tmp
bakdir=/data/backup/$1

extradir=$bakdir/ckptdir
if [ ! -d $extradir ]; then
  mkdir -p $extradir
fi

logdir=$bakdir/log
if [ ! -d $logdir ]; then
  mkdir -p $logdir
fi
lastweek_dir=$bakdir/files
if [ ! -d $lastweek_dir ]; then
  mkdir -p $lastweek_dir
fi

if [ "${1}" == "hgameS" ];
then
  defaults_file=/etc/my-3306.cnf
else
  defaults_file=/etc/my-3307.cnf
fi

parallel_dgr=$thread_num
backdate=`date "+%Y%m%d"`
ydate=`date +%Y%m%d  -d '30 days ago'`
Yesterday=`date -d '-1 day' +%Y%m%d`

logs="$logdir"/backup_"$platform"_full_"$schema"_"$backdate".log

echo "1"
cd $lastweek_dir
if [ ! -d $backdate ]; then
  mkdir -p $backdate/$backdate-000fullbackup
fi

sleep 1

/bin/find $lastweek_dir -name ${ydate}_full.tar.gz -exec rm -rf {} \; 

xtrabackup --backup --binlog-info=AUTO --socket=$socket --user=$uid --password=$pwd  --tmpdir=$tmpdir --slave-info --extra-lsndir=$extradir --no-timestamp --parallel=$parallel_dgr --target-dir=$backdate/$backdate-000fullbackup 2>$logs 


if [ "${1}" == "hgameS" ];
then
  /bin/cp -arf /etc/my-3306.cnf $backdate/$backdate-000fullbackup
else
  /bin/cp -arf /etc/my-3307.cnf $backdate/$backdate-000fullbackup
fi

#tar zcvf ${Yesterday}_full.tar.gz ${Yesterday}/${Yesterday}-000fullbackup --remove-files

#/bin/rm -rf ${Yesterday} 

#s3cmd upload
#s3cmd put --multipart-chunk-size-mb=250 ${Yesterday}_full.tar.gz s3://hqq-project-s3-bucket/OL/Mysql/


#s3 SyncAllinone
#s3cmd sync  --multipart-chunk-size-mb=100 --recursive /opt/SyncAllinone --exclude="*.gz" --exclude="*.log" s3://hqt-project-bucket/


#bash /data/shell/S3BucketCheck.sh
