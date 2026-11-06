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
cv_step Given "a registered customer signs in" $LINENO
register_user
cv_http POST /auth/login "$(jq -nc --arg e "$EMAIL" --arg p "$PASSWORD" '{email:$e,password:$p}')"
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 from sign-in got $CV_HTTP_STATUS" $LINENO
TOKEN=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.token // empty')
[ -n "$TOKEN" ] || cv_fail "expected a token from sign-in got none" $LINENO
PNAME="Widget $SUFFIX"

# When
cv_step When "the signed-in customer adds a product" $LINENO
cv_http POST /products "$(jq -nc --arg n "$PNAME" '{name:$n,description:"test product",price:12.5}')" -H "Authorization: Bearer $TOKEN"
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected 201 from product create got $CV_HTTP_STATUS" $LINENO
PID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.product.id // empty')
[ -n "$PID" ] || cv_fail "expected product id in response got none" $LINENO

# Then
cv_step Then "the catalog shows the new product" $LINENO
cv_http GET /products
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 from catalog got $CV_HTTP_STATUS" $LINENO
FOUND=$(printf '%s' "$CV_HTTP_BODY" | jq -r --arg id "$PID" '.products[] | select(.id==$id) | .name')
[ "$FOUND" = "$PNAME" ] || cv_fail "expected catalog to list $PNAME got '$FOUND'" $LINENO
cv_http GET "/products/$PID"
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 for product $PID got $CV_HTTP_STATUS" $LINENO
PRICE=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.product.price')
[ "$PRICE" = "12.5" ] || cv_fail "expected price 12.5 got $PRICE" $LINENO

# Cleanup
cv_step Cleanup "nothing to remove: the store is in-memory and has no delete endpoint" $LINENO
echo "CODEVALID_TEST_ASSERTION_OK:api_78497391_6"
