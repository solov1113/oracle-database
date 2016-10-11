connect sys/QS_DATABASE_PASS@QS_PRIMARY_NAME as sysdba
set pages 1000 line 150
spool /tmp/dbcheck.log
alter system switch LOGFILE;
alter system switch LOGFILE;
alter system switch LOGFILE;
ALTER SESSION SET nls_date_format='DD-MON-YYYY HH24:MI:SS';
SELECT sequence#, first_time, next_time, applied
FROM   v$archived_log
ORDER BY sequence#;
alter system switch LOGFILE;
alter system switch LOGFILE;
alter system switch LOGFILE;
ALTER SESSION SET nls_date_format='DD-MON-YYYY HH24:MI:SS';
SELECT sequence#, first_time, next_time, applied
FROM   v$archived_log
ORDER BY sequence#;
exit
