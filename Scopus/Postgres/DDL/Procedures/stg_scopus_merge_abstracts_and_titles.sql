\set ON_ERROR_STOP on
\set ECHO all

-- DataGrip: start execution from here
SET TIMEZONE = 'US/Eastern';


create procedure stg_scopus_merge_abstracts_and_titles()
    language plpgsql
as
$$
BEGIN
    INSERT INTO scopus_abstracts(scp, abstract_language, abstract_source)
    SELECT DISTINCT stg.scp,
           stg.abstract_language,
           stg.abstract_source
    FROM stg_scopus_abstracts stg
    ON CONFLICT (scp,abstract_language) DO UPDATE SET abstract_source=excluded.abstract_source;
-----------------------------------------
    INSERT INTO scopus_titles(scp, title, language)
    SELECT stg.scp,
           max(title) as title,
           max(language) as language
    FROM stg_scopus_titles stg
    GROUP BY scp
    ON CONFLICT (scp, language) DO UPDATE SET title=excluded.title;
END
$$;