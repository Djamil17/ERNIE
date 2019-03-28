\set ON_ERROR_STOP on
\set ECHO all

-- DataGrip: start execution from here
SET TIMEZONE = 'US/Eastern';

-- This function performs a bulk update by inserting mapped XML data from a staging table which holds (raw) XML from the update files.
-- On failure it reverts to a debugger version of the function which performs individual inserts of valid instances of the mapped XML data
CREATE OR REPLACE PROCEDURE update_references(input_xml XML) AS
$$
  BEGIN
    INSERT INTO scopus_references(scp,ref_sgr,pub_ref_id,citation_text)
    SELECT
          xmltable.scp AS scp,
          xmltable.ref_sgr AS ref_sgr,
          xmltable.pub_ref_id AS pub_ref_id,
          COALESCE(xmltable.ref_fulltext,xmltable.ref_text) AS citation_text
     FROM
     XMLTABLE('//bibrecord/tail/bibliography/reference' PASSING input_xml
              COLUMNS
                scp BIGINT PATH '//itemidlist/itemid[@idtype="SCP"]/text()',
                ref_sgr BIGINT PATH 'ref-info/refd-itemidlist/itemid[@idtype="SGR"]/text()',
                pub_ref_id INT PATH'@id',
                ref_fulltext TEXT PATH 'ref-fulltext/text()[1]', -- should work around situations where additional tags are included in the text field (e.g. a <br/> tag). Otherwise, would encounter a "more than one value returned by column XPath expression" error.
                ref_text TEXT PATH 'ref-info/ref-text/text()[1]'
                )
    ON CONFLICT DO NOTHING;
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE 'FAILURE OCCURED ON BULK INSERT, SWITCHING TO INDIVIDUAL INSERT+DEBUG FUNCTION';
      CALL update_references_debug(input_xml);
  END;
$$
LANGUAGE plpgsql;

-- This function loops through XML records in the staging table and inserts valid instances of mapped data. It's slower than the other function, but safer.
-- On failure it will raise a notice regarding the invalid XML
CREATE OR REPLACE PROCEDURE update_references_debug(input_xml XML) AS
$$
  DECLARE row RECORD;
  BEGIN
      FOR row IN
        SELECT
              xmltable.scp AS scp,
              xmltable.ref_sgr AS ref_sgr,
              xmltable.pub_ref_id AS pub_ref_id,
              COALESCE(xmltable.ref_fulltext,xmltable.ref_text) AS citation_text
         FROM XMLTABLE('//bibrecord/tail/bibliography/reference' PASSING input_xml
                  COLUMNS
                    scp BIGINT PATH '//itemidlist/itemid[@idtype="SCP"]/text()',
                    ref_sgr BIGINT PATH 'ref-info/refd-itemidlist/itemid[@idtype="SGR"]/text()',
                    pub_ref_id INT PATH'@id',
                    ref_fulltext TEXT PATH 'ref-fulltext/text()[1]', -- should work around situations where additional tags are included in the text field (e.g. a <br/> tag)
                    ref_text TEXT PATH 'ref-info/ref-text/text()[1]'
                    )
      LOOP
        BEGIN
          INSERT INTO scopus_references VALUES (row.scp,row.ref_sgr,row.pub_ref_id,row.citation_text) ON CONFLICT DO NOTHING;
        -- Exception commented out so that error bubbles up
        /*EXCEPTION WHEN OTHERS THEN
          RAISE NOTICE 'CANNOT INSERT VALUES (scp=%,ref_sgr=%,pub_ref_id=%)',row.scp,row.ref_sgr,row.pub_ref_id;
          CONTINUE;*/
        END;
      END LOOP;
  END;
$$
LANGUAGE plpgsql;
