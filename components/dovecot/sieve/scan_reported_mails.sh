#!/usr/bin/env bash
# Author: Zhang Huangbin <zhb@iredmail.org>
# Purpose: Copy spam/ham to another directory and call sa-learn to learn.
#
# #
# This file is managed by iRedMail Team <support@iredmail.org> with Ansible,
# please do __NOT__ modify it manually.
#

# Paths to find program.
export PATH="/bin:/usr/bin:/usr/local/bin:$PATH"

export OWNER="vmail"
export GROUP="vmail"

# The Amavisd daemon user.
# Note: on OpenBSD, it's "_vscan". On FreeBSD, it's "vscan".
export AMAVISD_USER='amavis'

# Kernel name, in upper cases.
export KERNEL_NAME="$(uname -s | tr '[a-z]' '[A-Z]')"

# A temporary lock file. should be removed after successfully examed messages.
export LOCK_FILE='/tmp/scan_reported_mails.lock'

# Logging to syslog with 'logger' command.
export LOG='logger -p local5.info -t scan_reported_mails'

# `sa-learn` command, with optional arguments.
export SA_LEARN="sa-learn -u ${AMAVISD_USER}"

# Spool directory.
# Must be owned by vmail:vmail.
export SPOOL_DIR='/var/vmail/imapsieve_copy/localhost'

# Directories which store spam and ham emails.
# These 2 should be created while setup Dovecot antispam plugin.
export SPOOL_SPAM_DIR="${SPOOL_DIR}/spam"
export SPOOL_HAM_DIR="${SPOOL_DIR}/ham"

# Directory used to store emails we're going to process.
# We will copy new spam/ham messages to these directories, scan them, then
# remove them.
export SPOOL_LEARN_SPAM_DIR="${SPOOL_DIR}/processing/spam"
export SPOOL_LEARN_HAM_DIR="${SPOOL_DIR}/processing/ham"

if [ -e ${LOCK_FILE} ]; then
    find $(dirname ${LOCK_FILE}) -maxdepth 1 -ctime 1 "$(basename ${LOCK_FILE})" >/dev/null 2>&1
    if [ X"$?" == X'0' ]; then
        rm -f ${LOCK_FILE} >/dev/null 2>&1
    else
        ${LOG} "Lock file exists (${LOCK_FILE}), abort."
        exit
    fi
fi

for dir in "${SPOOL_DIR}" "${SPOOL_LEARN_SPAM_DIR}" "${SPOOL_LEARN_HAM_DIR}"; do
    if [[ ! -d ${dir} ]]; then
        mkdir -p ${dir}
    fi

    chown ${OWNER}:${GROUP} ${dir}
    chmod 0700 ${dir}
done

# If there're a lot files, direct `mv` command may fail with error like
# `argument list too long`, so we need `find` in this case.
if [[ X"${KERNEL_NAME}" == X'OPENBSD' ]]; then
    [[ -d ${SPOOL_SPAM_DIR} ]] && find ${SPOOL_SPAM_DIR} -name '*.eml' -exec mv {} ${SPOOL_LEARN_SPAM_DIR}/ \;
    [[ -d ${SPOOL_HAM_DIR} ]]  && find ${SPOOL_HAM_DIR}  -name '*.eml' -exec mv {} ${SPOOL_LEARN_HAM_DIR}/  \;
else
    [[ -d ${SPOOL_SPAM_DIR} ]] && find ${SPOOL_SPAM_DIR} -name '*.eml' -exec mv -t ${SPOOL_LEARN_SPAM_DIR}/ {} +
    [[ -d ${SPOOL_HAM_DIR} ]]  && find ${SPOOL_HAM_DIR}  -name '*.eml' -exec mv -t ${SPOOL_LEARN_HAM_DIR}/  {} +
fi

# Try to delete empty directory, if failed, that means we have some messages to
# scan.
rmdir ${SPOOL_LEARN_SPAM_DIR} &>/dev/null
if [[ X"$?" != X'0' ]]; then
    output="$(${SA_LEARN} --spam ${SPOOL_LEARN_SPAM_DIR})"
    rm -rf ${SPOOL_LEARN_SPAM_DIR} &>/dev/null
    ${LOG} '[SPAM]' ${output}
fi

rmdir ${SPOOL_LEARN_HAM_DIR} &>/dev/null
if [[ X"$?" != X'0' ]]; then
    output="$(${SA_LEARN} --ham ${SPOOL_LEARN_HAM_DIR})"
    rm -rf ${SPOOL_LEARN_HAM_DIR} &>/dev/null
    ${LOG} '[CLEAN]' ${output}
fi

rm -f ${LOCK_FILE} &>/dev/null
