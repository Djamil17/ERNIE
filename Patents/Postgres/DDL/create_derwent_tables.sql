/*
  This script is used to (re)create the Derwent tables on the ERNIE server
*/
SET default_tablespace = derwent;

DROP TABLE IF EXISTS derwent_patents;
DROP TABLE IF EXISTS derwent_inventors;
DROP TABLE IF EXISTS derwent_examiners;
DROP TABLE IF EXISTS derwent_assignees;
DROP TABLE IF EXISTS derwent_pat_citations;
DROP TABLE IF EXISTS derwent_agents;
DROP TABLE IF EXISTS derwent_assignors;
DROP TABLE IF EXISTS derwent_lit_citations;



CREATE TABLE derwent_patents (
    id integer,
    patent_num_orig character varying(30),
    patent_num_wila character varying(30),
    patent_num_tsip character varying(30),
    patent_type character varying(20),
    status character varying(30),
    file_name character varying(50),
    country character varying(4),
    date_published character varying(50),
    appl_num_orig character varying(30),
    appl_num_wila character varying(30),
    appl_num_tsip character varying(30),
    appl_date character varying(50),
    appl_year character varying(4),
    appl_type character varying(20),
    appl_country character varying(4),
    appl_series_code character varying(4),
    ipc_classification character varying(20),
    main_classification character varying(20),
    sub_classification character varying(20),
    invention_title character varying(1000),
    claim_text text,
    government_support text,
    summary_of_invention text,
    parent_patent_num_orig character varying(30)
);

CREATE TABLE derwent_inventors (
    id integer,
    patent_num character varying(30),
    inventors character varying(300),
    full_name character varying(500),
    last_name character varying(1000),
    first_name character varying(1000),
    city character varying(100),
    state character varying(100),
    country character varying(60)
);

-- region derwent_examiners
CREATE TABLE IF NOT EXISTS derwent_examiners (
  id            INTEGER,
  patent_num    VARCHAR(30)  NOT NULL,
  full_name     VARCHAR(100) NOT NULL,
  examiner_type VARCHAR(30)  NOT NULL,
  CONSTRAINT derwent_examiners_pk PRIMARY KEY (patent_num, examiner_type) USING INDEX TABLESPACE index_tbs
) TABLESPACE derwent_tbs;

COMMENT ON TABLE derwent_examiners
IS 'Thomson Reuters: Derwent - Patent examiners and examiner type';

COMMENT ON COLUMN derwent_examiners.id
IS ' Example: 1';

COMMENT ON COLUMN derwent_examiners.patent_num
IS ' Example: 04890722';

COMMENT ON COLUMN derwent_examiners.full_name
IS ' Example: Spar, Robert J.';

COMMENT ON COLUMN derwent_examiners.examiner_type
IS 'primary/secondary. Example: primary';
-- endregion


-- region derwent_assignees
CREATE TABLE IF NOT EXISTS derwent_assignees (
  id            INTEGER      NOT NULL,
  patent_num    VARCHAR(30)  NOT NULL DEFAULT '',
  assignee_name VARCHAR(400) NOT NULL DEFAULT '',
  role          VARCHAR(30)  NOT NULL DEFAULT '',
  city          VARCHAR(300) NOT NULL DEFAULT '',
  state         VARCHAR(200),
  country       VARCHAR(60),
  CONSTRAINT derwent_assignees_pk PRIMARY KEY (patent_num, assignee_name, role, city) USING INDEX TABLESPACE index_tbs
) TABLESPACE derwent_tbs;

COMMENT ON TABLE derwent_assignees
IS 'Thomson Reuters: Derwent - Assignee  of the patents';

COMMENT ON COLUMN derwent_assignees.id
IS ' Example: 1';

COMMENT ON COLUMN derwent_assignees.patent_num
IS ' Example: 05857186';

COMMENT ON COLUMN derwent_assignees.assignee_name
IS ' Example: Nippon Steel Corporation';

COMMENT ON COLUMN derwent_assignees.role
IS 'assignee/applicant/applicant-inventor. Example: assignee';

COMMENT ON COLUMN derwent_assignees.city
IS ' Example: Tokyo';

COMMENT ON COLUMN derwent_assignees.state
IS ' Example: CA';

COMMENT ON COLUMN derwent_assignees.country
IS ' Example: JP';
-- endregion

-- region derwent_pat_citations
CREATE TABLE IF NOT EXISTS derwent_pat_citations (
  id                INTEGER,
  patent_num_orig   VARCHAR(30)  NOT NULL,
  cited_patent_orig VARCHAR(100) NOT NULL,
  cited_patent_wila VARCHAR(100),
  cited_patent_tsip VARCHAR(100),
  country           VARCHAR(30)  NOT NULL,
  kind              VARCHAR(20),
  cited_inventor    VARCHAR(400),
  cited_date        VARCHAR(10),
  main_class        VARCHAR(40),
  sub_class         VARCHAR(40),
  CONSTRAINT derwent_pat_citations_pk PRIMARY KEY (patent_num_orig, country, cited_patent_orig) --
  USING INDEX TABLESPACE index_tbs
) TABLESPACE derwent_tbs;

COMMENT ON TABLE derwent_pat_citations
IS 'Thomson Reuters: Derwent - cited patent list of the patents';

COMMENT ON COLUMN derwent_pat_citations.id
IS ' Example: 1';

COMMENT ON COLUMN derwent_pat_citations.patent_num_orig
IS ' Example: 05857186';

COMMENT ON COLUMN derwent_pat_citations.cited_patent_orig
IS ' Example: 05142687';

COMMENT ON COLUMN derwent_pat_citations.cited_patent_wila
IS ' Example: 5142687';

COMMENT ON COLUMN derwent_pat_citations.cited_patent_tsip
IS ' Example: 5142687';

COMMENT ON COLUMN derwent_pat_citations.country
IS ' Example: US';

COMMENT ON COLUMN derwent_pat_citations.kind
IS ' Example: A';

COMMENT ON COLUMN derwent_pat_citations.cited_inventor
IS ' Example: Lary';

COMMENT ON COLUMN derwent_pat_citations.cited_date
IS 'No records yet.';

COMMENT ON COLUMN derwent_pat_citations.main_class
IS ' Example: 707';

COMMENT ON COLUMN derwent_pat_citations.sub_class
IS ' Example: 007000';
-- endregion

-- region derwent_agents
CREATE TABLE IF NOT EXISTS derwent_agents (
  id                INTEGER,
  patent_num        VARCHAR(30)  NOT NULL,
  rep_type          VARCHAR(30),
  last_name         VARCHAR(200),
  first_name        VARCHAR(60),
  organization_name VARCHAR(400) NOT NULL,
  country           VARCHAR(10),
  CONSTRAINT derwent_agents_pk PRIMARY KEY (patent_num, organization_name) USING INDEX TABLESPACE index_tbs
) TABLESPACE derwent_tbs;

COMMENT ON TABLE derwent_agents
IS 'Thomson Reuters: Derwent - patents: patent and agents information';

COMMENT ON COLUMN derwent_agents.id
IS 'id is always an integer- is an internal (PARDI) number. Example: 1';

COMMENT ON COLUMN derwent_agents.patent_num
IS ' Example: 05857186';

COMMENT ON COLUMN derwent_agents.rep_type
IS ' Example: agent';

COMMENT ON COLUMN derwent_agents.last_name
IS ' Example: Whelan';

COMMENT ON COLUMN derwent_agents.first_name
IS 'No records yet.';

COMMENT ON COLUMN derwent_agents.organization_name
IS ' Example: Whelan, John T.';

COMMENT ON COLUMN derwent_agents.country
IS 'No records yet.';
-- endregion

-- region derwent_assignors
CREATE TABLE IF NOT EXISTS derwent_assignors (
  id         INTEGER,
  patent_num VARCHAR(30)  NOT NULL,
  assignor   VARCHAR(400) NOT NULL,
  CONSTRAINT derwent_assignors_pk PRIMARY KEY (patent_num, assignor) USING INDEX TABLESPACE index_tbs
) TABLESPACE derwent_tbs;

COMMENT ON TABLE derwent_assignors
IS 'Thomson Reuters: Derwent - Assignor of the patents';

COMMENT ON COLUMN derwent_assignors.id
IS ' Example: 2';

COMMENT ON COLUMN derwent_assignors.patent_num
IS ' Example: 05857160';

COMMENT ON COLUMN derwent_assignors.assignor
IS ' Example: BROWN, TODD';
-- endregion

-- region derwent_lit_citations
CREATE TABLE IF NOT EXISTS derwent_lit_citations (
  id               INTEGER,
  patent_num_orig  VARCHAR(30)   NOT NULL,
  cited_literature VARCHAR(5000) NOT NULL
) TABLESPACE derwent_tbs;

CREATE UNIQUE INDEX IF NOT EXISTS derwent_lit_citations_uk
  ON derwent_lit_citations (patent_num_orig, md5(cited_literature :: TEXT)) TABLESPACE index_tbs;

COMMENT ON TABLE derwent_lit_citations
IS 'Thomson Reuters: Derwent - cited literature of the patents';

COMMENT ON COLUMN derwent_lit_citations.id
IS ' Example: 1';

COMMENT ON COLUMN derwent_lit_citations.patent_num_orig
IS ' Example: 05857186';

COMMENT ON COLUMN derwent_lit_citations.cited_literature
IS ' Example: Kruse, Data Structures and Program Design, Prentice-Hall, 1984, p. 139-145.';
-- endregion
