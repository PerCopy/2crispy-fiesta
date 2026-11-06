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
cv_step Given "a catalog with a known product count and no signed-in session" $LINENO
cv_http GET /products
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 from catalog got $CV_HTTP_STATUS" $LINENO
BEFORE=$(printf '%s' "$CV_HTTP_BODY" | jq '.products | length')
PNAME="Anon item $SUFFIX"

# When
cv_step When "an anonymous client tries to add a product" $LINENO
cv_http POST /products "$(jq -nc --arg n "$PNAME" '{name:$n,price:9.99}')"
STATUS="$CV_HTTP_STATUS"

# Then
cv_step Then "the request is refused and the catalog does not contain the product" $LINENO
case "$STATUS" in 2*) cv_fail "expected anonymous product create to be refused got $STATUS" $LINENO ;; esac
cv_http GET /products
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 from catalog got $CV_HTTP_STATUS" $LINENO
FOUND=$(printf '%s' "$CV_HTTP_BODY" | jq -r --arg n "$PNAME" '[.products[] | select(.name==$n)] | length')
[ "$FOUND" = "0" ] || cv_fail "expected anonymous product absent from catalog got $FOUND matches" $LINENO

# Cleanup
cv_step Cleanup "nothing to remove: no data was created" $LINENO
echo "CODEVALID_TEST_ASSERTION_OK:api_78497391_8"
