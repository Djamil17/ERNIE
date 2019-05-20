-- Total DB size
SELECT pg_size_pretty(pg_database_size(current_database()));
-- 2977 GB

-- Total size of the public schema
SELECT pg_size_pretty(sum(pg_total_relation_size(pc.oid))) AS total_size
FROM pg_class pc --
JOIN pg_namespace pn ON pn.oid = pc.relnamespace AND pn.nspname = 'public' -- Tables, sequences and MVs occupy space.
  -- Indexes and TOAST tables are added automatically by pg_total_relation_size()
WHERE pc.relkind IN('r', 'S', 'm');
-- 2974 GB

-- All tablespaces
SELECT
  pt.spcname AS tablespace,
  pg_size_pretty(COALESCE(pg_tablespace_size(pt.spcname), 0)) AS used_space,
  CASE spcname
    WHEN 'pg_default' THEN ps.setting || '/base'
    WHEN 'pg_global' THEN ps.setting || '/global'
    ELSE pg_tablespace_location(pt.oid)
  END AS location,
  pt.oid AS tablespace_oid
FROM pg_tablespace pt, pg_settings ps
WHERE ps.name = 'data_directory'
ORDER BY pg_tablespace_size(pt.spcname) DESC;

/*
Relations (data-containing objects) by a tablespace excluding TOAST tables and their indexes.
Does not support default DB tablespace
*/
SELECT
  pc.relname,
  pg_size_pretty(pg_relation_size(pc.oid)),
  CASE pc.relkind -- By default, CASE will cast results as char (pc.relkind)
    WHEN 'r' THEN CAST('table' AS TEXT)
    WHEN 'i' THEN 'index'
    WHEN 'S' THEN 'sequence'
    WHEN 'v' THEN 'view'
    WHEN 'm' THEN 'materialized view'
    WHEN 'c' THEN 'composite type'
    WHEN 't' THEN 'TOAST table'
    WHEN 'f' THEN 'foreign table'
    ELSE pc.relkind
  END AS kind,
  pn.nspname AS schema,
  pa.rolname AS owner
FROM pg_class pc
LEFT JOIN pg_tablespace obj_pt ON obj_pt.oid = pc.reltablespace
JOIN pg_database pd ON pd.datname = current_catalog
JOIN pg_tablespace db_pt ON db_pt.oid = pd.dattablespace
JOIN pg_namespace pn ON pn.oid = pc.relnamespace AND pn.nspname = 'public'
JOIN pg_authid pa ON pa.oid = pc.relowner
WHERE coalesce(obj_pt.spcname, db_pt.spcname) = :tablespace AND relname NOT LIKE 'pg_toast_%'
ORDER BY pg_total_relation_size(pc.oid) DESC;

-- Default tablespace parameter
SHOW default_tablespace;

-- Current DB's default tablespace
SELECT datname AS db, pt.spcname AS db_default_tablespace,
  --
       pg_size_pretty(pg_tablespace_size(pt.spcname)) AS used_space
FROM pg_database pd
JOIN pg_tablespace pt ON pt.oid = pd.dattablespace
WHERE datname = current_catalog;

SHOW temp_tablespaces;

-- Database cluster directory
SHOW data_directory;

-- Sizes and tablespaces of all relations (data-containing objects) in the current DB
SELECT
  pc.relname,
  pg_size_pretty(pg_total_relation_size(pc.oid)),
  CASE pc.relkind -- By default, CASE will cast results as char (pc.relkind)
    WHEN 'r' THEN CAST('table' AS TEXT)
    WHEN 'i' THEN 'index'
    WHEN 'S' THEN 'sequence'
    WHEN 'v' THEN 'view'
    WHEN 'm' THEN 'materialized view'
    WHEN 'c' THEN 'composite type'
    WHEN 't' THEN 'TOAST table'
    WHEN 'f' THEN 'foreign table'
    ELSE pc.relkind --
  END AS kind,
  coalesce(obj_pt.spcname, db_pt.spcname) AS tablespace
FROM pg_class pc --
LEFT JOIN pg_tablespace obj_pt ON obj_pt.oid = pc.reltablespace
JOIN pg_database pd ON pd.datname = current_catalog
JOIN pg_tablespace db_pt ON db_pt.oid = pd.dattablespace
ORDER BY pg_total_relation_size(pc.oid) DESC;

-- Size and tablespace of relation(s) (data-containing objects) by name pattern
SELECT
  pc.relname,
  pn.nspname AS schema,
  pa.rolname AS owner,
  pg_size_pretty(pg_total_relation_size(pc.oid)),
  CASE pc.relkind -- By default, CASE will cast results as char (pc.relkind)
    WHEN 'r' THEN CAST('table' AS TEXT)
    WHEN 'i' THEN 'index'
    WHEN 'S' THEN 'sequence'
    WHEN 'v' THEN 'view'
    WHEN 'm' THEN 'materialized view'
    WHEN 'c' THEN 'composite type'
    WHEN 't' THEN 'TOAST table'
    WHEN 'f' THEN 'foreign table'
    ELSE pc.relkind --
  END AS kind,
  coalesce(obj_pt.spcname, db_pt.spcname) AS tablespace
FROM pg_class pc --
JOIN pg_namespace pn ON pn.oid = pc.relnamespace
JOIN pg_authid pa ON pa.oid = pc.relowner
LEFT JOIN pg_tablespace obj_pt ON obj_pt.oid = pc.reltablespace
JOIN pg_database pd ON pd.datname = current_catalog
JOIN pg_tablespace db_pt ON db_pt.oid = pd.dattablespace
WHERE pc.relname LIKE :name_pattern
ORDER BY pg_total_relation_size(pc.oid) DESC;

-- Tablespace of relation(s) (data-containing objects) by name pattern
SELECT pc.relname, --
       pn.nspname AS schema, --
       CASE pc.relkind -- By default, CASE will cast results as char (pc.relkind)
         WHEN 'r' THEN CAST('table' AS TEXT)
         WHEN 'i' THEN 'index'
         WHEN 'S' THEN 'sequence'
         WHEN 'v' THEN 'view'
         WHEN 'm' THEN 'materialized view'
         WHEN 'c' THEN 'composite type'
         WHEN 't' THEN 'TOAST table'
         WHEN 'f' THEN 'foreign table'
         ELSE pc.relkind --
       END AS kind, --
       coalesce(obj_pt.spcname, db_pt.spcname) AS tablespace, pa.rolname AS owner
FROM pg_class pc --
JOIN pg_namespace pn ON pn.oid = pc.relnamespace
JOIN pg_authid pa ON pa.oid = pc.relowner
LEFT JOIN pg_tablespace obj_pt ON obj_pt.oid = pc.reltablespace
JOIN pg_database pd ON pd.datname = current_catalog
JOIN pg_tablespace db_pt ON db_pt.oid = pd.dattablespace
WHERE pc.relname LIKE :name_pattern
ORDER BY schema, relname;

-- Relations (data-containing objects) by kind
SELECT
  pc.relname,
  pg_size_pretty(pg_total_relation_size(pc.oid)),
  CASE pc.relkind
    WHEN 'r' -- By default, CASE will cast results as char (pc.relkind)
            THEN CAST('table' AS TEXT)
    WHEN 'i' THEN 'index'
    WHEN 'S' THEN 'sequence'
    WHEN 'v' THEN 'view'
    WHEN 'm' THEN 'materialized view'
    WHEN 'c' THEN 'composite type'
    WHEN 't' THEN 'TOAST table'
    WHEN 'f' THEN 'foreign table'
    ELSE pc.relkind --
  END AS kind,
  coalesce(obj_pt.spcname, db_pt.spcname) AS tablespace
FROM pg_class pc --
LEFT JOIN pg_tablespace obj_pt ON obj_pt.oid = pc.reltablespace
JOIN pg_database pd ON pd.datname = current_catalog
JOIN pg_tablespace db_pt ON db_pt.oid = pd.dattablespace
WHERE pc.relkind = :relkind
ORDER BY pg_total_relation_size(pc.oid) DESC;

-- Total size for a table + indexes
SELECT pg_size_pretty(pg_total_relation_size(:'table'));

-- Table indexes with sizes
SELECT pc_index.relname AS index_name, pg_size_pretty(pg_total_relation_size(pc_index.oid))
FROM pg_class pc_table
JOIN pg_index pi ON pc_table.oid = pi.indrelid
JOIN pg_class pc_index ON pc_index.oid = pi.indexrelid
WHERE pc_table.relname = 'temp_wos_reference'
  --'derwent_familyid'
ORDER BY pc_index.relname;

-- Generate tablespace creation DDL: names and locations only (*no owners or options*)
SELECT
  pt.spcname,
  format('CREATE TABLESPACE %I LOCATION %L;', pt.spcname, CASE spcname
                                                            WHEN 'pg_default' THEN ps.setting || '/base'
                                                            WHEN 'pg_global' THEN ps.setting || '/global'
                                                            ELSE pg_tablespace_location(pt.oid)
                                                          END) AS ddl,
  pt.oid AS tablespace_oid
FROM pg_tablespace pt, pg_settings ps
WHERE ps.name = 'data_directory' AND pt.spcname NOT LIKE 'pg_%'
ORDER BY pt.spcname;

-- region Create a tablespace
-- Pre-requisite: > sudo -u postgres mkdir -p {dir}
CREATE TABLESPACE :tbs LOCATION :'absolute_dir';
-- endregion

-- region Rename a tablespace
ALTER TABLESPACE :tbs RENAME TO :to_tbs;
-- endregion

-- region Drop a tablespace
DROP TABLESPACE :tbs;
-- endregion

-- region Move objects to a tablespace
-- 1.7 GB
-- 17s for a Premium to Premium storage move
ALTER TABLE :table SET TABLESPACE :tbs;

-- 2.6 GB
-- 23-42s for a Premium to Premium storage move
ALTER INDEX :index SET TABLESPACE :tbs;
-- endregion
