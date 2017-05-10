#!/bin/bash -e
ASM_PASS=${1} #ASM_PASS
DATABASE_PORT=${2} #DATABASE_PORT
PRIMARY_NAME=${3} #PRIMARY_NAME
ORACLE_VERSION=${4} #ORACLE_VERSION

# Installs Oracle Grid infrastructure using grid-setup.rsp parameter file, to /u01/app/oracle/product/12c/grid home
if [[ ${ORACLE_VERSION} == '12.1.0.2' ]]; then
 /u01/install/grid/runInstaller -silent -ignorePrereq -responsefile /u01/install/grid-setup.rsp &>> /tmp/oracleexec.log
 # Wait until the installer asks for root.sh running scripts as this is asynchronous from shell execution
 timeout 900 grep -q '1. /u01/app/oraInventory/orainstRoot.sh' <(tail -f /tmp/oracleexec.log)
 echo QS_runInstaller_end &>> /tmp/oracleexec.log
fi
if [[ ${ORACLE_VERSION} == '12.2.0.1' ]]; then
 /u01/app/oracle/product/12c/grid/gridSetup.sh -silent -ignorePrereq -responsefile /u01/install/grid-setup122.rsp &>> /tmp/oracleexec.log
 echo QS_gridsetup_end &>> /tmp/oracleexec.log
fi
# Then run the orainsRoot.sh oracle shell to update inventory # part of Oracle Grid installation process
sudo /u01/app/oraInventory/orainstRoot.sh &>> /tmp/oracleexec.log
echo QS_orainstRootsh &>> /tmp/oracleexec.log
# Run root.sh to correct permissions for Oracle # part of Oracle Grid Installation process
sudo /u01/app/oracle/product/12c/grid/root.sh &>> /tmp/oracleexec.log
echo QS_rootsh &>> /tmp/oracleexec.log
# Run configTollAllCommands  -  it setups the ASM instance  with asm-config.rsp parameter file
if [[ ${ORACLE_VERSION} == '12.1.0.2' ]]; then
 /u01/app/oracle/product/12c/grid/cfgtoollogs/configToolAllCommands RESPONSE_FILE=/u01/install/asm-config.rsp
fi
if [[ ${ORACLE_VERSION} == '12.2.0.1' ]]; then
 /u01/app/oracle/product/12c/grid/gridSetup.sh -executeConfigTools -responseFile /u01/install/grid-setup122.rsp -silent &>> /tmp/oracleexec.log
 echo QS_gridSetupConfigTools &>> /tmp/oracleexec.log
fi
# Run asmcmd to create the diskgroups for ASM
echo QS_beginRECOsetup &>> /tmp/oracleexec.log
if [[ ${ORACLE_VERSION} == '12.1.0.2' ]]; then
   /u01/app/oracle/product/12c/grid/bin/asmca -silent -createDiskGroup -sysAsmPassword ${ASM_PASS} -asmsnmpPassword ${ASM_PASS} -diskGroupName RECO -diskList ORCL:RECO1,ORCL:RECO2,ORCL:RECO3 -redundancy EXTERNAL &>> /tmp/oracleexec.log
fi
if [[ ${ORACLE_VERSION} == '12.2.0.1' ]]; then
  /u01/app/oracle/product/12c/grid/bin/asmca -silent -createDiskGroup -sysAsmPassword ${ASM_PASS} -asmsnmpPassword ${ASM_PASS} -diskGroupName RECO -diskList /dev/oracleasm/disks/RECO1,/dev/oracleasm/disks/RECO2,/dev/oracleasm/disks/RECO3 -redundancy EXTERNAL &>> /tmp/oracleexec.log
fi
echo QS_RECOdiskgroup &>> /tmp/oracleexec.log
# Setup oracle ASM variables to execute a commmand
export ORACLE_SID=+ASM
export ORACLE_HOME=/u01/app/oracle/product/12c/grid
export PATH=/u01/app/oracle/product/12c/grid/bin:${PATH}
# Stop the LISTENER using Grid Oracle home
lsnrctl stop
# Change the default listener port to the chosen one
echo "QS_DATABASE_PORT: ${DATABASE_PORT}"
sed -i "s/1521/${DATABASE_PORT}/g" /u01/app/oracle/product/12c/grid/network/admin/listener.ora
# Start the LISTENER using Grid Oracle home
lsnrctl start
if lsnrctl status | grep $DATABASE_PORT | awk -F'(' '{print $6}' | sed -e 's/)//g' | grep PORT; then
    echo "QS_LISTENER_CONFIG_TO_"$DATABASE_PORT"|SUCCESS"
else
    echo "QS_LISTENER_CONFIG_PORT|FAILURE"
    exit 1
fi
# Install Oracle Database Software using the db-config.rsp parameter file
if [[ ${ORACLE_VERSION} == '12.1.0.2' ]]; then
   /u01/install/database/runInstaller -silent -ignorePrereq -responsefile /u01/install/db-config.rsp &>> /tmp/oracleexec.log
   # Wait until the installer asks for root.sh running scripts as this is asynchronous from shell execution
   timeout 900 grep -q '1. /u01/app/oracle/product/12c/db_1/root.sh' <(tail -f /tmp/oracleexec.log)
fi
if [[ ${ORACLE_VERSION} == '12.2.0.1' ]]; then
  /u01/install/database/runInstaller -silent -ignorePrereq -responsefile /u01/install/db-config122.rsp &>> /tmp/dbrunInstaller.log
  # Wait until the installer asks for root.sh running scripts as this is asynchronous from shell execution
  while ! grep '/u01/app/oracle/product/12c/db_1/root.sh' /tmp/dbrunInstaller.log  ; do      sleep 5s;   done
fi
# Execute the root.sh to configure and give correct oratab and permissions
sudo /u01/app/oracle/product/12c/db_1/root.sh &>> /tmp/oracleexec.log
# Run configToolAllCommands to configure Primary Database using db-post-rsp
if [[ ${ORACLE_VERSION} == '12.1.0.2' ]]; then
   /u01/app/oracle/product/12c/db_1/cfgtoollogs/configToolAllCommands RESPONSE_FILE=/u01/install/db-post.rsp
fi
if [[ ${ORACLE_VERSION} == '12.2.0.1' ]]; then
  /u01/install/database/runInstaller -executeConfigTools -responseFile /u01/install/db-config122.rsp -silent &>>/tmp/dbexecConf.log
  while ! grep 'Successfully Configured Software.' /tmp/dbexecConf.log  ; do      sleep 5s;   done
  # Check if database is UP before performing DB changes in config
  A=`ps -ef | grep smon | grep -v ASM | grep -v grep | wc -l`
  while [ $A -eq 0 ]; do sleep 10s; A=`ps -ef | grep smon | grep -v ASM | grep -v grep | wc -l`; done
  A=`ps -ef | grep pmon | grep -v ASM | grep -v grep | wc -l`
  while [ $A -eq 0 ]; do sleep 10s; A=`ps -ef | grep pmon | grep -v ASM | grep -v grep | wc -l`; done
  A=`ps -ef | grep dbw | grep -v ASM | grep -v grep | wc -l`
  while [ $A -eq 0 ]; do sleep 10s; A=`ps -ef | grep dbw | grep -v ASM | grep -v grep | wc -l`; done
fi
# Setup oracle Database variables
export ORACLE_SID=${PRIMARY_NAME}
export ORACLE_HOME=/u01/app/oracle/product/12c/db_1
export PATH=/u01/app/oracle/product/12c/db_1/bin:${PATH}
# Run SQLPLUS to update parameter files, setup ARCHIVELOG mode and LOGFILES
sqlplus /nolog @/tmp/dbsetup.sql
# Perform a backup from tnsnames.ora
cp /u01/app/oracle/product/12c/db_1/network/admin/tnsnames.ora /tmp/tnsnames.bkp
# Replaces tnsnames.ora with the correct IPs  and Instances
cp /tmp/tns_stdb.ora /u01/app/oracle/product/12c/db_1/network/admin/tnsnames.ora
# Append descriptions to PRIMARY LISTENER
cat /tmp/listener_prim.ora >>/u01/app/oracle/product/12c/grid/network/admin/listener.ora
# Setup ASM Variables
export ORACLE_SID=+ASM
export ORACLE_HOME=/u01/app/oracle/product/12c/grid
export PATH=/u01/app/oracle/product/12c/grid/bin:${PATH}
# Stop the LISTENER
lsnrctl stop
# Start the LISTENER
lsnrctl start
export ORACLE_SID=${PRIMARY_NAME}
export ORACLE_HOME=/u01/app/oracle/product/12c/db_1
export PATH=/u01/app/oracle/product/12c/db_1/bin:${PATH}
