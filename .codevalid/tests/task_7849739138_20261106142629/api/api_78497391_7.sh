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
cv_step Given "a signed-in customer has added a product to the catalog" $LINENO
register_user
TOKEN=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.token // empty')
[ -n "$TOKEN" ] || cv_fail "expected a token from register got none" $LINENO
PNAME="Browse item $SUFFIX"
cv_http POST /products "$(jq -nc --arg n "$PNAME" '{name:$n,price:3}')" -H "Authorization: Bearer $TOKEN"
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected 201 from product create got $CV_HTTP_STATUS" $LINENO
PID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.product.id // empty')
[ -n "$PID" ] || cv_fail "expected product id got none" $LINENO

# When
cv_step When "an anonymous client requests the catalog" $LINENO
cv_http GET /products

# Then
cv_step Then "the catalog contents are returned including the product" $LINENO
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 for anonymous catalog browse got $CV_HTTP_STATUS" $LINENO
FOUND=$(printf '%s' "$CV_HTTP_BODY" | jq -r --arg id "$PID" '.products[]? | select(.id==$id) | .name')
[ "$FOUND" = "$PNAME" ] || cv_fail "expected anonymous catalog to include $PNAME got '$FOUND'" $LINENO

# Cleanup
cv_step Cleanup "nothing to remove: the store is in-memory and has no delete endpoint" $LINENO
echo "CODEVALID_TEST_ASSERTION_OK:api_78497391_7"
