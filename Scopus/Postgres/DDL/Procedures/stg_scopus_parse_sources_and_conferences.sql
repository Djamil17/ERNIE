\set ON_ERROR_STOP on
\set ECHO all

-- DataGrip: start execution from here
SET TIMEZONE = 'US/Eastern';

CREATE OR REPLACE PROCEDURE stg_scopus_parse_source_and_conferences(scopus_doc_xml XML)
  LANGUAGE plpgsql AS $block$
DECLARE --
  xml_source RECORD; --
  pub_ernie_source_id INT;
BEGIN
  SELECT
    coalesce(source_id, '') AS source_id, coalesce(issn, '') AS issn_main, coalesce(isbn, '') AS isbn_main,
    string_agg(source_type, ' ') AS source_type, string_agg(source_title, ' ') AS source_title,
    string_agg(coden_code, ' ') AS coden_code, string_agg(publisher_name, ' ') AS publisher_name,
    string_agg(publisher_e_address, ' ') AS publisher_e_address,
    max(try_parse(pub_year, pub_month, pub_day)) AS pub_date
    INTO xml_source
    FROM
      xmltable(--
          XMLNAMESPACES ('http://www.elsevier.com/xml/ani/common' AS ce), --
          '//bibrecord/head/source' PASSING scopus_doc_xml COLUMNS --
            source_id TEXT PATH '@srcid', --
            issn TEXT PATH 'issn[1]', --
            isbn TEXT PATH 'isbn[1]', --
            source_type TEXT PATH '@type', --
            source_title TEXT PATH 'sourcetitle', --
            coden_code TEXT PATH 'codencode', --
            publisher_name TEXT PATH 'publisher/publishername', --
            publisher_e_address TEXT PATH 'publisher/ce:e-address', --
            pub_year SMALLINT PATH 'publicationdate/year', --
            pub_month SMALLINT PATH 'publicationdate/month', --
            pub_day SMALLINT PATH 'publicationdate/day' --
        )
   WHERE source_id <> '' OR issn <> '' OR isbn <> ''
   GROUP BY source_id, issn_main, isbn_main;

  -- Returns NULL if not found
  SELECT ss.ernie_source_id
    INTO pub_ernie_source_id
    FROM scopus_sources ss
   WHERE ss.source_id = xml_source.source_id AND ss.issn_main = xml_source.issn_main
     AND ss.isbn_main = xml_source.isbn_main;

--   RAISE NOTICE 'Parsed source `%`. Source id #`%`', xml_source, pub_ernie_source_id;

  IF pub_ernie_source_id IS NULL THEN -- Generate a new source
  --@formatter:off
    INSERT INTO stg_scopus_sources(ernie_source_id, source_id, issn_main, isbn_main, source_type, source_title,
                                  coden_code, publisher_name, publisher_e_address, pub_date)
    SELECT
     nextval('scopus_sources_ernie_source_id_seq'), xml_source.source_id, xml_source.issn_main,
     xml_source.isbn_main, xml_source.source_type, xml_source.source_title, xml_source.coden_code,
     xml_source.publisher_name, xml_source.publisher_e_address, xml_source.pub_date
       ON CONFLICT (source_id, issn_main, isbn_main) DO UPDATE SET --
         source_type = excluded.source_type,
         source_title = excluded.source_title,
         coden_code = excluded.coden_code,
         publisher_name = excluded.publisher_name,
         publisher_e_address = excluded.publisher_e_address,
         pub_date = excluded.pub_date
    RETURNING ernie_source_id INTO pub_ernie_source_id;
    COMMIT;
--@formatter:on

    UPDATE stg_scopus_sources ss
       SET website=sq.website
      FROM
        (
          SELECT pub_ernie_source_id AS ernie_source_id, string_agg(website, ',') AS website
            FROM
              xmltable(--
                  XMLNAMESPACES ('http://www.elsevier.com/xml/ani/common' AS ce), --
                  '//bibrecord/head/source/website/ce:e-address' PASSING scopus_doc_xml COLUMNS --
                    website TEXT PATH 'normalize-space()')
           GROUP BY pub_ernie_source_id
        ) AS sq
     WHERE ss.ernie_source_id = sq.ernie_source_id;
    COMMIT;
  END IF;

  -- scopus_isbns
  INSERT INTO stg_scopus_isbns(ernie_source_id, isbn, isbn_length, isbn_type, isbn_level)
  SELECT DISTINCT
    pub_ernie_source_id AS ernie_source_id, isbn, isbn_length, coalesce(isbn_type, '') AS isbn_type, isbn_level
    FROM
      xmltable(--
          '//bibrecord/head/source/isbn' PASSING scopus_doc_xml COLUMNS --
        isbn TEXT PATH '.', isbn_length SMALLINT PATH '@length', isbn_type TEXT PATH '@type', isbn_level TEXT PATH '@level');
  COMMIT;
  -- scopus_issns
  INSERT INTO stg_scopus_issns(ernie_source_id, issn, issn_type)
  SELECT pub_ernie_source_id AS ernie_source_id, issn, coalesce(issn_type, '') AS issn_type
    FROM
      xmltable(--
          '//bibrecord/head/source/issn' PASSING scopus_doc_xml COLUMNS --
        issn TEXT PATH '.', issn_type TEXT PATH '@type');
  COMMIT;

  UPDATE stg_scopus_publications
     SET pub_type=subquery.pub_type,
       process_stage=subquery.process_stage,
       state=subquery.state,
       date_sort=subquery.date_sort,
       ernie_source_id=subquery.ernie_source_id
    FROM
      (
        SELECT
          pub_ernie_source_id AS ernie_source_id, scp, pub_type, process_stage, state,
          try_parse(sort_year, sort_month, sort_day) AS date_sort
          FROM
            xmltable(XMLNAMESPACES ('http://www.elsevier.com/xml/ani/ait' AS ait), '//item' PASSING scopus_doc_xml
                     COLUMNS scp BIGINT PATH '//bibrecord/item-info/itemidlist/itemid[@idtype="SCP"]', pub_type TEXT PATH 'ait:process-info/ait:status/@type', process_stage TEXT PATH 'ait:process-info/ait:status/@stage', state TEXT PATH 'ait:process-info/ait:status/@state', sort_year SMALLINT PATH 'ait:process-info/ait:date-sort/@year', sort_month SMALLINT PATH 'ait:process-info/ait:date-sort/@month', sort_day SMALLINT PATH 'ait:process-info/ait:date-sort/@day')
      ) AS subquery
   WHERE stg_scopus_publications.scp = subquery.scp;
  COMMIT;

  -- scopus_conference_events
  INSERT INTO stg_scopus_conference_events(conf_code, conf_name, conf_address, conf_city, conf_postal_code,
                                           conf_start_date,
                                           conf_end_date, conf_number, conf_catalog_number)
  SELECT DISTINCT
    coalesce(conf_code, '') AS conf_code, coalesce(conf_name, '') AS conf_name, conf_address, conf_city,
    conf_postal_code, try_parse(s_year, s_month, s_day) AS conf_start_date,
    try_parse(e_year, e_month, e_day) AS conf_end_date, conf_number, conf_catalog_number
    FROM
      xmltable(--
          '//bibrecord/head/source' PASSING scopus_doc_xml COLUMNS --
        conf_code TEXT PATH 'additional-srcinfo/conferenceinfo/confevent/confcode', conf_name TEXT PATH 'normalize-space(additional-srcinfo/conferenceinfo/confevent/confname)', conf_address TEXT PATH 'additional-srcinfo/conferenceinfo/confevent/conflocation/address-part', conf_city TEXT PATH 'additional-srcinfo/conferenceinfo/confevent/conflocation/city', conf_postal_code TEXT PATH 'additional-srcinfo/conferenceinfo/confevent/conflocation/postal-code', s_year SMALLINT PATH 'additional-srcinfo/conferenceinfo/confevent/confdate/startdate/@year', s_month SMALLINT PATH 'additional-srcinfo/conferenceinfo/confevent/confdate/startdate/@month', s_day SMALLINT PATH 'additional-srcinfo/conferenceinfo/confevent/confdate/startdate/@day', e_year SMALLINT PATH 'additional-srcinfo/conferenceinfo/confevent/confdate/enddate/@year', e_month SMALLINT PATH 'additional-srcinfo/conferenceinfo/confevent/confdate/enddate/@month', e_day SMALLINT PATH 'additional-srcinfo/conferenceinfo/confevent/confdate/enddate/@day', conf_number TEXT PATH 'additional-srcinfo/conferenceinfo/confevent/confnumber', conf_catalog_number TEXT PATH 'additional-srcinfo/conferenceinfo/confevent/confcatnumber');
  COMMIT;

  UPDATE stg_scopus_conference_events sce
     SET conf_sponsor=sq.conf_sponsor
    FROM
      (
        SELECT
          coalesce(conf_code, '') AS conf_code, coalesce(conf_name, '') AS conf_name,
          string_agg(conf_sponsor, ',') AS conf_sponsor
          FROM
            xmltable(--
                '//bibrecord/head/source/additional-srcinfo/conferenceinfo/confevent/confsponsors/confsponsor' --
                PASSING scopus_doc_xml COLUMNS --
                  conf_code TEXT PATH '../../confcode', conf_name TEXT PATH 'normalize-space(../../confname)', conf_sponsor TEXT PATH 'normalize-space(.)')
         GROUP BY conf_code, conf_name
      ) AS sq
   WHERE sce.conf_code = sq.conf_code AND sce.conf_name = sq.conf_name;
  COMMIT;

  -- scopus_conf_proceedings
  INSERT INTO stg_scopus_conf_proceedings(ernie_source_id, conf_code, conf_name, proc_part_no, proc_page_range,
                                          proc_page_count)
  SELECT
    pub_ernie_source_id AS ernie_source_id, coalesce(conf_code, '') AS conf_code, coalesce(conf_name, '') AS conf_name,
    proc_part_no, proc_page_range,
    CASE
      WHEN proc_page_count LIKE '%p'
        THEN RTRIM(proc_page_count, 'p') :: SMALLINT
      WHEN proc_page_count LIKE '%p.'
        THEN RTRIM(proc_page_count, 'p.') :: SMALLINT
      WHEN proc_page_count ~ '[^0-9]'
        THEN NULL
      ELSE proc_page_count :: SMALLINT
    END
    FROM
      xmltable(--
          '//bibrecord/head/source/additional-srcinfo/conferenceinfo/confpublication' PASSING scopus_doc_xml COLUMNS --
        conf_code TEXT PATH 'preceding-sibling::confevent/confcode', conf_name TEXT PATH 'normalize-space(preceding-sibling::confevent/confname)', proc_part_no TEXT PATH 'procpartno', proc_page_range TEXT PATH 'procpagerange', proc_page_count TEXT PATH 'procpagecount')
   WHERE proc_part_no IS NOT NULL OR proc_page_range IS NOT NULL OR proc_page_count IS NOT NULL;
  COMMIT;

  -- scopus_conf_editors
  INSERT INTO stg_scopus_conf_editors(ernie_source_id, conf_code, conf_name, indexed_name,
                                      surname, degree)
  SELECT
    pub_ernie_source_id AS ernie_source_id, coalesce(conf_code, '') AS conf_code, coalesce(conf_name, '') AS conf_name,
    coalesce(indexed_name, '') AS indexed_name, surname, degree
    FROM
      xmltable(--
          XMLNAMESPACES ('http://www.elsevier.com/xml/ani/common' AS ce), --
          '//bibrecord/head/source/additional-srcinfo/conferenceinfo/confpublication/confeditors/editors/editor' --
          PASSING scopus_doc_xml COLUMNS --
            conf_code TEXT PATH '../../../preceding-sibling::confevent/confcode', conf_name TEXT PATH 'normalize-space(../../../preceding-sibling::confevent/confname)', indexed_name TEXT PATH 'ce:indexed-name', surname TEXT PATH 'ce:surname', given_name TEXT PATH 'ce:given-name', degree TEXT PATH 'ce:degrees');
  COMMIT;

  UPDATE stg_scopus_conf_editors sed
     SET address=sq.address
    FROM
      (
        SELECT
          pub_ernie_source_id AS ernie_source_id, coalesce(conf_code, '') AS conf_code,
          coalesce(conf_name, '') AS conf_name, string_agg(address, ',') AS address
          FROM
            xmltable(--
                '//bibrecord/head/source/additional-srcinfo/conferenceinfo/confpublication/confeditors/editoraddress' --
                PASSING scopus_doc_xml COLUMNS --
                  conf_code TEXT PATH '../../preceding-sibling::confevent/confcode', conf_name TEXT PATH '../../preceding-sibling::confevent/confname', address TEXT PATH 'normalize-space()')
         GROUP BY pub_ernie_source_id, conf_code, conf_name
      ) AS sq
   WHERE sed.ernie_source_id = sq.ernie_source_id AND sed.conf_code = sq.conf_code AND sed.conf_name = sq.conf_name;
  COMMIT;

  UPDATE stg_scopus_conf_editors sed
     SET organization=sq.organization
    FROM
      (
        SELECT
          pub_ernie_source_id AS ernie_source_id, coalesce(conf_code, '') AS conf_code,
          coalesce(conf_name, '') AS conf_name, string_agg(organization, ',') AS organization
          FROM
            xmltable(--
                '//bibrecord/head/source/additional-srcinfo/conferenceinfo/confpublication/confeditors/editororganization'
                PASSING scopus_doc_xml COLUMNS --
                  conf_code TEXT PATH '../../preceding-sibling::confevent/confcode', conf_name TEXT PATH '../../preceding-sibling::confevent/confname', organization TEXT PATH 'normalize-space()')
         GROUP BY pub_ernie_source_id, conf_code, conf_name
      ) AS sq
   WHERE sed.ernie_source_id = sq.ernie_source_id AND sed.conf_code = sq.conf_code AND sed.conf_name = sq.conf_name;
  COMMIT;
END; $block$