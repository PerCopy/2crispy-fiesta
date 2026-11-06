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
cv_step Given "a customer is registered with email and password" $LINENO
register_user

# When
cv_step When "sign-in is attempted with an empty password and then with an empty email" $LINENO
cv_http POST /auth/login "$(jq -nc --arg e "$EMAIL" '{email:$e,password:""}')"
S1="$CV_HTTP_STATUS"; B1="$CV_HTTP_BODY"
cv_http POST /auth/login "$(jq -nc --arg p "$PASSWORD" '{email:"",password:$p}')"
S2="$CV_HTTP_STATUS"; B2="$CV_HTTP_BODY"

# Then
cv_step Then "both sign-ins are refused and no token is issued" $LINENO
case "$S1" in 4*) ;; *) cv_fail "expected refusal (4xx) for empty password got $S1" $LINENO ;; esac
case "$S2" in 4*) ;; *) cv_fail "expected refusal (4xx) for empty email got $S2" $LINENO ;; esac
T1=$(printf '%s' "$B1" | jq -r '.token // empty' 2>/dev/null || true)
T2=$(printf '%s' "$B2" | jq -r '.token // empty' 2>/dev/null || true)
[ -z "$T1" ] || cv_fail "expected no token for empty password got one" $LINENO
[ -z "$T2" ] || cv_fail "expected no token for empty email got one" $LINENO

# Cleanup
cv_step Cleanup "nothing to remove: the store is in-memory and has no delete endpoint" $LINENO
echo "CODEVALID_TEST_ASSERTION_OK:api_78497391_4"
