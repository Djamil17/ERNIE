\set ON_ERROR_STOP on
\set ECHO all

-- DataGrip: start execution from here
SET TIMEZONE = 'US/Eastern';

-- Create table holding scps then drop at the end
CREATE TABLE public.del_scps_stg(
  scp BIGINT NOT NULL
  del_time current_timestamp
);

--edit the delete file with sed, then perform a client side copy into the table
\! sed "s/DELETE-2-s2.0-//g" delete.txt > edited_delete.txt
\copy del_scps_stg FROM 'edited_delete.txt'
\! rm edited_delete.txt

select * from del_scps_stg limit 100; 

DELETE FROM scopus_publications
WHERE scp IN (SELECT scp
          FROM public.del_scps_stg);
