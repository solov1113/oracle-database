#!/bin/bash -e
OSB_CHOICE=${1} #OSB_CHOICE
HOST_TYPE=${2} #HOST_TYPE
PRIMARY_NAME=${3} #PRIMARY_NAME
INSTALLER_S3_BUCKET=${4} #INSTALLER_S3_BUCKET
OSB_AWS_BUCKET=${5} #OSB_AWS_BUCKET
OSB_AWS_KEY=${6} #OSB_AWS_KEY
OSB_AWS_SECRET=${7} #OSB_AWS_SECRET
OSB_OTN_USER=${8} #OSB_OTN_USER
OSB_OTN_PASS=${9} #OSB_OTN_PASS

if [[ ${OSB_CHOICE} == 'true' ]]; then
    export ORACLE_HOME=/u01/app/oracle/product/12c/db_1
    export PATH=/u01/app/oracle/product/12c/db_1/bin:${PATH}
    export ORACLE_SID=${PRIMARY_NAME}
    aws s3 cp s3://${INSTALLER_S3_BUCKET}/osbws_installer.zip /u01/install/osbws_installer.zip
    cd /u01/install/
    unzip osbws_installer.zip
    java -jar ./osbws_install.jar -AWSID ${OSB_AWS_KEY} -AWSKey ${OSB_AWS_SECRET} -otnUser ${OSB_OTN_USER} -otnPass ${OSB_OTN_PASS} -walletDir ${ORACLE_HOME}/dbs/osbws_wallet  -libDir ${ORACLE_HOME}/lib/
    echo OSB_WS_BUCKET=${OSB_AWS_BUCKET}  >>/u01/app/oracle/product/12c/db_1/dbs/osbws${PRIMARY_NAME}.ora
    if [[ ${HOST_TYPE} == 'PRIMARY' ]]; then
        rman cmdfile=/tmp/rmanbackup.cmd log=/tmp/rmanbackup.log
    fi
elif [[ ${OSB_CHOICE} == 'false' ]]; then
    echo 'OSB not configured' | tee /tmp/rmanbackup.log
fi
