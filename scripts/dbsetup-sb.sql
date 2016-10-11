connect / as sysdba
set pages 1000 line 150
spool /tmp/dbsetup.log
ALTER SESSION SET nls_date_format='DD-MON-YYYY HH24:MI:SS';
SELECT sequence#, first_time, next_time, applied
FROM   v$archived_log
ORDER BY sequence#;
set echo off
set head off
spool /tmp/status.log
select 'QS_PHYSICAL_STANDBY|SUCCESS' status from v$database where database_role='PHYSICAL STANDBY';
spool off
exit
