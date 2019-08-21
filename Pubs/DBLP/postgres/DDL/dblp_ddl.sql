\set ON_ERROR_STOP on
\set ECHO all

-- SET default_tablespace = dblp_tbs;

CREATE TABLE dblp_publications (
  begin_page         VARCHAR,
  modified_date 	   DATE,
  document_title     VARCHAR,
  document_type      VARCHAR,
  end_page           VARCHAR,
  id                 SERIAL      NOT NULL,
  issue              VARCHAR,
  publication_year   VARCHAR,
  publisher_address  VARCHAR,
  publisher_name     VARCHAR,
  source_id          VARCHAR PRIMARY KEY USING INDEX TABLESPACE index_tbs,
  source_title       VARCHAR,
  source_type        VARCHAR NOT NULL,
  volume             VARCHAR,
  last_updated_time  TIMESTAMP DEFAULT current_timestamp
) TABLESPACE dblp_tbs;

CREATE INDEX dblp_publications_source_type_source_id_year_i
  ON dblp_publications (source_type,source_id) TABLESPACE index_tbs;

COMMENT ON TABLE dblp_publications
IS 'Main DBLP table';

COMMENT ON COLUMN dblp_publications.begin_page
IS ' Example: 1421';

COMMENT ON COLUMN dblp_publications.modified_date
IS ' Example: 2016-03-18';

COMMENT ON COLUMN dblp_publications.document_title
IS 'Paper title. Example: Trace- and failure-based semantics for responsiveness';

COMMENT ON COLUMN dblp_publications.document_type
IS ' edited/withdrawn etc..  Example: edited';

COMMENT ON COLUMN dblp_publications.end_page
IS ' Example: 1432';

COMMENT ON COLUMN dblp_publications.id
IS 'id is always an integer- is an internal (PARDI) number. Example: 1';

COMMENT ON COLUMN dblp_publications.issue
IS ' Example: 8';

COMMENT ON COLUMN dblp_publications.publication_year
IS ' Example: 2015';

COMMENT ON COLUMN dblp_publications.publisher_address
IS ' Example: New York';

COMMENT ON COLUMN dblp_publications.publisher_name
IS ' Example: Springer';

COMMENT ON COLUMN dblp_publications.source_id
IS 'Paper Id Example: journals/acta/Devroye87';

COMMENT ON COLUMN dblp_publications.source_title
IS 'Journal title or Book title. Example: Acta Inf';

COMMENT ON COLUMN dblp_publications.source_type
IS ' Article/Proceedings,Inproceedings etc... Example: Article';

COMMENT ON COLUMN dblp_publications.volume
IS ' Example: 202';



CREATE TABLE dblp_document_identifiers (
  id                SERIAL,
  source_id         VARCHAR  NOT NULL DEFAULT '',
  document_id       VARCHAR NOT NULL DEFAULT '',
  document_id_type  VARCHAR  NOT NULL DEFAULT '',
  last_updated_time TIMESTAMP             DEFAULT current_timestamp,
  CONSTRAINT dblp_document_identifiers_pk PRIMARY KEY (source_id, document_id_type, document_id)
) TABLESPACE dblp_tbs;

CREATE INDEX IF NOT EXISTS dblp_document_id_type_document_id_i
  ON dblp_document_identifiers (document_id_type, document_id) TABLESPACE index_tbs;

COMMENT ON TABLE dblp_document_identifiers
IS 'DBLP document identifiers such as doi/crossref';

COMMENT ON COLUMN dblp_document_identifiers.id
IS ' Example: 1';

COMMENT ON COLUMN dblp_document_identifiers.source_id
IS 'UT. Example: journals/acta/Schonhage77';

COMMENT ON COLUMN dblp_document_identifiers.document_id
IS ' Example: https://doi.org/10.1007/BF00289470';

COMMENT ON COLUMN dblp_document_identifiers.document_id_type
IS 'url/ee/isbn/crossref etc.. Example: url';

CREATE TABLE dblp_authors (
  id                SERIAL,
  source_id         VARCHAR NOT NULL DEFAULT '',
  full_name         VARCHAR,
  last_name         VARCHAR,
  first_name        VARCHAR,
  seq_no            INTEGER     NOT NULL DEFAULT 0,
  orc_id            VARCHAR,
  editor_name 		VARCHAR,
  last_updated_time TIMESTAMP            DEFAULT current_timestamp,
  CONSTRAINT dblp_authors_pk PRIMARY KEY (source_id, seq_no)

) TABLESPACE dblp_tbs;


CREATE TABLE dblp_references (
  dblp_reference_id   SERIAL,
  source_id          VARCHAR NOT NULL,
  cited_source_id   VARCHAR NOT NULL, 
  last_updated_time  TIMESTAMP DEFAULT current_timestamp
) TABLESPACE dblp_tbs;

ALTER TABLE dblp_references
  ADD CONSTRAINT dblp_references_pk PRIMARY KEY (source_id, cited_source_id) USING INDEX TABLESPACE index_tbs;

CREATE INDEX dblp_cited_source_uid_source_id_i
  ON dblp_references (cited_source_id, source_id) TABLESPACE index_tbs;

COMMENT ON TABLE dblp_references
IS 'DBLP data cited references';

COMMENT ON COLUMN dblp_references.dblp_reference_id
IS 'auto-increment integer, serving as a row key in distributed systems. Example: 1';

COMMENT ON COLUMN dblp_references.source_id
IS 'Example: journals/toplas/MannaW80';

COMMENT ON COLUMN dblp_references.cited_source_id
IS 'Example: journals/jacm/Summers77';
