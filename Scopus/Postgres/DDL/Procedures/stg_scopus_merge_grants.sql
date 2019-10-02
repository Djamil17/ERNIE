\set ON_ERROR_STOP on
\set ECHO all

-- DataGrip: start execution from here
SET TIMEZONE = 'US/Eastern';

CREATE OR REPLACE PROCEDURE stg_scopus_merge_grants()
    LANGUAGE plpgsql AS
$$
BEGIN
    INSERT INTO scopus_grants(scp, grant_id, grantor_acronym, grantor,
                              grantor_country_code, grantor_funder_registry_id)
    SELECT scopus_publications.scp,
           grant_id,
           max(grantor_acronym)            AS grantor_acronym,
           grantor,
           max(grantor_country_code)       AS grantor_country_code,
           max(grantor_funder_registry_id) AS grantor_funder_registry_id
    FROM stg_scopus_grants,
         scopus_publications
    Where stg_scopus_grants.scp = scopus_publications.scp
    GROUP BY scopus_publications.scp, grant_id, grantor
    ON CONFLICT (scp, grant_id, grantor) DO UPDATE SET grantor_acronym=excluded.grantor_acronym,
                                                       grantor_country_code=excluded.grantor_country_code,
                                                       grantor_funder_registry_id=excluded.grantor_funder_registry_id;

    INSERT INTO scopus_grant_acknowledgments(scp, grant_text)
    SELECT DISTINCT scopus_publications.scp, grant_text
    FROM stg_scopus_grant_acknowledgments,
         scopus_publications
    WHERE stg_scopus_grant_acknowledgments.scp = scopus_publications.scp
    ON CONFLICT (scp) DO UPDATE SET grant_text=excluded.grant_text;
END
$$;
