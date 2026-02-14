#!/bin/bash
source /opt/buildpiper/shell-functions/file-functions.sh
source /opt/buildpiper/shell-functions/log-functions.sh
source /opt/buildpiper/shell-functions/functions.sh
source ./git_build_login.sh
source ./git_deploy_login.sh

if [ "$DEBUG" = true ]; then
  set -x
fi
TASK_STATUS=0

CODEBASE_LOCATION="${WORKSPACE}"/"${CODEBASE_DIR}"
logInfoMessage "I'll do processing at [$CODEBASE_LOCATION]"
sleep  $SLEEP_DURATION
cd  "${CODEBASE_LOCATION}"

case "$ACTION" in
  build)
    logInfoMessage "Selected action: $ACTION"
    logInfoMessage "login to SCM"
    build_login_scm
    ;;
  deploy)
    logInfoMessage "Selected action: $ACTION"
    logInfoMessage "login to SCM"
    deploy_login_scm
    ;;
  *)
    logErrorMessage "Usage: ACTION must be {build|deploy}"
    exit 1
    ;;
esac


# Getting the variable values
TARGET_URL="$DNS_URL/logs?global_task_id=$GLOBAL_TASK_ID"
REPO_NAME=$(jq -r '.environment_variables.CODEBASE_DIR' /bp/execution_dir/$GLOBAL_TASK_ID/cloning_repository_output.json)
SOURCE_BRANCH="${BRANCH}"
DEST_BRANCH="${DEST_BRANCH}"
PR_TITLE="CI: Merge release $SOURCE_BRANCH into $DEST_BRANCH from BUILDPIPER"
PR_DESC="Automated PR from pipeline"

# reviewers as comma-separated usernames
REVIEWERS="${USERNAME}"

# Print the variables
logInfoMessage "REPO_OWNER: ${SCM_USERNAME}"
logInfoMessage "SCM Cred Name: $NAME"
logInfoMessage "SCM Project  Name: $SCM_PROJECT"
logInfoMessage "Repo: https://$SCM_URL"
logInfoMessage "Branch: $BRANCH"
logInfoMessage "Source Branch: $SOURCE_BRANCH"
logInfoMessage "Destination Branch: $DEST_BRANCH"
logInfoMessage "REPO_NAME: ${REPO_NAME}"
logInfoMessage "Reviewers Name: ${REVIEWERS}"


# Convert reviewers to JSON array
REVIEWER_JSON=""
IFS=',' read -ra USERS <<< "$REVIEWERS"
for u in "${USERS[@]}"; do
  REVIEWER_JSON+="{\"username\":\"$u\"},"
done
REVIEWER_JSON="[${REVIEWER_JSON%,}]"

detect_scm() {
  if [[ "$SCM_URL" == *"github.com"* ]]; then
    SCM_TYPE="github"
  elif [[ "$SCM_URL" == *"bitbucket.org"* ]]; then
    SCM_TYPE="bitbucket"
  else
    logErrorMessage "Unable to detect SCM from SCM_URL=$SCM_URL"
    exit 1
  fi
  logInfoMessage "Detected SCM: $SCM_TYPE"
}

detect_scm

if [ "$SCM_TYPE" = "github" ]; then 
  logInfoMessage "Creating pull request in GitHub from $SOURCE_BRANCH to $DEST_BRANCH"
  logWarningMessage "GitHub PR creation is currently under development."
  exit 1

  #PR_ID=$(echo "$RESPONSE" | jq -r '.number // empty')


elif [ "$SCM_TYPE" = "bitbucket" ]; then
logInfoMessage "Creating pull request in Bitbucket from $SOURCE_BRANCH to $DEST_BRANCH"
RESPONSE=$(curl -s -X POST -u "${SCM_USERNAME}:${SCM_PASSWORD}" \
https://api.bitbucket.org/2.0/repositories/$SCM_PROJECT/$REPO_NAME/pullrequests \
-H "Content-Type: application/json" \
-d "{
  \"title\": \"$PR_TITLE\",
  \"description\": \"$PR_DESC\n\nBUILDPIPER Logs: $TARGET_URL\",
  \"source\": {\"branch\": {\"name\": \"$SOURCE_BRANCH\"}},
  \"destination\": {\"branch\": {\"name\": \"$DEST_BRANCH\"}},
  \"reviewers\": $REVIEWER_JSON
}")

PR_ID=$(echo "$RESPONSE" | jq -r '.id // empty')

fi

if [[ -n "$PR_ID" ]]; then
  logInfoMessage "Pull Request created successfully (PR ID: $PR_ID)"
else
  logErrorMessage "Failed to create Pull Request"
  logErrorMessage "$RESPONSE"
  exit 1
fi


saveTaskStatus ${TASK_STATUS} ${ACTIVITY_SUB_TASK_CODE}
