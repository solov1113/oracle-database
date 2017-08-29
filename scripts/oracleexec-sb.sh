 #!/bin/bash -e
DATABASE_PASS=${1} #DATABASE_PASS
ASM_PASS=${2} #ASM_PASS
DATABASE_PORT=${3} #DATABASE_PORT
PRIMARY_NAME=${4} #PRIMARY_NAME
STANDBY_NAME=${5} #STANDBY_NAME
ORACLE_VERSION=${6} #ORACLE_VERSION
source ~/.bash_profile
#Installs Oracle Grid infrastructure using grid-setup.rsp parameter file, to /u01/app/oracle/product/12c/grid home
if [[ ${ORACLE_VERSION} == '12.1.0.2' ]]; then
  /u01/install/grid/runInstaller -silent -ignorePrereq -responsefile /u01/install/grid-setup.rsp &>> /tmp/oracleexec.log
  # Wait until the installer asks for root.sh running scripts as this is asynchronous from shell execution
  timeout 1800 grep -q '1. /u01/app/oraInventory/orainstRoot.sh' <(tail -f /tmp/oracleexec.log)
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
   touch /tmp/dbrunInstaller.log
   /u01/install/database/runInstaller -silent -ignorePrereq -responsefile /u01/install/db-config-sb.rsp &>> /tmp/dbrunInstaller.log
   # Wait until the installer asks for root.sh running scripts as this is asynchronous from shell execution
   while ! grep '/u01/app/oracle/product/12c/db_1/root.sh' /tmp/dbrunInstaller.log  ; do      sleep 5s;   done
fi
if [[ ${ORACLE_VERSION} == '12.2.0.1' ]]; then
  /u01/install/database/runInstaller -silent -ignorePrereq -responsefile /u01/install/db-config-sb122.rsp &>> /tmp/dbrunInstaller.log
  # Wait until the installer asks for root.sh running scripts as this is asynchronous from shell execution
  while ! grep '/u01/app/oracle/product/12c/db_1/root.sh' /tmp/dbrunInstaller.log  ; do      sleep 5s;   done
fi
# Do not run root.sh to do not update oratab with primary wrong values
# Create configToolAllCommands file as it failed to create #bug then change permissions for Oracle execution
echo /u01/app/oracle/product/12c/db_1/oui/bin/runConfig.sh ORACLE_HOME=/u01/app/oracle/product/12c/db_1 MODE=perform ACTION=configure RERUN=true $* >/u01/app/oracle/product/12c/db_1/cfgtoollogs/configToolAllCommands
chmod 755 /u01/app/oracle/product/12c/db_1/cfgtoollogs/configToolAllCommands
# Runs standby instance configuration with db-post.rsp parameter file
/u01/app/oracle/product/12c/db_1/cfgtoollogs/configToolAllCommands RESPONSE_FILE=/u01/install/db-post.rsp
# Export PRIMARY instance and Oracle database environment variables
export ORACLE_SID=${PRIMARY_NAME}
export ORACLE_HOME=/u01/app/oracle/product/12c/db_1
export PATH=/u01/app/oracle/product/12c/db_1/bin:${PATH}
# Copy the primary tnsnames.ora file to the $ORACLE_HOME/network/admin/ for Oracle database
cp /u01/install/config/tnsnames.ora /u01/app/oracle/product/12c/db_1/network/admin/tnsnames.ora
# Copy the primary password file to the $ORACLE_HOME/network/admin/ for Oracle database
cp /u01/install/config/orapw* /u01/app/oracle/product/12c/db_1/dbs/.
# Copy the listener file appended listener description to the $ORACLE_HOME/network/admin/ for Oracle database
cat /tmp/listener_stdb.ora >>/u01/app/oracle/product/12c/grid/network/admin/listener.ora
# Setup ASM variables
export ORACLE_SID=+ASM
export ORACLE_HOME=/u01/app/oracle/product/12c/grid
export PATH=/u01/app/oracle/product/12c/grid/bin:${PATH}
# Stop the listener running without appened description
lsnrctl stop
# Start the listener to run with appened description
lsnrctl start
# Setup ORacle Datatase variables with PRimary instance name
export ORACLE_SID=${PRIMARY_NAME}
export ORACLE_HOME=/u01/app/oracle/product/12c/db_1
export PATH=/u01/app/oracle/product/12c/db_1/bin:${PATH}
# Get controlfile parameter from the primary file exchanged
cat /u01/install/config/stby.ora | grep -v log_archive_dest_1 | grep -v log_archive_dest_2 | grep -v control_file >/u01/install/config/initstby.ora
# Pick up the AUD path from the initstby file
AUD=`grep audit /u01/install/config/initstby.ora | grep u01 | awk -F''\' '{print $2}'`
# Create the complete path for audit files
mkdir -p ${AUD}
# Connect to the instance and startup nomount it
sqlplus / as sysdba @/tmp/start.sql
# Use RMAN restore the controlfile from Primary exchanged file
rman cmdfile=/tmp/rman.cmd log=/tmp/rman.log
# Connect to sqlplus and stop the instance with primary definition
sqlplus / as sysdba @/tmp/stop.sql
# Export ASM variables
export ORACLE_SID=+ASM
export ORACLE_HOME=/u01/app/oracle/product/12c/grid
export PATH=/u01/app/oracle/product/12c/grid/bin:${PATH}
# Start ASMCMD  to discover the controlfile name for the new standby instance
CTL=`echo -e 'find --type controlfile . *\n' | asmcmd  | grep current | awk '{print $2}'`
# Update the init file with the correct controlfile location
echo '*.control_files='\'${CTL}\' >>/u01/install/config/initstby.ora
# Update standby management, fal server and name to  in init file
echo '*.standby_file_management='\'AUTO\'  >>/u01/install/config/initstby.ora
echo '*.fal_server='\'${PRIMARY_NAME}\' >>/u01/install/config/initstby.ora
echo '*.db_unique_name='\'${STANDBY_NAME}\'>>/u01/install/config/initstby.ora
# Export Orracl Database variables
export ORACLE_HOME=/u01/app/oracle/product/12c/db_1
export PATH=/u01/app/oracle/product/12c/db_1/bin:${PATH}
export ORACLE_SID=${STANDBY_NAME}
# Copy the primary password file to the standby init file
cp /u01/app/oracle/product/12c/db_1/dbs/orapw${PRIMARY_NAME} /u01/app/oracle/product/12c/db_1/dbs/orapw${STANDBY_NAME}
#update /etc/oratab with new create instance
echo "${STANDBY_NAME}:/u01/app/oracle/product/12c/db_1:N" >>/etc/oratab
# Run SQLPLUS start standby instance with its new updated init file
sqlplus / as sysdba @/tmp/start2.sql
# Run RMAN to execute DUPLICATE command - copies the Primary data files to standby database
rman cmdfile=/tmp/rman2.cmd log=/tmp/rman2.log
# Use SQLPLUS to set up correct archive parameter to configure standby instances
# Put database in recovery mode
sqlplus / as sysdba @/tmp/post-duplicate.sql
# Use SQLPLUS update parameters to configure the Data Guard Broker in Primary and Standby Instances
sqlplus /nolog @/tmp/dbbroker.sql
# As the last command runs asynchronous, wait for its completion to run DGMGRL
sleep 3m
# Setup Oracle Database variables to run DGMGRL
export ORACLE_HOME=/u01/app/oracle/product/12c/db_1
export PATH=/u01/app/oracle/product/12c/db_1/bin:${PATH}
export ORACLE_SID=${STANDBY_NAME}
# Run DGMGRL to perform Data Guard Broker configuration
echo -e "connect sys/${DATABASE_PASS}@${PRIMARY_NAME}\ncreate configuration awsguard as primary database is ${PRIMARY_NAME} connect identifier is ${PRIMARY_NAME};\nexit\n" | dgmgrl
echo -e "connect sys/${DATABASE_PASS}@${PRIMARY_NAME}\nadd database ${STANDBY_NAME} as connect identifier is ${STANDBY_NAME} maintained as physical;\nexit\n" | dgmgrl
echo -e "connect sys/${DATABASE_PASS}@${PRIMARY_NAME}\nshow configuration;\nexit\n" | dgmgrl >/tmp/dgmgrl.conf
echo -e "connect sys/${DATABASE_PASS}@${PRIMARY_NAME}\nenable configuration;\nexit\n" | dgmgrl
# Connect to SQLPLUS on primary instance to generate archivelogs
sqlplus /nolog @/tmp/dbcheck.sql
# dbsetup-sb.sql - use SQLPLUS to check if the archivelogs are being applied to Standby Instance
sqlplus /nolog @/tmp/dbsetup-sb.sql
