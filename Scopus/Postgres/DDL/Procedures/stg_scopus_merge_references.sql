\set ON_ERROR_STOP on
\set ECHO all

-- DataGrip: start execution from here
SET TIMEZONE = 'US/Eastern';

-- TODO JOIN to scopus_publications looks unnecessary
CREATE OR REPLACE PROCEDURE stg_scopus_merge_references()
  LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO scopus_references(scp, ref_sgr, citation_text)
  SELECT DISTINCT stg_scopus_references.scp, ref_sgr, max(citation_text) AS citation_text
    FROM stg_scopus_references, scopus_publications
   WHERE stg_scopus_references.scp = scopus_publications.scp
   GROUP BY stg_scopus_references.scp, ref_sgr
      ON CONFLICT (scp, ref_sgr) DO UPDATE SET citation_text=excluded.citation_text;
END; $$