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
cv_step When "the customer signs in with the registered email and password" $LINENO
cv_http POST /auth/login "$(jq -nc --arg e "$EMAIL" --arg p "$PASSWORD" '{email:$e,password:$p}')"
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 from sign-in got $CV_HTTP_STATUS" $LINENO
TOKEN=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.token // empty')
[ -n "$TOKEN" ] || cv_fail "expected a token in sign-in response got none" $LINENO
GOT_EMAIL=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.user.email // empty')
[ "$GOT_EMAIL" = "$EMAIL" ] || cv_fail "expected user.email $EMAIL got $GOT_EMAIL" $LINENO

# Then
cv_step Then "the token is accepted on a signed-in-only request" $LINENO
cv_http POST /products "$(jq -nc --arg n "Signin check $SUFFIX" '{name:$n,price:1}')" -H "Authorization: Bearer $TOKEN"
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected 201 for signed-in product create got $CV_HTTP_STATUS" $LINENO

# Cleanup
cv_step Cleanup "nothing to remove: the store is in-memory and has no delete endpoint" $LINENO
echo "CODEVALID_TEST_ASSERTION_OK:api_78497391_1"
