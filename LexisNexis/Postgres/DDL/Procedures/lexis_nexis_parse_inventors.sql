/*
  Author: VJ Davey
  This script is part of a set that defines several procedures for XMLTABLE based parsing of LexisNexis XML patent files.
  This section covers inventor data.
*/

\set ON_ERROR_STOP on
\set ECHO all

-- DataGrip: start execution from here
SET TIMEZONE = 'US/Eastern';
SET search_path TO public;

-- Inventors parsing
CREATE OR REPLACE PROCEDURE lexis_nexis_parse_inventors(input_xml XML) AS
$$
  BEGIN
    INSERT INTO lexis_nexis_inventors(country_code,doc_number,kind_code,inventor_sequence,
                                language,name,address_1,address_2,address_3,address_4,address_5,
                                mailcode,pobox,room,address_floor,building,street,city,county,
                                postcode,country)
    SELECT
          xmltable.country_code,
          xmltable.doc_number,
          xmltable.kind_code,
          xmltable.inventor_sequence,
          xmltable.language,
          xmltable.name,
          xmltable.address_1,
          xmltable.address_2,
          xmltable.address_3,
          xmltable.address_4,
          xmltable.address_5,
          xmltable.mailcode,
          xmltable.pobox,
          xmltable.room,
          xmltable.address_floor,
          xmltable.building,
          xmltable.street,
          xmltable.city,
          xmltable.county,
          xmltable.postcode,
          xmltable.country
     FROM
     XMLTABLE('//bibliographic-data/parties/inventors/inventor' PASSING input_xml
              COLUMNS
                --below come from higher level nodes
                country_code TEXT PATH '//bibliographic-data/publication-reference/document-id/country' NOT NULL,
                doc_number TEXT PATH '//bibliographic-data/publication-reference/document-id/doc-number' NOT NULL,
                kind_code TEXT PATH '//bibliographic-data/publication-reference/document-id/kind' NOT NULL,

                --below are attributes
                inventor_sequence INT PATH '@sequence' NOT NULL,
                language DATE PATH 'addressbook/@lang',
                --Below are sub elements
                name TEXT PATH 'addressbook/name',
                address_1 TEXT PATH 'addressbook/address/address-1',
                address_2 TEXT PATH 'addressbook/address/address-2',
                address_3 TEXT PATH 'addressbook/address/address-3',
                address_4 TEXT PATH 'addressbook/address/address-4',
                address_5 TEXT PATH 'addressbook/address/address-5',
                mailcode TEXT PATH 'addressbook/address/mailcode',
                pobox TEXT PATH 'addressbook/address/pobox',
                room TEXT PATH 'addressbook/address/room',
                address_floor TEXT PATH 'addressbook/address/address-floor',
                building TEXT PATH 'addressbook/address/building',
                street TEXT PATH 'addressbook/address/street',
                city TEXT PATH 'addressbook/address/city',
                county TEXT PATH 'addressbook/address/county',
                state TEXT PATH 'addressbook/address/state',
                postcode TEXT PATH 'addressbook/address/postcode',
                country TEXT PATH 'addressbook/address/country'
              )
    ON CONFLICT (country_code,doc_number,kind_code,inventor_sequence)
    DO NOTHING;
    --DO UPDATE SET abstract_text=excluded.abstract_text,abstract_date_changed=excluded.abstract_date_changed,
     --last_updated_time=now();
  END;
$$
LANGUAGE plpgsql;
