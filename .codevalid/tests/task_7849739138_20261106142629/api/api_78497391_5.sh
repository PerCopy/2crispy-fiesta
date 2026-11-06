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

check_no_password() {
  local label="$1" body="$2"
  if printf '%s' "$body" | grep -qF -- "$PASSWORD"; then cv_fail "expected $label response not to contain the password got it in body" $LINENO; fi
  local keys
  keys=$(printf '%s' "$body" | jq -r '[paths(scalars) | map(tostring) | join(".")] | map(select(test("password";"i"))) | join(",")' 2>/dev/null || true)
  [ -z "$keys" ] || cv_fail "expected no password fields in $label response got $keys" $LINENO
  if printf '%s' "$body" | grep -qE '\$2[aby]\$[0-9]{2}\$'; then cv_fail "expected no password hash in $label response got a bcrypt hash" $LINENO; fi
}

# Given
cv_step Given "a customer is registered (registration response checked too)" $LINENO
register_user
REG_BODY="$CV_HTTP_BODY"

# When
cv_step When "the customer signs in" $LINENO
cv_http POST /auth/login "$(jq -nc --arg e "$EMAIL" --arg p "$PASSWORD" '{email:$e,password:$p}')"
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 from sign-in got $CV_HTTP_STATUS" $LINENO
LOGIN_BODY="$CV_HTTP_BODY"

# Then
cv_step Then "no sign-in or account response contains the password or its hash" $LINENO
printf '%s' "$LOGIN_BODY" | jq -e '.user.email' >/dev/null || cv_fail "expected account info in sign-in response got none" $LINENO
check_no_password "register" "$REG_BODY"
check_no_password "sign-in" "$LOGIN_BODY"

# Cleanup
cv_step Cleanup "nothing to remove: the store is in-memory and has no delete endpoint" $LINENO
echo "CODEVALID_TEST_ASSERTION_OK:api_78497391_5"
