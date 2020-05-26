DROP TABLE IF EXISTS theta_plus.imm1985_testcase_asjc2403;
CREATE TABLE theta_plus.imm1985_testcase_asjc2403
TABLESPACE theta_plus_tbs AS
SELECT sp.scp FROM scopus_publications sp
INNER JOIN scopus_publication_groups spg
ON sp.scp=spg.sgr
AND spg.pub_year=1985
AND sp.citation_type='ar'
AND sp.citation_language='English'
INNER JOIN scopus_classes sc
ON sp.scp=sc.scp
AND sc.class_code='2403';
CREATE INDEX imm1985_testcase_asjc_idx
ON theta_plus.imm1985_testcase_asjc2403(scp)
TABLESPACE index_tbs;

DROP TABLE IF EXISTS theta_plus.imm1985_testcase_cited;
CREATE TABLE theta_plus.imm1985_testcase_cited
TABLESPACE theta_plus_tbs AS
SELECT tp.scp as citing,sr.ref_sgr AS cited
FROM theta_plus.imm1985_testcase_asjc2403 tp
INNER JOIN scopus_references sr on tp.scp = sr.scp;
CREATE INDEX imm1985_testcase_cited_idx
ON theta_plus.imm1985_testcase_cited(citing,cited)
TABLESPACE index_tbs;

DROP TABLE IF EXISTS theta_plus.imm1985_testcase_citing;
CREATE TABLE theta_plus.imm1985_testcase_citing TABLESPACE theta_plus_tbs AS
SELECT sr.scp as citing,tp.scp as cited FROM theta_plus.imm1985_testcase_asjc2403 tp
INNER JOIN scopus_references sr on tp.scp=sr.ref_sgr;
CREATE INDEX imm1985_testcase_citing_idx ON theta_plus.imm1985_testcase_citing(citing,cited)
TABLESPACE index_tbs;

select count(1) from imm1985_testcase_asjc2403;
select count(1) from imm1985_testcase_cited;
select count(1) from imm1985_testcase_citing;

DROP TABLE IF EXISTS theta_plus.imm1985_testcase_asjc2403_citing_cited;
CREATE TABLE theta_plus.imm1985_testcase_asjc2403_citing_cited
TABLESPACE theta_plus_tbs AS
SELECT DISTINCT citing,cited from imm1985_testcase_cited UNION
SELECT DISTINCT citing,cited from imm1985_testcase_citing;
SELECT count(1) from imm1985_testcase_asjc2403_citing_cited;

-- clean up Scopus data
DELETE FROM theta_plus.imm1985_testcase_asjc2403_citing_cited
WHERE citing=cited;

DROP TABLE IF EXISTS theta_plus.imm1985_nodes;
CREATE TABLE theta_plus.imm1985_nodes
TABLESPACE theta_plus_tbs AS
SELECT distinct citing as scp
FROM theta_plus.imm1985_testcase_asjc2403_citing_cited
UNION
SELECT distinct cited
FROM theta_plus.imm1985_testcase_asjc2403_citing_cited;

DROP TABLE IF EXISTS theta_plus.imm1985_title_abstracts;
CREATE TABLE theta_plus.imm1985_title_abstracts
TABLESPACE theta_plus_tbs AS
SELECT tpin.scp,st.title,sa.abstract_text
FROM theta_plus.imm1985_nodes tpin
INNER JOIN scopus_titles st ON tpin.scp=st.scp
INNER JOIN scopus_abstracts sa ON tpin.scp=sa.scp
AND sa.abstract_language='eng'
AND st.language='English';

select scp,title from theta_plus.imm1985_title_abstracts limit 5;
select count(1) from theta_plus.imm1985_title_abstracts;

select count(1) from imm1990_testcase_asjc2403;
select count(1) from (select distinct scp from imm1990_testcase_asjc2403)c;
select count(1) from imm1985_testcase_cited;
select count(1) from (select distinct citing from imm1985_testcase_cited)c;
select count(1) from (select distinct cited from imm1985_testcase_cited)c;
select count(1) from (select distinct itc.cited from imm1985_testcase_cited itc
INNER JOIN scopus_publications sp ON
itc.citing=sp.scp)c

DROP TABLE IF EXISTS theta_plus.imm1985_testcase_cited_leftjoin;
CREATE TABLE theta_plus.imm1985_testcase_cited_leftjoin
TABLESPACE theta_plus_tbs AS
SELECT tp.scp as citing,sr.ref_sgr AS cited
FROM theta_plus.imm1985_testcase_asjc2403 tp
LEFT JOIN scopus_references sr on tp.scp = sr.scp;
CREATE INDEX imm1985_testcase_cited_leftjoin_idx
ON theta_plus.imm1985_testcase_cited_leftjoin(citing,cited)
TABLESPACE index_tbs;

select count(1) from theta_plus.imm1985_testcase_cited_leftjoin;
select citing,count(cited) from theta_plus.imm1985_testcase_cited
group by citing having count(cited) > 0
order by count(cited) desc;

112 of size 20

10 random clusters of size 20 and avg:

