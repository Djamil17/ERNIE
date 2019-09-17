set search_path = ':';
\set ON_ERROR_STOP on
\set ECHO all

-- DataGrip: start execution from here
SET TIMEZONE = 'US/Eastern';

CREATE OR REPLACE PROCEDURE stg_scopus_parse_grants(scopus_doc_xml XML)
language plpgsql
AS
$$
BEGIN
    -- scopus_grants
INSERT
INTO stg_scopus_grants(scp, grant_id, grantor_acronym, grantor,
                   grantor_country_code, grantor_funder_registry_id)
SELECT
        scp,
       coalesce(grant_id, '') AS grant_id,
       max(grantor_acronym) as grantor_acronym,
       grantor,
       max(grantor_country_code) as grantor_country_code,
       max(grantor_funder_registry_id) as grantor_funder_registry_id
FROM xmltable(--
             '//bibrecord/head/grantlist/grant' PASSING scopus_doc_xml COLUMNS --
            scp BIGINT PATH '../../preceding-sibling::item-info/itemidlist/itemid[@idtype="SCP"]',
            grant_id TEXT PATH 'grant-id',
            grantor_acronym TEXT PATH 'grant-acronym',
            grantor TEXT PATH 'grant-agency',
            grantor_country_code TEXT PATH 'grant-agency/@iso-code',
            grantor_funder_registry_id TEXT PATH 'grant-agency-id'
         )
GROUP BY scp, grant_id, grantor;

    -- scopus_grant_acknowledgements
INSERT INTO scopus_grant_acknowledgements(scp, grant_text)

SELECT scp,
       grant_text
FROM xmltable(--
             '//bibrecord/head/grantlist/grant-text' PASSING scopus_doc_xml COLUMNS --
            scp BIGINT PATH '../../preceding-sibling::item-info/itemidlist/itemid[@idtype="SCP"]',
            grant_text TEXT PATH '.'
         );
END;
$$;
