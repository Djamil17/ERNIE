/*
Author: Djamil Lakhdar-Hamina
Date: July 22, 2019

Runs and creates a update-log. Before update takes tally, after tally, compares difference.
*/

\set ON_ERROR_STOP on
\set ECHO all

-- DataGrip: start execution from here
SET TIMEZONE = 'US/Eastern';

UPDATE update_log_scopus
SET
  last_updated = current_timestamp, --
  num_scopus =
    (SELECT count(1)
     FROM scopus_publications),
  num_update =
    (SELECT count(1)
     FROM uhs_wos_publications a
     WHERE uhs_updated_time >
             (SELECT process_start_time
              FROM update_log_wos
              ORDER BY id DESC
              LIMIT 1)),
  num_delete =
    (SELECT count(1)
     FROM del_wos_publications b
     WHERE deleted_time >
             (SELECT process_start_time
              FROM update_log_wos
              ORDER BY id DESC
              LIMIT 1)),
  num_new =
    (SELECT count(1)
     FROM wos_publications c
     WHERE last_updated_time >
             (SELECT process_start_time
              FROM update_log_wos
              ORDER BY id DESC
              LIMIT 1) AND source_id NOT IN
             (SELECT DISTINCT source_id
              FROM uhs_wos_publications
              WHERE uhs_updated_time >
                      (SELECT process_start_time
                       FROM update_log_wos
                       ORDER BY id DESC
                       LIMIT 1)))
WHERE id =
        (SELECT max(id)
         FROM update_log_wos);

SELECT *
FROM update_log_wos
ORDER BY id DESC
FETCH FIRST 10 ROWS ONLY;


DROP TABLE IF EXISTS update_log_scopus;
CREATE TABLE public.update_log_scopus (
  id  SERIAL,
  last_updated TIMESTAMP,
  num_scopus INTEGER,
  new_num INTEGER,
  num_update INTEGER,
  num_delete INTEGER,
  source_filename VARCHAR(200),
  record_count BIGINT,
  source_file_size BIGINT,
  process_start_time TIMESTAMP
  CONSTRAINT update_log_scopus_pk PRIMARY KEY (id) USING INDEX TABLESPACE index_tbs
) TABLESPACE scopus_tbs;

COMMENT ON TABLE update_log_scopus
IS 'Scopus tables - update log table for scopus';
