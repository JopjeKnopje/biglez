#!/bin/sh
curl "${HEALTHCHECK_ENDPOINT}/start"
restic backup ${BACKUP_FILE_PATH} -v && curl ${HEALTHCHECK_ENDPOINT}
