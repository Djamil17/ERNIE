/*
 Author: Djamil Lakhdar-Hamina

 lexis-nexis table and parsers

 */

\timing

 ---- region lexis_nexis_patent_priority_claims
DROP TABLE IF EXISTS lexis_nexis_patent_priority_claims;
CREATE TABLE lexis_nexis_patent_priority_claims (
  doc_number,
  country_code,
  kind_code,
  publication_language,
  priority_claim,
  sequence,
  number,
  date,
  last_updated_time TIMESTAMP DEFAULT now(),
  CONSTRAINT lexis_nexis_patent_priority_claims_pk PRIMARY KEY (country_code,doc_number,kind_code,language) USING INDEX TABLESPACE index_tbs
)
TABLESPACE lexis_nexis_tbs;

CREATE OR REPLACE PROCEDURE lexis_nexis_patent_priority_claims_parser (input_xml XML)
AS
$$
  BEGIN
      INSERT INTO lexis_nexis_patent_priority_claims(doc_number, country_code, kind_code,
                                                     publication_language, priority_claim,
                                                     sequence, number, date, last_updated_time)
    SELECT
      xmltable.doc_number,
      xmltable.country_code,
      xmltable.kind_code,
      xmltable.publication_language,
      xmltable.priority_claim_doc_number,
      xmltable.priority_claim_sequence,
      to_date(xmltable.priority_claim_date, 'YYYYMMDD')
    FROM xml_test, xmltable('//priority-claim' PASSING priority_claim COLUMNS
 -- The highest-level of the xml tree-structure
    doc_number TEXT PATH '//publication-reference/document-id/doc-number',
    country_code TEXT PATH '//publication-reference/document-id/country',
    kind_code TEXT PATH '//publication-reference/document-id/kind',
    publication_language TEXT PATH '//publication-reference/document-id/kind',
    -- Access the attributes
    priority_sequence TEXT PATH '@sequence',
    priority_doc_number TEXT PATH 'doc-number',
    priority_date TEXT PATH 'date')
    ON CONFLICT DO NOTHING;
end;
$$
LANGUAGE plpsql;
