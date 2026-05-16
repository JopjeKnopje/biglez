#!/bin/sh
restic backup ${BACKUP_FILE_PATH} -v && curl ${HEALTHCHECK_ENDPOINT}
