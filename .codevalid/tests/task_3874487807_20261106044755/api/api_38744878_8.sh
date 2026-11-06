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
cv_step Given "a catalog snapshot and a user whose sign-in was not completed" $LINENO
register_user "$EMAIL" "$PASSWORD"
cv_http POST /auth/login "$(jq -nc --arg e "$EMAIL" '{email:$e,password:"Not-The-Password1"}')" 401
product_count; BEFORE="$PRODUCT_COUNT"
NAME="Anon-Item-$SUFFIX"

# When
cv_step When "the not-signed-in user tries to add a product" $LINENO
cv_http POST /products "$(jq -nc --arg n "$NAME" '{name:$n,price:3}')"

# Then
cv_step Then "the attempt is refused and the catalog is unchanged" $LINENO
[ "$CV_HTTP_STATUS" = "401" ] || [ "$CV_HTTP_STATUS" = "403" ] || cv_fail "expected refusal (401/403) got $CV_HTTP_STATUS" $LINENO
cv_http GET /products "" 200
printf '%s' "$CV_HTTP_BODY" | jq -e --arg n "$NAME" '[.products[]|select(.name==$n)]|length==0' >/dev/null || cv_fail "expected no product $NAME in catalog but it was created" $LINENO

# Cleanup
cv_step Cleanup "in-memory store has no delete routes; nothing to remove" $LINENO
echo "catalog size before was $BEFORE"

echo "CODEVALID_TEST_ASSERTION_OK:api_38744878_8"
