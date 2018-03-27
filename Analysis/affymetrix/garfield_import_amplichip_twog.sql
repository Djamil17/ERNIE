0;95;0c-- Script to generate csv files for import into neo4j
-- This is the affymetrix case study tracing the affy seedset of <= 1991 to the Amplichip CYP450
-- Panel of 2005
-- Author: George Chacko 2/22/2018

-- End point is the garfield_hgraph series, which contains 23 wos_ids from Garfield's microarray historiograph
-- Starting point is all papers identified in a keyword search in PubMed for Amplichip
-- Publications are connected/related by citation. The target is cited by the source.

-- Citation endpoint is 23 pubs in the garfield_historiograph
/*
DROP TABLE IF EXISTS garfield_hgraph_end;
CREATE TABLE garfield_hgraph_end AS
SELECT source_id, publication_year 
FROM wos_publications WHERE source_id IN 
(select distinct wos_id from garfield_hgraph2) AND
publication_year <= 1992;

-- get first gen of citing references
DROP TABLE IF EXISTS garfield_gen1;
CREATE TABLE garfield_gen1 AS
SELECT source_id AS source, cited_source_uid AS target,
'source'::varchar(10) AS stype, 'endref'::varchar(10) AS ttype
FROM wos_references WHERE cited_source_uid IN
(select source_id from garfield_hgraph_end);
CREATE INDEX garfield_gen1_idx ON garfield_gen1(source);

-- get second gen of citing references
DROP TABLE IF EXISTS garfield_gen2;
CREATE TABLE garfield_gen2 AS
SELECT source_id AS source, cited_source_uid AS target,
'source'::varchar(10) AS stype, 'target'::varchar(10) AS ttype
FROM wos_references WHERE cited_source_uid IN
(select source from garfield_gen1);
CREATE INDEX garfield_gen2_idx ON garfield_gen2(source);

*/

--Citation starting point is publications Amplichip CYP450 keyword search
-- get two generations of cited references

DROP TABLE IF EXISTS garfield_amplichip;
CREATE TABLE garfield_amplichip (pmid int);
\COPY garfield_amplichip FROM '~/ERNIE/Analysis/affymetrix/garfield_amplichip.csv' CSV DELIMITER ','; 

DROP TABLE IF EXISTS garfield_amplichip2;
CREATE TABLE garfield_amplichip2 AS
SELECT a.pmid,b.wos_id 
FROM garfield_amplichip a
INNER JOIN wos_pmid_mapping b ON
a.pmid=b.pmid_int;

DROP TABLE IF EXISTS garfield_amplichip3;
CREATE TABLE garfield_amplichip3 AS
SELECT a.*,b.cited_source_uid AS citedref1 
FROM  garfield_amplichip2 a INNER JOIN 
wos_references b ON a.wos_id=b.source_id;
CREATE INDEX garfield_amplichip3_idx ON garfield_amplichip3(citedref1);

DROP TABLE IF EXISTS garfield_amplichip3_clean;
CREATE TABLE garfield_amplichip3_clean AS
SELECT a.* FROM garfield_amplichip3 a INNER JOIN
wos_publications b ON a.citedref1=b.source_id;

DROP TABLE IF EXISTS garfield_amplichip4;
CREATE TABLE garfield_amplichip4 AS
SELECT a.*,b.cited_source_uid AS citedref2
FROM garfield_amplichip3_clean a LEFT JOIN 
wos_references b on a.citedref1=b.source_id;
CREATE INDEX garfield_amplichip4_idx on garfield_amplichip4(citedref2);

DROP TABLE IF EXISTS garfield_amplichip4_clean;
CREATE TABLE garfield_amplichip4_clean AS
SELECT a.* FROM garfield_amplichip4 a INNER JOIN
wos_publications b ON a.citedref2=b.source_id;

DROP TABLE IF EXISTS garfield_amplichip_begin;
CREATE TABLE garfield_amplichip_begin AS
SELECT wos_id AS source, citedref1 AS target,
'startref'::varchar(10) AS stype, 'target'::varchar(10) AS ttype
FROM garfield_amplichip3_clean;
INSERT INTO garfield_amplichip_begin(source,target,stype,ttype)
SELECT citedref1,citedref2,'source'::varchar(10),'target'::varchar(10)
FROM garfield_amplichip4_clean; 
CREATE INDEX garfield_amplichip_begin_idx ON garfield_amplichip_begin(source,target);

-- begin node list assembly process.
DROP TABLE IF EXISTS garfield_amplichip_node_assembly;
CREATE TABLE  garfield_amplichip_node_assembly(node_id varchar(19),ntype varchar(10));

--build node_table
--citedref1
INSERT INTO garfield_amplichip_node_assembly(node_id,ntype) 
SELECT DISTINCT source, stype 
FROM garfield_amplichip_begin;
--citedref2
INSERT INTO garfield_amplichip_node_assembly(node_id,ntype) 
SELECT DISTINCT target,ttype
FROM garfield_amplichip_begin;

-- add in endrefs and citing refs from garfield_import_dmet_twog.sql
INSERT INTO garfield_amplichip_node_assembly(node_id,ntype)
SELECT DISTINCT source,stype
FROM garfield_dmet_begin;

INSERT INTO garfield_amplichip_node_assembly(node_id,ntype)
SELECT DISTINCT target,ttype
FROM garfield_dmet_begin;

DROP TABLE IF EXISTS garfield_amplichip_nodelist;
CREATE TABLE garfield_amplichip_nodelist AS
SELECT DISTINCT * FROM arfield_amplichip_node_assembly;

--build edge_table
DROP TABLE IF EXISTS garfield_amplichip_edge_table;
CREATE TABLE garfield_amplichip_edge_table(source varchar(19), target varchar(19),
stype varchar(10),ttype varchar(10));

INSERT INTO garfield_amplichip_edge_table(source, target, stype, ttype)
SELECT source,target,stype,ttype FROM garfield_amplichip_begin;
INSERT INTO garfield_amplichip_edge_table
SELECT source,target,stype,ttype FROM garfield_gen1;
INSERT INTO garfield_amplichip_edge_table
SELECT source,target,stype,ttype FROM garfield_gen2;
CREATE INDEX garfield_edge_table_idx ON garfield_edge_table(source,target);

DROP TABLE IF EXISTS garfield_amplichip_edgelist;
CREATE TABLE garfield_amplichip_edgelist AS
SELECT DISTINCT * FROM garfield_edge_table
ORDER BY source,target;
CREATE INDEX garfield_edgelist_idx ON garfield_edgelist(source,target);

-- create formatted nodelist with unique node_ids
DROP TABLE IF EXISTS garfield_amplichip_nodelist_formatted_a;
CREATE TABLE garfield_amplichip_nodelist_formatted_a (node_id varchar(19), ntype varchar(10), startref varchar(10), endref varchar(10));
INSERT INTO garfield_amplichip_nodelist_formatted_a (node_id,ntype) SELECT DISTINCT * FROM garfield_amplichip_nodelist;			   
UPDATE garfield_amplichip_nodelist_formatted_a SET startref=1 WHERE stype='startref';
UPDATE garfield_amplichip_nodelist_formatted_a SET startref=0 WHERE stype='source' OR stype IS NULL;
UPDATE garfield_nodelist_formatted_a SET endref=1 WHERE ttype='endref';
UPDATE garfield_amplichip_nodelist_formatted_a SET endref=0 WHERE ttype='target' OR ttype IS NULL;

DROP TABLE IF EXISTS garfield_amplichip_nodelist_formatted_b;
CREATE TABLE garfield_amplichip_nodelist_formatted_b AS
SELECT DISTINCT node_id, node_name, startref, endref FROM garfield_nodelist_formatted_a;
CREATE INDEX garfield_amplichip_nodelist_formatted_b_idx ON garfield_nodelist_formatted_b(node_name);

DROP TABLE IF EXISTS garfield_amplichip_nodelist_formatted_b_pmid;
CREATE TABLE garfield_amplichip_nodelist_formatted_b_pmid AS
SELECT a.*,b.pmid_int FROM garfield_amplichip_nodelist_formatted_b a 
LEFT JOIN wos_pmid_mapping b ON a.node_name=b.wos_id;

DROP TABLE IF EXISTS garfield_amplichip_nodelist_formatted_b_pmid_grants;
CREATE TABLE garfield_amplichip_nodelist_formatted_b_pmid_grants AS
SELECT
  a.*,
  EXISTS(SELECT 1
         FROM exporter_publink b
         WHERE a.pmid_int = b.pmid :: INT AND substring(b.project_number, 4, 2) = 'DA') AS nida_support,
  EXISTS(SELECT 1
         FROM exporter_publink b
         WHERE a.pmid_int = b.pmid :: INT AND substring(b.project_number, 4, 2) <> 'DA') AS other_hhs_support
FROM chackoge.garfield_amplichip_nodelist_formatted_b_pmid a;

DROP TABLE IF EXISTS garfield_amplichip_nodelist_formatted_c_pmid_grants;
CREATE TABLE garfield_amplichip_nodelist_formatted_c_pmid_grants AS
SELECT DISTINCT a.*,b.publication_year FROM garfield_amplichip_nodelist_formatted_b_pmid_grants a
LEFT JOIN wos_publications b ON a.node_name=b.source_id;

DROP TABLE IF EXISTS garfield_amplichip_nodelist_final;
CREATE TABLE garfield_amplichip_nodelist_final AS
SELECT DISTINCT node_id, node_name, startref, endref, nida_support, other_hhs_support, publication_year 
FROM garfield_amplichip_nodelist_formatted_c_pmid_grants;

CREATE INDEX garfield_amplichip_nodelist_final_idx ON garfield_amplichip_nodelist_final(node_name);

-- remove duplicate rows
DELETE FROM garfield_amplichip_nodelist_final WHERE node_id IN (select node_id from garfield_amplichip_nodelist_final ou
where (select count(*) from garfield_amplichip_nodelist_final inr
where inr.node_name = ou.node_name) > 1 order by node_name) AND startref='0' AND endref='0';

DELETE FROM garfield_amplichip_edgelist ou WHERE (select count(*) from garfield_amplichip_edgelist inr
where inr.source= ou.source and inr.target=ou.target) > 1 
AND stype='source' AND ttype='target';

-- adding a citation count column to nodelist

DROP TABLE IF EXISTS garfield_amplichip_node_citation_a;
CREATE TABLE garfield_amplichip_node_citation_a AS 
SELECT a.node_name,count(b.source_id) AS total_citation_count 
FROM garfield_amplichip_nodelist_final a LEFT JOIN wos_references b 
ON  a.node_name=b.cited_source_uid group by a.node_name;

DROP TABLE IF EXISTS garfield_amplichip_nodelist_final_citation;
CREATE TABLE garfield_amplichip_nodelist_final_citation AS
SELECT DISTINCT a.*,b.total_citation_count 
FROM garfield_amplichip_nodelist_final a 
LEFT JOIN garfield_amplichip_node_citation_a b 
ON a.node_name=b.node_name;

-- copy tables to /tmp for import
COPY (
  SELECT node_name AS "wos_id:ID",
    CAST(startref = '1' AS text) AS "startref:boolean",
    CAST(endref = '1' AS text) AS "endref:boolean",
    CAST(nida_support AS text) AS "nida_support:boolean",
    CAST(other_hhs_support AS text) AS "other_hhs_support:boolean",
    publication_year AS "publication_year:int",
    total_citation_count AS "total_citations:int"
  FROM chackoge.garfield_nodelist_final_citation
) TO '/tmp/garfield_amplichip_nodelist_final.csv' WITH (FORMAT CSV, HEADER);

COPY (
  SELECT source AS ":START_ID",
    target AS ":END_ID"
  FROM chackoge.garfield_edgelist
) TO '/tmp/garfield_amplichip_edgelist_final.csv' WITH (FORMAT CSV, HEADER);

