#!/usr/bin/env bash
if [[ $1 == "-h" || $# -lt 3 ]]; then
  cat <<'HEREDOC'
NAME

  neo4j_bulk_import.sh -- loads CSVs in bulk to Neo4j and optionally calculate metrics

SYNOPSIS

  neo4j_bulk_import.sh [-m] nodes_file edges_file current_user_password [DB_name_prefix]
  neo4j_bulk_import.sh -h: display this help

DESCRIPTION
  Bulk imports to a new `{DB_name_prefix-}v{file_timestamp}` DB.
  Spaces are replaced by underscores in the `DB_name_prefix`.
  Updates Neo4j config file and restarts Neo4j.

  The following options are available:

  -m  Calculate metrics: PageRank, Betweenness Centrality, Closeness Centrality

ENVIRONMENT

  Current user must be a sudoer.

HEREDOC
  exit 1
fi

set -e
set -o pipefail


# Get a script directory, same as by $(dirname $0)
readonly SCRIPT_DIR=${0%/*}
readonly ABSOLUTE_SCRIPT_DIR=$(cd "${SCRIPT_DIR}" && pwd)

while (( $# > 0 )); do
  case "$1" in
    -m)
      readonly CALC_METRICS=true
    ;;
    *)
      break
  esac
  shift
done

readonly NODES_FILE="$1"
readonly EDGES_FILE="$2"
if [[ $4 ]]; then
  readonly DB_PREFIX="${4// /_}-"
fi

echo -e "\n## Running under ${USER}@${HOSTNAME} at ${PWD} ##\n"

if ! command -v cypher-shell >/dev/null; then
  echo "Please install Neo4j"
  exit 1
fi

# region Generate a unique db_name
#name_with_ext=${NODES_FILE##*/}
#if [[ "${name_with_ext}" != *.* ]]; then
#  name_with_ext=${name_with_ext}.
#fi

#name=${name_with_ext%.*}
file_date1=$(date -r "${NODES_FILE}" +%F-%H-%M-%S)
file_date2=$(date -r "${EDGES_FILE}" +%F-%H-%M-%S)
if [[ ${file_date1} > ${file_date2} ]]; then
  db_ver="${file_date1}"
else
  db_ver="${file_date2}"
fi
db_name="${DB_PREFIX}v${db_ver}.db"
# endregion

# The current directory must be writeable for the neo4j user. Otherwise, it'd fail with the
# `java.io.FileNotFoundException: import.report (Permission denied)` error
echo "$3" | sudo --stdin -u neo4j bash -c "set -xe
  echo 'Loading data into ${db_name} ...'
  neo4j-admin import --nodes:Publication '${NODES_FILE}' --relationships:CITES '${EDGES_FILE}' --database='${db_name}'"

"${ABSOLUTE_SCRIPT_DIR}/neo4j_switch_db.sh" "${db_name}" "$3"

echo "Calculating metrics and indexing ..."
if [[ $CALC_METRICS == true ]]; then
  parallel --halt soon,fail=1 --verbose --line-buffer --tagstring '|job#{#} s#{%}|' --pipe cypher-shell ::: \
    "// Calculate and store PageRank
    CALL algo.pageRank()
    YIELD nodes, iterations, loadMillis, computeMillis, writeMillis, dampingFactor, write, writeProperty;" \
    "// Calculate and store Betweenness Centrality
    CALL algo.betweenness(null, null, {writeProperty: 'betweenness'})
    YIELD nodes, minCentrality, maxCentrality, sumCentrality, loadMillis, computeMillis, writeMillis;" \
    "// Calculate and store Closeness Centrality
    CALL algo.closeness(null, null, {writeProperty: 'closeness'})
    YIELD nodes, loadMillis, computeMillis, writeMillis;" \
    "CREATE INDEX ON :Publication(node_id);"

  cypher-shell <<'HEREDOC'
    // PageRank statistics
    MATCH (n)
    RETURN apoc.agg.statistics(n.pagerank);
HEREDOC
else
  cypher-shell <<HEREDOC
    CREATE INDEX ON :Publication(node_id);
HEREDOC
fi

#cypher-shell <<'HEREDOC'
#CREATE INDEX ON :Publication(node_id);
#
#// Calculate and store PageRank
#CALL algo.pageRank()
#YIELD nodes, iterations, loadMillis, computeMillis, writeMillis, dampingFactor, write, writeProperty;
#
#// Calculate and store Betweenness Centrality
#CALL algo.betweenness(null, null, {writeProperty: 'betweenness'})
#YIELD nodes, minCentrality, maxCentrality, sumCentrality, loadMillis, computeMillis, writeMillis;
#
#// Calculate and store Closeness Centrality
#CALL algo.closeness(null, null, {writeProperty: 'closeness'})
#YIELD nodes, loadMillis, computeMillis, writeMillis;
#
#// PageRank statistics
#MATCH (n)
#RETURN apoc.agg.statistics(n.pagerank);
#HEREDOC