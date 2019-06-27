#!/usr/bin/env bash
if [[ $1 == "-h" ]]; then
  cat <<'HEREDOC'
NAME

  update.sh -- update Scopus data in a PostgreSQL database with zipped (*.zip) Scopus XMLs delivered by the provider
  Note that clean mode is NOT available with this script.

SYNOPSIS

  update.sh [-s subset_SP] -d data_directory
  update.sh -h: display this help

DESCRIPTION

  Process specified zip files in the target directory

  TODO:
    1) Copy files from some secondary storing location and then proceed to work on them.

  The following options are available:

    -s subset_SP: parse a subset of data via the specified subset parsing Stored Procedure (SP)

  To stop process gracefully after the current ZIP is processed, create a `{working_dir}/.stop` signal file.
  This file is automatically removed

HEREDOC
  exit 1
fi

set -e
set -o pipefail
#set -x

readonly STOP_FILE=".stop"
# Get a script directory, same as by $(dirname $0)
readonly SCRIPT_DIR=${0%/*}
readonly ABSOLUTE_SCRIPT_DIR=$(cd "${SCRIPT_DIR}" && pwd)
readonly FAILED_FILES_DIR=../failed
readonly PROCESSED_LOG=/erniedev_data2/Scopus_updates/processed.log

while (( $# > 0 )); do
  case "$1" in
    -d)
      shift
      readonly ZIP_DIR="$1"
      ;;
    -s)
      shift
      readonly SUBSET_OPTION="-s $1"
      ;;
    *)
      break
  esac
  shift
done

echo -e "\n## Running under ${USER}@${HOSTNAME} in ${PWD} ##\n"
echo -e "Zip files to process:\n$(ls ${ZIP_DIR}/*.zip)"

rm -f eta.log
declare -i files=$(cd $ZIP_DIR ; ls *ANI-ITEM-full-format-xml.zip| wc -l) i=0 start_time file_start_time file_stop_time delta delta_s delta_m della_h \
    elapsed=0 est_total eta

for ZIP_DATA in $(ls ${ZIP_DIR}/*ANI-ITEM-full-format-xml.zip); do
  file_start_time=$(date '+%s')
  (( i == 0 )) && start_time=${file_start_time}
  echo -e "\n## Update Zip file #$((++i)) out of ${files} update zip files ##"
  echo "Unzipping ${ZIP_DATA} file into a working directory ..."
  DATA_DIR="${ZIP_DATA%.zip}"
  unzip -u -q "${ZIP_DATA}" -d "${DATA_DIR}"

  echo "Processing ${DATA_DIR} directory ..."
  if ! "${ABSOLUTE_SCRIPT_DIR}/process_update_directory.sh" -p "${PROCESSED_LOG}" -f "${FAILED_FILES_DIR}" ${SUBSET_OPTION} "${DATA_DIR}"; then
    failures_occurred="true"
  fi

  #TODO: uncomment and add this in once we have an automated process set up
  #echo "Removing directory ${ZIP_DATA%.zip}"
  #rm -rf "${ZIP_DATA%.zip}"

  file_stop_time=$(date '+%s')

  ((delta=file_stop_time - file_start_time + 1)) || :
  ((delta_s=delta % 60)) || :
  ((delta_m=(delta / 60) % 60)) || :
  ((della_h=delta / 3600)) || :
  printf "\n$(TZ=America/New_York date) Done with ${ZIP_DATA} data file in %dh:%02dm:%02ds\n" ${della_h} \
         ${delta_m} ${delta_s} | tee -a eta.log
  if [[ -f "${ZIP_DATA}/${STOP_FILE}" ]]; then
    echo "Found the stop signal file. Gracefully stopping the update..."
    rm -f "${ZIP_DATA}/${STOP_FILE}"
    break
  fi

  ((elapsed=elapsed + delta))
  ((est_total=elapsed * files / i)) || :
  ((eta=start_time + est_total))
  echo "ETA for updates after ${ZIP_DATA} data file: $(TZ=America/New_York date --date=@${eta})" | tee -a eta.log
done

echo "Main update process completed. Now processing delete files..."
declare -i num_deletes=$(cd $ZIP_DIR ; ls *ANI-ITEM-delete.zip| wc -l) i=0
for ZIP_DATA in $(cd $ZIP_DIR ; ls *ANI-ITEM-delete.zip); do
  if grep -q "^${ZIP_DATA}$" "${PROCESSED_LOG}"; then
    echo "Skipping file ${ZIP_DATA} ( .zip file #$((++i)) out of ${num_deletes} ). It is already marked as completed."
  else
    echo -e "\nProcessing delete file ${ZIP_DATA} ( .zip file #$((++i)) out of ${num_deletes} )..."
    unzip ${ZIP_DIR}/${ZIP_DATA}
    psql -f process_deletes.sql
    rm delete.txt
    echo "${ZIP_DATA}" >> ${PROCESSED_LOG}
    echo "Delete file ${ZIP_DATA} processed."
  fi
done

[[ "${failures_occurred}" == "true" ]] && exit 1
exit 0