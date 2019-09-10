INSERT INTO scopus_sources
  (source_id, issn_main, isbn_main)
VALUES
  (21100256101, 23029293, '')
    ON CONFLICT(source_id, issn_main, isbn_main) DO UPDATE SET source_id=excluded.source_id,
      issn_main=excluded.issn_main,
      isbn_main=excluded.isbn_main;

SELECT *
  FROM scopus_source_publication_details
 WHERE publication_year = 1880;
-- 2m:36s

SELECT *
  FROM
    scopus_publications sp
      JOIN scopus_publication_groups spg ON sp.sgr = spg.sgr
 WHERE scp IN (84960675891,
               84960681706,
               84960640034,
               84960645391,
               84960653710,
               84960656392,
               84960646195,
               84960678793,
               84960656746);
