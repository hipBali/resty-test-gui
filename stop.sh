#!/bin/sh

#####################################################################
# usage:
# sh stop.sh -- stop application with default config
# sh stop.sh ${env} -- stop application @${env}

# examples:
# sh stop.sh prod -- use conf/nginx-prod.conf to stop OpenResty
# sh stop.sh -- use conf/nginx-local.conf to stop OpenResty
#####################################################################

if [ -n "$1" ];then
    PROFILE="$1"
else
    PROFILE=local
fi

mkdir -p logs & mkdir -p tmp
echo "stop RESTY application with profile: "${PROFILE}
nginx -s stop -p `pwd`/ -c conf/nginx-${PROFILE}.conf
