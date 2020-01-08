#!/usr/bin/env bash
if [[ $# -lt 4 || "$1" == "-h" ]]; then
  cat << 'HEREDOC'
NAME

    neo4j-export-via-map-parallel2.sh -- perform calculations via `apoc.cypher.mapParallel2()` and export CSVs

SYNOPSIS

    neo4j-export-via-map-parallel2.sh output_file JDBC_conn_string SQL Cypher_query_file [expected_rec_num] [batch_size]
    neo4j-export-via-map-parallel2.sh -h: display this help

DESCRIPTION

    Perform calculations via Cypher_query and export in batches. The batch size is 1000 records.
    Output CSV.

    The following options are available:

    output_file           `-{batch #}` suffixes are automatically added when bactehd.use `/dev/stdout` for `stdout`.
                          Note: the number of records is printed to stdout.
    JDBC_conn_string      JDBC connection string
    SQL                   SQL to retrieve input data. Input data should be ordered when batched.
    Cypher_query_file     file containing Cypher query to execute which uses the `row` resultset returned by
                          `CALL apoc.load.jdbc(db, {SQL_query}) YIELD row`.
    expected_rec_number   If supplied, the number of output records is checked to be = expected
    batch_size            If `expected_rec_number` > `batch_size`, output is batched and
                          ` LIMIT {batch_size} OFFSET {batch_offset}` clauses are added to `SQL_query`.
                          WARNING: `apoc.cypher.mapParallel2()` is unstable as of v3.5.0.6 and may fail on
                          medium-to-large batches. batch_size = 50 is recommended to start with.

ENVIRONMENT

    Neo4j DB should be pre-loaded with data and indexed as needed.

EXIT STATUS

    The neo4j-export-via-map-parallel2 utility exits with one of the following values:

    0   Success
    1   The actual number of exported records is not the expected one
    2   Cypher execution failed

EXAMPLES

    To find all occurrences of the word `patricia' in a file:

        $ neo4j-export-via-map-parallel2.sh jaccard_co_citation_conditional_star_index.csv \
            "jdbc:postgresql://ernie2/ernie?user=ernie_admin&password=${ERNIE_ADMIN_POSTGRES}" \
            'SELECT 17538003 AS cited_1, 18983824 AS cited_2' \
            jaccard_co_citation_conditional_star_index.cypher

        jaccard_co_citation_conditional_star_index.cypher:
```
WITH collect({x_scp: row.cited_1, y_scp: row.cited_2}) AS pairs
CALL apoc.cypher.mapParallel2('
  MATCH (x:Publication {node_id: _.x_scp})<--(Nxy)-->(y:Publication {node_id: _.y_scp})
  WITH count(Nxy) AS intersect_size, min(Nxy.pub_year) AS first_co_citation_year, _.x_scp AS x_scp, _.y_scp AS y_scp
  OPTIONAL MATCH (x:Publication {node_id: x_scp})<--(Nx:Publication)
    WHERE Nx.node_id <> y_scp AND Nx.pub_year <= first_co_citation_year
  WITH collect(Nx) AS nx_list, intersect_size, first_co_citation_year, x_scp, y_scp
  OPTIONAL MATCH (y:Publication {node_id: y_scp})<--(Ny:Publication)
    WHERE Ny.node_id <> x_scp AND Ny.pub_year <= first_co_citation_year
  WITH nx_list + collect(Ny) AS union_list, intersect_size, x_scp, y_scp
  UNWIND union_list AS union_node
  RETURN x_scp, y_scp, toFloat(intersect_size) / (count(DISTINCT union_node) + 2) AS jaccard_index', {}, pairs, 16)
YIELD value
RETURN value.x_scp AS cited_1, value.y_scp AS cited_2, value.jaccard_index AS jaccard_co_citation_conditional_index;
```

AUTHOR(S)

    Written by Dmitriy "DK" Korobskiy.
HEREDOC
  exit 1
fi

set -e
set -o pipefail

readonly OUTPUT="$1"
readonly JDBC_CONN_STRING="$2"
readonly INPUT_DATA_SQL_QUERY="$3"
readonly CYPHER_QUERY_FILE="$4"
echo "Calculating via $CYPHER_QUERY_FILE"

if [[ $5 ]]; then
  declare -ri EXPECTED_NUM_RECORDS=$5
  shift
fi
if [[ $5 ]]; then
  declare -ri BATCH_SIZE=$5
  declare -i expected_batches=$(( EXPECTED_NUM_RECORDS / BATCH_SIZE ))
  if (( EXPECTED_NUM_RECORDS % BATCH_SIZE > 0 )); then
    (( ++expected_batches ))
  fi
fi

# Get a script directory, same as by $(dirname $0)
#readonly SCRIPT_DIR=${0%/*}
#readonly ABSOLUTE_SCRIPT_DIR=$(cd "${SCRIPT_DIR}" && pwd)
#
#readonly WORK_DIR=${1:-${ABSOLUTE_SCRIPT_DIR}/build} # $1 with the default
#if [[ ! -d "${WORK_DIR}" ]]; then
#  mkdir "${WORK_DIR}"
#  chmod g+w "${WORK_DIR}"
#fi
#cd "${WORK_DIR}"
#echo -e "\n## Running under ${USER}@${HOSTNAME} in ${PWD} ##\n"

declare -i processed_records=0 batch_num=1
export sql_query="'${INPUT_DATA_SQL_QUERY}'"
output_file="$OUTPUT"
while (( processed_records < EXPECTED_NUM_RECORDS )); do
  if [[ $BATCH_SIZE ]]; then
    if (( batch_num > 1 )); then
      output_file="/tmp/batch.csv"
    fi
    export sql_query="'${INPUT_DATA_SQL_QUERY} LIMIT $BATCH_SIZE OFFSET $processed_records'"
    declare -i expected_batch_records=$(( EXPECTED_NUM_RECORDS - processed_records ))
    if (( expected_batch_records > BATCH_SIZE )); then
      (( expected_batch_records = BATCH_SIZE ))
    fi
  else
    if [[ $EXPECTED_NUM_RECORDS ]]; then
      declare -i expected_batch_records=$EXPECTED_NUM_RECORDS
    fi
  fi

  # shellcheck disable=SC2016 # false alarm
  # cypher-shell :param does not support a multi-line string, hence de-tokenizing SQL query using `envsubst`.
  cypher_query="CALL apoc.export.csv.query(\"$(envsubst '\$sql_query' <"$CYPHER_QUERY_FILE")\", '$output_file', {});"

  if ! cypher-shell << HEREDOC
:param JDBC_conn_string => '$JDBC_CONN_STRING'

$cypher_query
HEREDOC
  then
    cat << HEREDOC
Failed Cypher query:
=====
$cypher_query
=====
HEREDOC
    exit 2
  fi

  declare -i num_of_records
  # Suppress printing a file name
  num_of_records=$(wc --lines <"$output_file")
  if (( num_of_records > 0 )); then
    # Exclude CSV header
    (( --num_of_records )) || :
  fi
  if [[ $BATCH_SIZE ]]; then
    echo -n "Batch #${batch_num}/${expected_batches}: "
    if (( batch_num > 1 )); then
      tail -n +2 <"$output_file" >> $"OUTPUT"
    fi
  fi
  echo "$num_of_records records exported"

  if [[ $expected_batch_records && $num_of_records -ne $expected_batch_records ]]; then
    # False if EXPECTED_NUM_RECORDS is not defined
    echo "Error! The actual exported number of records is not the expected number ($expected_batch_records)." 1>&2
    exit 1
  fi
  (( processed_records += num_of_records ))
  (( ++batch_num ))
done

exit 0
