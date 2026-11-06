#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"

register_user() {
  local email="cv-cat-${1}-${SUFFIX}@example.com"
  cv_http POST /auth/register "$(jq -nc --arg e "$email" --arg p "Pw-${SUFFIX}!" '{email:$e,password:$p}')"
  [ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected 201 registering $email got $CV_HTTP_STATUS" $LINENO
  TOKEN=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.token // empty')
  [ -n "$TOKEN" ] || cv_fail "expected a token on register got none" $LINENO
}

product_body() {
  jq -nc --arg n "$1" --arg d "$2" --argjson p "$3" --arg c "$4" '{name:$n,description:$d,price:$p,productCode:$c}'
}

NAME="CV Single ${SUFFIX}"; DESC="Single desc ${SUFFIX}"; CODE="CV-S-${SUFFIX}"

# Given
cv_step Given "a product exists in the catalog" $LINENO
register_user single
cv_http POST /products "$(product_body "$NAME" "$DESC" 12.25 "$CODE")" -H "Authorization: Bearer $TOKEN"
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected 201 adding product got $CV_HTTP_STATUS" $LINENO
PID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.product.id // empty')
[ -n "$PID" ] || cv_fail "expected product id from create got none" $LINENO

# When
cv_step When "a visitor who is not signed in opens the product by its identifier" $LINENO
cv_http GET "/products/$PID"
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 opening product got $CV_HTTP_STATUS" $LINENO

# Then
cv_step Then "the product's name, description, price and product code are returned" $LINENO
P=$(printf '%s' "$CV_HTTP_BODY" | jq -c '.product // .')
[ "$(printf '%s' "$P" | jq -r '.id')" = "$PID" ] || cv_fail "expected id $PID got $(printf '%s' "$P" | jq -r '.id')" $LINENO
[ "$(printf '%s' "$P" | jq -r '.name')" = "$NAME" ] || cv_fail "expected name $NAME got $(printf '%s' "$P" | jq -r '.name')" $LINENO
[ "$(printf '%s' "$P" | jq -r '.description')" = "$DESC" ] || cv_fail "expected description $DESC got $(printf '%s' "$P" | jq -r '.description')" $LINENO
[ "$(printf '%s' "$P" | jq -r '.price == 12.25')" = "true" ] || cv_fail "expected price 12.25 got $(printf '%s' "$P" | jq -r '.price')" $LINENO
GOT_CODE=$(printf '%s' "$P" | jq -r '.productCode // .code // empty')
[ "$GOT_CODE" = "$CODE" ] || cv_fail "expected product code $CODE got '$GOT_CODE'" $LINENO

# Cleanup
cv_step Cleanup "catalog is in-memory; no delete endpoint exists" $LINENO
echo "nothing to remove"
echo "CODEVALID_TEST_ASSERTION_OK:api_22455501_4"
