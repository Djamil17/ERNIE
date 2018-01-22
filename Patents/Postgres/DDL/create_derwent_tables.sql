-- This script creates temp tables for the derwent smokeload.

-- Author: VJ Davey
-- Created: 08/22/2017
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

CREATE TABLE derwent_examiners (
    id integer,
    patent_num character varying(30),
    full_name character varying(100),
    examiner_type character varying(30)
);

CREATE TABLE derwent_assignees (
    id integer NOT NULL,
    patent_num character varying(30) NOT NULL,
    assignee_name character varying(400),
    role character varying(30),
    city character varying(300),
    state character varying(200),
    country character varying(60)
);

CREATE TABLE derwent_pat_citations (
    id integer,
    patent_num_orig character varying(30),
    cited_patent_orig character varying(100),
    cited_patent_wila character varying(100),
    cited_patent_tsip character varying(100),
    country character varying(30),
    kind character varying(20),
    cited_inventor character varying(400),
    cited_date character varying(10),
    main_class character varying(40),
    sub_class character varying(40)
);

CREATE TABLE derwent_agents (
    id integer,
    patent_num character varying(30),
    rep_type character varying(30),
    last_name character varying(200),
    first_name character varying(60),
    organization_name character varying(400),
    country character varying(10)
);

CREATE TABLE derwent_assignors (
    id integer,
    patent_num character varying(30),
    assignor character varying(400)
);

CREATE TABLE derwent_lit_citations (
    id integer,
    patent_num_orig character varying(30),
    cited_literature character varying(5000)
);

