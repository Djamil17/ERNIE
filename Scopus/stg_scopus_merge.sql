DO
$block$
    BEGIN
        CALL stg_scopus_merge_publication_and_group();
        CALL stg_scopus_merge_source_and_conferences();
        CALL stg_scopus_merge_pub_details_subjects_and_classes();
        CALL stg_scopus_merge_authors_and_affiliations();
        CALL stg_scopus_merge_chemical_groups();
        CALL stg_scopus_merge_abstracts_and_titles();
        CALL stg_scopus_merge_keywords();
        CALL stg_scopus_merge_publication_identifiers();
        CALL stg_scopus_merge_grants();
        CALL stg_scopus_merge_references();
    END
$block$;

