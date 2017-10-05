-- Author     : Samet Keserci, (prev version - Lindsay Wan)
-- Aim        : Delete the del.file records from wos tables in parallel. Previous version was in serial and written by Lindsay.
-- Create date: 08/28/2017


-- Set temporary tablespace for calculation.
set log_temp_files = 0;
set enable_seqscan='off';
--set temp_tablespaces = 'temp_tbs';
SET temp_tablespaces='temp'; -- temporaryly it is being set.
--set enable_hashjoin = 'off';
--set enable_mergejoin = 'off';
set search_path = public;

\echo ***DELETING FROM TABLE: wos_document_identifiers
insert into del_wos_document_identifiers
  select a.* from wos_document_identifiers a inner join temp_delete_wosid b
  on a.source_id=b.source_id;
delete from wos_document_identifiers a
  where exists
  (select 1 from temp_delete_wosid_3 b
    where a.source_id=b.source_id);
