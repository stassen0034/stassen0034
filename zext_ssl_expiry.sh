#! /bin/sh
DOMAIN=$1
TIMEOUT=25
RETVAL=0
SNI=$3
TIMESTAMP=`echo | date`
#EXPIRE_DATE=`openssl s_client -host $DOMAIN -port 443 -showcerts </dev/null 2>/dev/null | openssl x509 -noout -dates 2>/dev/null | grep notAfter | cut -d'=' -f2`
#TEST
#openssl s_client -connect s.dyfqp83.com:443 -servername s.dyfqp83.com -showcerts</dev/null 2>/dev/null | openssl x509 -noout -dates 2>/dev/null
if [[ $DOMAIN == *s.0soikfj.com* ]];
then
DOMAIN="s.0soikfj.com:22000"
EXPIRE_DATE=`openssl s_client -connect $DOMAIN -servername $DOMAIN -showcerts </dev/null 2>/dev/null | openssl x509 -noout -dates 2>/dev/null | grep notAfter | cut -d'=' -f2`
else
EXPIRE_DATE=`openssl s_client -connect $DOMAIN:443 -servername $DOMAIN -showcerts </dev/null 2>/dev/null | openssl x509 -noout -dates 2>/dev/null | grep notAfter | cut -d'=' -f2`
fi
EXPIRE_SECS=`date -d "${EXPIRE_DATE}" +%s`
EXPIRE_TIME=$(( ${EXPIRE_SECS} - `date +%s` ))
if test $EXPIRE_TIME -lt 0
then
EXP_DATE=0
else
EXP_DATE=$(( ${EXPIRE_TIME} / 24 / 3600 ))
fi

echo ${EXP_DATE}
