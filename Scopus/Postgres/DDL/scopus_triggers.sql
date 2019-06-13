\set ECHO all
\set ON_ERROR_STOP on

-- triggers for scopus updates


CREATE OR REPLACE FUNCTION update_scp_function()
RETURNS TRIGGER AS $update_scp_trigger$
  BEGIN
    IF (tg_op = 'UPDATE') THEN
      NEW.last_updated_time := now();
    END IF;
    RETURN NEW;
  END;
  $update_scp_trigger$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION delete_scp_function()
RETURNS TRIGGER AS $delete_scp_trigger$
  BEGIN
    IF (tg_op = 'DELETE') THEN
      INSERT INTO del_scps(scp)
      VALUES (old.scp)
      ON CONFLICT (scp) DO UPDATE
      SET last_updated_time=now();
    END IF;
    RETURN NULL;
  END;
  $delete_scp_trigger$
LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS delete_scopus_publications_trigger ON scopus_publications;
CREATE TRIGGER delete_scopus_publications_trigger
  AFTER DELETE ON scopus_publications
  FOR EACH ROW EXECUTE PROCEDURE delete_scp_function();

DROP TRIGGER IF EXISTS update_scopus_abstracts_trigger ON scopus_abstracts;
CREATE TRIGGER update_scopus_abstracts_trigger
  BEFORE UPDATE ON scopus_abstracts
  FOR EACH ROW EXECUTE PROCEDURE update_scp_function();


DROP TRIGGER IF EXISTS update_scopus_keywords_trigger ON scopus_keywords;
CREATE TRIGGER update_scopus_keywords_trigger
  BEFORE UPDATE ON scopus_keywords
  FOR EACH ROW EXECUTE PROCEDURE update_scp_function();


DROP TRIGGER IF EXISTS update_scopus_titles_trigger ON scopus_titles;
CREATE TRIGGER update_scopus_titles_trigger
  BEFORE UPDATE ON scopus_titles
  FOR EACH ROW EXECUTE PROCEDURE update_scp_function();


DROP TRIGGER IF EXISTS update_scopus_publication_identifiers_trigger ON scopus_publication_identifiers;
CREATE TRIGGER update_scopus_publication_identifiers_trigger
  BEFORE UPDATE ON scopus_publication_identifiers
  FOR EACH ROW EXECUTE PROCEDURE update_scp_function();


DROP TRIGGER IF EXISTS update_scopus_chemical_groups_trigger ON scopus_chemical_groups;
CREATE TRIGGER update_scopus_chemical_groups_trigger
  BEFORE UPDATE ON scopus_chemical_groups
  FOR EACH ROW EXECUTE PROCEDURE update_scp_function();
