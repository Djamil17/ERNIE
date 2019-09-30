\set ON_ERROR_STOP on
\set ECHO all

-- DataGrip: start execution from here
SET TIMEZONE = 'US/Eastern';

CREATE OR REPLACE PROCEDURE stg_scopus_merge_abstracts_and_titles()
  LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO scopus_abstracts(scp, abstract_language, abstract_text, abstract_source)
  SELECT scp, abstract_language, abstract_text, abstract_source
    FROM stg_scopus_abstracts ssa
      ON CONFLICT (scp, abstract_language) DO UPDATE SET abstract_text=excluded.abstract_text,
        abstract_source=excluded.abstract_source;

  INSERT INTO scopus_titles(scp, title, language)
  SELECT scp, max(title) AS title, max(language) AS language
    FROM stg_scopus_titles stg
   GROUP BY scp
      ON CONFLICT (scp, language) DO UPDATE SET title=excluded.title;
END $$;