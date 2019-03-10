\set ON_ERROR_STOP on
\set ECHO all

-- DataGrip: start execution from here
SET TIMEZONE = 'US/Eastern';

DROP TABLE IF EXISTS scopus_publications CASCADE;

CREATE TABLE scopus_publication_groups (
  sgr BIGINT,
  pub_year SMALLINT,
  pub_date DATE,
  CONSTRAINT scopus_publication_groups_pk PRIMARY KEY (sgr) USING INDEX TABLESPACE index_tbs
) TABLESPACE scopus_tbs;

DROP TABLE IF EXISTS scopus_publications CASCADE;

CREATE TABLE scopus_publications (
  scp BIGINT
    CONSTRAINT scopus_publications_pk PRIMARY KEY USING INDEX TABLESPACE index_tbs,
  sgr BIGINT
    CONSTRAINT sp_sgr_fk REFERENCES scopus_publication_groups ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
  language_code CHAR(3),
  citation_title TEXT,
  title_lang_code CHAR(3),
--   abstract TEXT,
--   abstract_lang_code CHAR(3),
  correspondence_person_indexed_name TEXT,
  correspondence_org TEXT,
  correspondence_city TEXT,
  correspondence_country TEXT,
  correspondence_e_address TEXT
) TABLESPACE scopus_tbs;

DROP TABLE IF EXISTS scopus_pub_authors CASCADE;

CREATE TABLE scopus_pub_authors (
  scp BIGINT
    CONSTRAINT spa_source_scp_fk REFERENCES scopus_publications ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
  author_seq SMALLINT,
  auid BIGINT,
  author_indexed_name TEXT,
  author_surname TEXT,
  author_given_name TEXT,
  author_initials TEXT,
  author_e_address TEXT,
  CONSTRAINT scopus_pub_authors_pk PRIMARY KEY (scp, author_seq) USING INDEX TABLESPACE index_tbs
) TABLESPACE scopus_tbs;

DROP TABLE IF EXISTS scopus_references CASCADE;

CREATE TABLE scopus_references (
scp BIGINT
CONSTRAINT sr_source_scp_fk REFERENCES scopus_publications ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
ref_sgr BIGINT
CONSTRAINT sr_ref_sgr_fk REFERENCES scopus_publication_groups ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
CONSTRAINT scopus_references_pk PRIMARY KEY (scp, ref_sgr) USING INDEX TABLESPACE index_tbs
) TABLESPACE scopus_tbs;
