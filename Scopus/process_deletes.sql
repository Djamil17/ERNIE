\set ON_ERROR_STOP on
\set ECHO all

-- DataGrip: start execution from here
SET TIMEZONE = 'US/Eastern';

-- Create temp table holding scps
CREATE TEMP TABLE del_scps_stg(
  scp BIGINT NOT NULL
);

--edit the delete file with sed, then perform a client side copy into the temp table
\! sed "s/DELETE-2-s2.0-//g" delete.txt > edited_delete.txt
\copy del_scps_stg FROM 'edited_delete.txt'
\! rm edited_delete.txt

DELETE FROM scopus_publications
WHERE scp IN (SELECT scp
              FROM del_scps_stg);
