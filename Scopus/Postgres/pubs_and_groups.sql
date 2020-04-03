/* WITH cte AS ( SELECT plainto_tsquery('english', document_title), * FROM dblp_publications LIMIT 10 )
SELECT scp, title
  FROM scopus_titles
 WHERE to_tsvector('english', title) @@ SELECT plainto_tsquery()
  FROM cte
     )
 GROUP BY cte.plainto_tsquery;*/

SELECT dp.id, dp.document_title, st.scp, st.title, st.language
  FROM scopus_titles st, dblp_publications dp
WHERE to_tsvector('english', st.title) @@ plainto_tsquery('english', document_title)
LIMIT 1000;

SELECT *
FROM scopus_publication_groups
WHERE sgr = :scp;

SELECT *
FROM scopus_publications
WHERE sgr = :scp;

SELECT st.*
FROM
    scopus_titles st
        JOIN scopus_publications sp ON sp.scp = st.scp AND sp.sgr = 20384762;

SELECT count(1)
FROM scopus_publications
WHERE scp <> sgr;
-- 0
-- 2m:18s