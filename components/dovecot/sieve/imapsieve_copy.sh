#!/usr/bin/env bash
# Author: Zhang Huangbin <zhb@iredmail.org>
# Purpose: Read full email message from stdin, and save to a local file.

# Usage: bash imapsieve_copy <email> <spam|ham> <output_base_dir>

# #
# This file is managed by iRedMail Team <support@iredmail.org> with Ansible,
# please do __NOT__ modify it manually.
#

export USER="$1"
export MSG_TYPE="$2"

export OUTPUT_BASE_DIR="/var/vmail/imapsieve_copy"
export OUTPUT_DIR="${OUTPUT_BASE_DIR}/localhost/${MSG_TYPE}"
export FILE="${OUTPUT_DIR}/${USER}-$(date +%Y%m%d%H%M%S)-${RANDOM}${RANDOM}.eml"

export OWNER="vmail"
export GROUP="vmail"

for dir in "${OUTPUT_BASE_DIR}" "${OUTPUT_DIR}"; do
    if [[ ! -d ${dir} ]]; then
        mkdir -p ${dir}
        chown ${OWNER}:${GROUP} ${dir}
        chmod 0700 ${dir}
    fi
done

cat > ${FILE} < /dev/stdin

# Logging
#export LOG='logger -p local5.info -t imapsieve_copy'
#[[ $? == 0 ]] && ${LOG} "Copied one ${MSG_TYPE} email reported by ${USER}: ${FILE}"
