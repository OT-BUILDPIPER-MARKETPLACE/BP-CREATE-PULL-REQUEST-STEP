#!/bin/bash

source /opt/buildpiper/shell-functions/file-functions.sh
source /opt/buildpiper/shell-functions/log-functions.sh
source /opt/buildpiper/shell-functions/functions.sh
source ./git_bulid_login.sh
source ./git_deploy_login.sh

# ---------------------------------------------------------------
# NOTE: ACTIVITY_SUB_TASK_CODE is managed by the BuildPiper
#       environment. Do NOT override it here to ensure events
#       appear correctly in the UI.
# ---------------------------------------------------------------

if [ "$DEBUG" = true ]; then
    set -x
fi

# ---------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------
WORKSPACE="${WORKSPACE:-/bp/workspace}"
CODEBASE_LOCATION="${WORKSPACE}/${CODEBASE_DIR}"
TASK_STATUS=0

# ---------------------------------------------------------------
# 1. Initialization
# ---------------------------------------------------------------
logInfoMessage "> Starting step: create_pull_request"
logInfoMessage "> Codebase location: ${CODEBASE_LOCATION}"
logInfoMessage "> Action: ${ACTION}"

add_event "INITIALIZATION" "Successful" \
    "Create Pull Request step initialized" \
    "Action: ${ACTION} | Codebase: ${CODEBASE_DIR}"

if [ -n "$SLEEP_DURATION" ] && [ "$SLEEP_DURATION" -gt 0 ] 2>/dev/null; then
    logInfoMessage "> Sleeping for ${SLEEP_DURATION} second(s)..."
    sleep "$SLEEP_DURATION"
fi

# ---------------------------------------------------------------
# 2. Input Validation
# ---------------------------------------------------------------
logInfoMessage "> Validating inputs..."

VALIDATION_ERRORS=""
[[ -z "$WORKSPACE" ]]     && VALIDATION_ERRORS+="WORKSPACE is not set. "
[[ -z "$CODEBASE_DIR" ]]  && VALIDATION_ERRORS+="CODEBASE_DIR is not set. "
[[ -z "$ACTION" ]]        && VALIDATION_ERRORS+="ACTION is not set. "
[[ -z "$BRANCH" ]]        && VALIDATION_ERRORS+="BRANCH (source branch) is not set. "
[[ -z "$DEST_BRANCH" ]]   && VALIDATION_ERRORS+="DEST_BRANCH is not set. "

if [[ -n "$VALIDATION_ERRORS" ]]; then
    logErrorMessage "> Missing required variables: ${VALIDATION_ERRORS}"
    add_event "INPUT_VALIDATION" "Failed" \
        "Required environment variables are missing" \
        "${VALIDATION_ERRORS}"
    saveTaskStatus 1 "${ACTIVITY_SUB_TASK_CODE}"
    exit 1
fi

add_event "INPUT_VALIDATION" "Successful" \
    "All required inputs validated" \
    "Action: ${ACTION} | Source: ${BRANCH} → Dest: ${DEST_BRANCH}"

# ---------------------------------------------------------------
# 3. Workspace Navigation
# ---------------------------------------------------------------
logInfoMessage "> Navigating to codebase directory..."

cd "${CODEBASE_LOCATION}" || {
    logErrorMessage "> Failed to navigate to codebase directory: ${CODEBASE_LOCATION}"
    add_event "WORKSPACE_NAVIGATION" "Failed" \
        "Cannot change to codebase directory" \
        "Path: ${CODEBASE_LOCATION} | Verify WORKSPACE and CODEBASE_DIR"
    saveTaskStatus 1 "${ACTIVITY_SUB_TASK_CODE}"
    exit 1
}

logInfoMessage "> Successfully navigated to: ${CODEBASE_LOCATION}"
add_event "WORKSPACE_NAVIGATION" "Successful" \
    "Navigated to codebase directory" \
    "Path: ${CODEBASE_LOCATION}"

# ---------------------------------------------------------------
# 4. SCM Login
# ---------------------------------------------------------------
logInfoMessage "> Logging into SCM (action: ${ACTION})..."

case "$ACTION" in
    build)
        if ! build_login_scm; then
            logErrorMessage "> Failed to login to SCM (action: build)"
            add_event "SCM_LOGIN" "Failed" \
                "Failed to login to SCM" \
                "Action: build | Check SCM credentials"
            saveTaskStatus 1 "${ACTIVITY_SUB_TASK_CODE}"
            exit 1
        fi
        add_event "SCM_LOGIN" "Successful" \
            "Successfully logged into SCM" \
            "Action: build"
        ;;
    deploy)
        if ! deploy_login_scm; then
            logErrorMessage "> Failed to login to SCM (action: deploy)"
            add_event "SCM_LOGIN" "Failed" \
                "Failed to login to SCM" \
                "Action: deploy | Check SCM credentials"
            saveTaskStatus 1 "${ACTIVITY_SUB_TASK_CODE}"
            exit 1
        fi
        add_event "SCM_LOGIN" "Successful" \
            "Successfully logged into SCM" \
            "Action: deploy"
        ;;
    *)
        logErrorMessage "> Invalid ACTION: '${ACTION}' — allowed: build, deploy"
        add_event "SCM_LOGIN" "Failed" \
            "Invalid ACTION provided" \
            "ACTION: ${ACTION} | Allowed values: build | deploy"
        saveTaskStatus 1 "${ACTIVITY_SUB_TASK_CODE}"
        exit 1
        ;;
esac

# ---------------------------------------------------------------
# 5. Variable Resolution
# ---------------------------------------------------------------
logInfoMessage "> Resolving PR variables..."

TARGET_URL="${DNS_URL}/logs?global_task_id=${GLOBAL_TASK_ID}"
REPO_NAME=$(jq -r '.environment_variables.CODEBASE_DIR' /bp/execution_dir/${GLOBAL_TASK_ID}/cloning_repository_output.json)
SOURCE_BRANCH="${BRANCH}"
PR_TITLE="CI: Merge release ${SOURCE_BRANCH} into ${DEST_BRANCH} from BUILDPIPER"
PR_DESC="Automated PR from pipeline"
REVIEWERS="${USERNAME}"

# Convert reviewers to JSON array
REVIEWER_JSON=""
IFS=',' read -ra USERS <<< "$REVIEWERS"
for u in "${USERS[@]}"; do
    REVIEWER_JSON+="{\"username\":\"$u\"},"
done
REVIEWER_JSON="[${REVIEWER_JSON%,}]"

# ---------------------------------------------------------------
# 6. SCM Detection
# ---------------------------------------------------------------
logInfoMessage "> Detecting SCM provider from URL: ${SCM_URL}..."

if [[ "$SCM_URL" == *"github.com"* ]]; then
    SCM_TYPE="github"
elif [[ "$SCM_URL" == *"bitbucket.org"* ]]; then
    SCM_TYPE="bitbucket"
else
    logErrorMessage "> Unable to detect SCM provider from SCM_URL: ${SCM_URL}"
    add_event "SCM_DETECTION" "Failed" \
        "Unable to detect SCM provider" \
        "SCM_URL: ${SCM_URL} | Supported: github.com, bitbucket.org"
    saveTaskStatus 1 "${ACTIVITY_SUB_TASK_CODE}"
    exit 1
fi

logInfoMessage "> SCM provider detected: ${SCM_TYPE}"
add_event "SCM_DETECTION" "Successful" \
    "SCM provider detected" \
    "SCM: ${SCM_TYPE} | URL: ${SCM_URL}"

# ---------------------------------------------------------------
# 7. Execution Summary
# ---------------------------------------------------------------
echo ""
echo "> Create Pull Request Execution Summary"
printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
printf '| %-28s | %-48s |\n' "Parameter" "Value"
printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
printf '| %-28s | %-48s |\n' "SCM Provider" "${SCM_TYPE}"
printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
printf '| %-28s | %-48s |\n' "Repository" "${REPO_NAME}"
printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
printf '| %-28s | %-48s |\n' "Source Branch" "${SOURCE_BRANCH}"
printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
printf '| %-28s | %-48s |\n' "Destination Branch" "${DEST_BRANCH}"
printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
printf '| %-28s | %-48s |\n' "PR Title" "${PR_TITLE}"
printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
printf '| %-28s | %-48s |\n' "Reviewers" "${REVIEWERS}"
printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
printf '| %-28s | %-48s |\n' "Build Logs URL" "${TARGET_URL}"
printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
echo ""

# ---------------------------------------------------------------
# 8. Pull Request Creation
# ---------------------------------------------------------------
add_event "PR_CREATION_START" "Successful" \
    "Initiating Pull Request creation" \
    "Source: ${SOURCE_BRANCH} → Dest: ${DEST_BRANCH} | SCM: ${SCM_TYPE}"

if [ "$SCM_TYPE" = "github" ]; then
    # Extract owner from SCM_URL: e.g. github.com/deepakgupta97/emp_project.git → deepakgupta97
    REPO_OWNER=$(echo "$SCM_URL" | cut -d'/' -f2)
    logInfoMessage "> Creating pull request in GitHub: ${SOURCE_BRANCH} → ${DEST_BRANCH}"
    RESPONSE=$(curl -s -X POST \
        -H "Authorization: token ${SCM_PASSWORD}" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/pulls" \
        -d "{
            \"title\": \"${PR_TITLE}\",
            \"body\": \"${PR_DESC}\\n\\nBUILDPIPER Logs: ${TARGET_URL}\",
            \"head\": \"${SOURCE_BRANCH}\",
            \"base\": \"${DEST_BRANCH}\"
        }")
    PR_ID=$(echo "$RESPONSE" | jq -r '.number // empty')

elif [ "$SCM_TYPE" = "bitbucket" ]; then
    logInfoMessage "> Creating pull request in Bitbucket: ${SOURCE_BRANCH} → ${DEST_BRANCH}"
    RESPONSE=$(curl -s -X POST \
        -u "${SCM_USERNAME}:${SCM_PASSWORD}" \
        -H "Content-Type: application/json" \
        "https://api.bitbucket.org/2.0/repositories/${SCM_PROJECT}/${REPO_NAME}/pullrequests" \
        -d "{
            \"title\": \"${PR_TITLE}\",
            \"description\": \"${PR_DESC}\n\nBUILDPIPER Logs: ${TARGET_URL}\",
            \"source\": {\"branch\": {\"name\": \"${SOURCE_BRANCH}\"}},
            \"destination\": {\"branch\": {\"name\": \"${DEST_BRANCH}\"}},
            \"reviewers\": ${REVIEWER_JSON}
        }")

    PR_ID=$(echo "$RESPONSE" | jq -r '.id // empty')
fi

# ---------------------------------------------------------------
# 9. PR Result Evaluation
# ---------------------------------------------------------------
if [[ -n "$PR_ID" ]]; then
    logInfoMessage "> Pull Request created successfully — PR ID: ${PR_ID}"
    add_event "PR_CREATION_RESULT" "Successful" \
        "Pull Request created successfully" \
        "PR ID: ${PR_ID} | Source: ${SOURCE_BRANCH} → Dest: ${DEST_BRANCH} | SCM: ${SCM_TYPE}"
    saveTaskStatus 0 "${ACTIVITY_SUB_TASK_CODE}"
    exit 0
else
    logErrorMessage "> Failed to create Pull Request"
    logErrorMessage "> SCM Response: ${RESPONSE}"
    add_event "PR_CREATION_RESULT" "Failed" \
        "Failed to create Pull Request" \
        "Source: ${SOURCE_BRANCH} → Dest: ${DEST_BRANCH} | Check SCM credentials and branch names"
    saveTaskStatus 1 "${ACTIVITY_SUB_TASK_CODE}"
    exit 1
fi
