#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
EMAIL="signin.${SUFFIX}@example.com"
PASSWORD="Str0ngPass-${SUFFIX}"
register_user() {
  cv_prereq "register $1" $LINENO
  cv_http POST /auth/register "$(jq -nc --arg e "$1" --arg p "$2" '{email:$e,password:$p,name:"Sign In Customer"}')"
  [ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected register 201 got $CV_HTTP_STATUS" $LINENO
}
product_count() {
  cv_http GET /products "" 200
  PRODUCT_COUNT=$(printf "%s" "$CV_HTTP_BODY" | jq -r ".products | length")
}

# Given
cv_step Given "a catalog containing a product added by a signed-in customer" $LINENO
register_user "$EMAIL" "$PASSWORD"
TOKEN=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.token // empty')
NAME="Browse-Item-$SUFFIX"
cv_http POST /products "$(jq -nc --arg n "$NAME" '{name:$n,price:5}')" 201 -H "Authorization: Bearer $TOKEN"
PID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.product.id // empty')
[ -n "$PID" ] || cv_fail "expected product id from setup got none" $LINENO

# When
cv_step When "a user without any sign-in reads the catalog" $LINENO
cv_http GET /products

# Then
cv_step Then "the catalog contents are returned" $LINENO
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 for anonymous browse got $CV_HTTP_STATUS" $LINENO
printf '%s' "$CV_HTTP_BODY" | jq -e --arg id "$PID" --arg n "$NAME" '[.products[]|select(.id==$id and .name==$n)]|length==1' >/dev/null || cv_fail "expected product $PID in anonymous catalog read got none" $LINENO
cv_http GET "/products/$PID"
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 for anonymous product read got $CV_HTTP_STATUS" $LINENO

# Cleanup
cv_step Cleanup "in-memory store has no delete routes; nothing to remove" $LINENO
echo "product $PID remains in memory"

echo "CODEVALID_TEST_ASSERTION_OK:api_38744878_7"
