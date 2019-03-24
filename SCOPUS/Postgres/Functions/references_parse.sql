-- This function performs a bulk update by inserting mapped XML data from a staging table which holds (raw) XML from the update files.
-- On failure it reverts to a debugger version of the function which performs individual inserts of valid instances of the mapped XML data
CREATE OR REPLACE FUNCTION update_references(input_xml XML) RETURNS VOID AS
$$
  BEGIN
    INSERT INTO scopus_references(scp,ref_sgr,pub_ref_id)
    SELECT xmltable.*
     FROM
     XMLTABLE('//bibrecord/tail/bibliography/reference' PASSING input_xml
              COLUMNS
                  scp BIGINT PATH '//itemidlist/itemid[@idtype="SCP"]/text()',
                  ref_sgr BIGINT PATH 'ref-info/refd-itemidlist/itemid[@idtype="SGR"]/text()',
                  pub_ref_id INT PATH'@id'
                )
    ON CONFLICT DO NOTHING;
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE 'FAILURE OCCURED ON BULK INSERT, SWITCHING TO INDIVIDUAL INSERT+DEBUG FUNCTION';
      PERFORM update_references_debug();
  END;
$$
LANGUAGE plpgsql;

-- This function loops through XML records in the staging table and inserts valid instances of mapped data. It's slower than the other function, but safer.
-- On failure it will raise a notice regarding the invalid XML
CREATE OR REPLACE FUNCTION update_references_debug(input_xml XML) RETURNS VOID AS
$$
  DECLARE row RECORD;
  BEGIN
      FOR row IN
        SELECT xmltable.*
         FROM staging_xml_table,
         XMLTABLE('//bibrecord/tail/bibliography/reference' PASSING input_xml
                  COLUMNS
                      scp BIGINT PATH '//itemidlist/itemid[@idtype="SCP"]/text()',
                      ref_sgr BIGINT PATH 'ref-info/refd-itemidlist/itemid[@idtype="SGR"]/text()',
                      pub_ref_id INT PATH'@id'
                    )
      LOOP
        BEGIN
          INSERT INTO scopus_references VALUES (row.scp,row.ref_sgr,row.pub_ref_id) ON CONFLICT DO NOTHING;
        -- Exception commented out so that error bubbles up
        /*EXCEPTION WHEN OTHERS THEN
          RAISE NOTICE 'CANNOT INSERT VALUES (scp=%,ref_sgr=%,pub_ref_id=%)',row.scp,row.ref_sgr,row.pub_ref_id;
          CONTINUE;*/
        END;
      END LOOP;
  END;
$$
LANGUAGE plpgsql;
