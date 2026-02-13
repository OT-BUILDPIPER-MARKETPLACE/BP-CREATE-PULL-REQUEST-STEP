#!/bin/bash
source /opt/buildpiper/shell-functions/file-functions.sh
source /opt/buildpiper/shell-functions/log-functions.sh
source /opt/buildpiper/shell-functions/functions.sh
source ./git_build_login_.sh
source ./git_build_login_.sh

if [ "$DEBUG" = true ]; then
  set -x
fi
TASK_STATUS=0

CODEBASE_LOCATION="${WORKSPACE}"/"${CODEBASE_DIR}"
logInfoMessage "I'll do processing at [$CODEBASE_LOCATION]"
sleep  $SLEEP_DURATION
cd  "${CODEBASE_LOCATION}"

if 

# Getting the variable values
TARGET_URL="$DNS_URL/logs?global_task_id=$GLOBAL_TASK_ID"
REPO_NAME=$(jq -r '.environment_variables.CODEBASE_DIR' /bp/execution_dir/$GLOBAL_TASK_ID/cloning_repository_output.json)
BUILD_NUMBER=$(jq -r '.build_number' /bp/data/environment_build)
SERVICE_ID=$(jq -r '.service_id' /bp/data/environment_build)


saveTaskStatus ${TASK_STATUS} ${ACTIVITY_SUB_TASK_CODE}