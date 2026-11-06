#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
EMAIL="cust_${SUFFIX}@example.com"
PASSWORD="Sup3rSecret_${SUFFIX}"
register_user() {
  cv_prereq "register customer $EMAIL" $LINENO
  cv_http POST /auth/register "$(jq -nc --arg e "$EMAIL" --arg p "$PASSWORD" --arg n "Customer $SUFFIX" '{email:$e,password:$p,name:$n}')"
  [ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected 201 from register got $CV_HTTP_STATUS" $LINENO
}

# Given
cv_step Given "an email address that no account was registered with" $LINENO
UNKNOWN="nobody_${SUFFIX}@example.com"
cv_prereq "unregistered email $UNKNOWN (unique suffix, never registered)" $LINENO

# When
cv_step When "sign-in is attempted with the unregistered email" $LINENO
cv_http POST /auth/login "$(jq -nc --arg e "$UNKNOWN" --arg p "$PASSWORD" '{email:$e,password:$p}')"
STATUS="$CV_HTTP_STATUS"; BODY="$CV_HTTP_BODY"

# Then
cv_step Then "the sign-in is refused and no token is issued" $LINENO
case "$STATUS" in 4*) ;; *) cv_fail "expected sign-in refusal (4xx) got $STATUS" $LINENO ;; esac
TOKEN=$(printf '%s' "$BODY" | jq -r '.token // empty' 2>/dev/null || true)
[ -z "$TOKEN" ] || cv_fail "expected no token for unregistered email got one" $LINENO

# Cleanup
cv_step Cleanup "nothing to remove: no data was created" $LINENO
echo "CODEVALID_TEST_ASSERTION_OK:api_78497391_3"
