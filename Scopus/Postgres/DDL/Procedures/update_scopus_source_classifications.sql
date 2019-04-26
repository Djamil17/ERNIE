\set ON_ERROR_STOP on
\set ECHO all

-- DataGrip: start execution from here
SET TIMEZONE = 'US/Eastern';

-- journal source and classifications
CREATE OR REPLACE PROCEDURE update_scopus_source_classifications(scopus_doc_xml XML)
AS $$
  BEGIN
    -- scopus_source_publication_details
    INSERT INTO scopus_source_publication_details(scp,issue,volume,first_page,last_page,publication_year,publication_date,conf_code,conf_name)

    SELECT
      scp,
      issue,
      volume,
      first_page,
      last_page,
      publication_year,
      make_date(pub_year, pub_month, pub_day) AS publication_date,
      coalesce(conf_code,'') AS conf_code,
      coalesce(conf_name,'') AS conf_name
    FROM
      xmltable(--
      '//bibrecord/head/source' PASSING scopus_doc_xml COLUMNS --
      scp BIGINT PATH '../preceding-sibling::item-info/itemidlist/itemid[@idtype="SCP"]',
      issue TEXT PATH 'volisspag/voliss/@issue',
      volume TEXT PATH 'volisspag/voliss/@volume',
      first_page TEXT PATH 'volisspag/pagerange/@first',
      last_page TEXT PATH 'volisspag/pagerange/@last',
      publication_year SMALLINT PATH 'publicationyear/@first',
      pub_year SMALLINT PATH 'publicationdate/year',
      pub_month SMALLINT PATH 'publicationdate/month',
      pub_day SMALLINT PATH 'publicationdate/day',
      conf_code TEXT PATH 'additional-srcinfo/conferenceinfo/confevent/confcode',
      conf_name TEXT PATH 'additional-srcinfo/conferenceinfo/confevent/confname'
      )
    ON CONFLICT DO NOTHING;

    UPDATE scopus_source_publication_details spd
    SET indexed_terms=sq.indexed_terms
    FROM (
         SELECT
          scp,
          string_agg(descriptors, ',') AS indexed_terms
         FROM xmltable(--
         '//bibrecord/head/enhancement/descriptorgroup/descriptors/descriptor/mainterm' PASSING scopus_doc_xml COLUMNS --
         scp BIGINT PATH '../../../../../preceding-sibling::item-info/itemidlist/itemid[@idtype="SCP"]',
         descriptors TEXT PATH 'normalize-space()'
         )
         GROUP BY scp
         ) as sq
    WHERE spd.scp=sq.scp;

    -- scopus_subjects
    INSERT INTO scopus_subjects (scp, subj_abbr)

    SELECT
      scp,
      subj_abbr
    FROM xmltable(--
      '//bibrecord/head/enhancement/classificationgroup/classifications[@type="SUBJABBR"]/classification' PASSING scopus_doc_xml COLUMNS --
      scp BIGINT PATH '../../../../preceding-sibling::item-info/itemidlist/itemid[@idtype="SCP"]',
      subj_abbr TEXT PATH '.'
      )
    ON CONFLICT DO NOTHING;

    -- scopus_subject_keywords
    INSERT INTO scopus_subject_keywords (scp, subject)

    SELECT 
      scp,
      subject
    FROM xmltable(--
      '//bibrecord/head/enhancement/classificationgroup/classifications[@type="SUBJECT"]/classification' PASSING scopus_doc_xml COLUMNS --
      scp BIGINT PATH '../../../../preceding-sibling::item-info/itemidlist/itemid[@idtype="SCP"]',
      subject TEXT PATH '.'
      )
    ON CONFLICT DO NOTHING;
    
    -- scopus_classes
    INSERT INTO scopus_classes(scp,class_type,class_code)
    SELECT scp,
           class_type,
           coalesce(classification_code, classification) AS class_code
    FROM xmltable(--
      '//bibrecord/head/enhancement/classificationgroup/classifications[not(@type="SUBJABBR" or @type="SUBJECT")]/classification' PASSING scopus_doc_xml COLUMNS --
      scp BIGINT PATH '../../../../preceding-sibling::item-info/itemidlist/itemid[@idtype="SCP"]',
      class_type TEXT PATH '../@type',
      classification_code TEXT PATH 'classification-code',
      classification TEXT PATH '.'
    )
    ON CONFLICT DO NOTHING;

    -- scopus_classification_lookup
    INSERT INTO scopus_classification_lookup(class_type,class_code,description)
    SELECT class_type,
           class_code,
           description
    FROM xmltable(--
      '//bibrecord/head/enhancement/classificationgroup/classifications[not(@type="ASJC" or @type="SUBJABBR" or @type="SUBJECT")]/classification/classification-code' PASSING scopus_doc_xml COLUMNS --
      class_type TEXT PATH '../../@type',
      class_code TEXT PATH '.',
      description TEXT PATH 'following-sibling::classification-description'
    )
    ON CONFLICT DO NOTHING;

  END;
  $$
  LANGUAGE plpgsql;
