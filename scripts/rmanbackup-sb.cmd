connect target /
configure channel device type sbt parms='SBT_LIBRARY=/u01/app/oracle/product/12c/db_1/lib/libosbws.so,    SBT_PARMS=(OSB_WS_PFILE=/u01/app/oracle/product/12c/db_1/dbs/osbwsQS_STANDBY_NAME.ora)';
configure default device type to 'sbt_tape';
CONFIGURE DEVICE TYPE SBT_TAPE PARALLELISM 5 BACKUP TYPE TO BACKUPSET;
CONFIGURE CHANNEL DEVICE TYPE SBT MAXPIECESIZE 2G;
run {
allocate channel ch1 type sbt_tape  PARMS  'SBT_LIBRARY=/u01/app/oracle/product/12c/db_1/lib/libosbws.so,    SBT_PARMS=(OSB_WS_PFILE=/u01/app/oracle/product/12c/db_1/dbs/osbwsQS_STANDBY_NAME.ora)';
allocate channel ch2 type sbt_tape  PARMS  'SBT_LIBRARY=/u01/app/oracle/product/12c/db_1/lib/libosbws.so,    SBT_PARMS=(OSB_WS_PFILE=/u01/app/oracle/product/12c/db_1/dbs/osbwsQS_STANDBY_NAME.ora)';
allocate channel ch3 type sbt_tape  PARMS  'SBT_LIBRARY=/u01/app/oracle/product/12c/db_1/lib/libosbws.so,    SBT_PARMS=(OSB_WS_PFILE=/u01/app/oracle/product/12c/db_1/dbs/osbwsQS_STANDBY_NAME.ora)';
allocate channel ch4 type sbt_tape  PARMS  'SBT_LIBRARY=/u01/app/oracle/product/12c/db_1/lib/libosbws.so,    SBT_PARMS=(OSB_WS_PFILE=/u01/app/oracle/product/12c/db_1/dbs/osbwsQS_STANDBY_NAME.ora)';
backup as compressed backupset database;
sql 'alter system archive log current';
  backup as compressed backupset archivelog all not backed up;
  backup current controlfile;
  release channel ch1;
  release channel ch2;
  release channel ch3;
  release channel ch4;
}
