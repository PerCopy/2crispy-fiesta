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

CODE1="CV-A-${SUFFIX}"; CODE2="CV-B-${SUFFIX}"

# Given
cv_step Given "a signed-in user adds two products" $LINENO
register_user list
cv_http POST /products "$(product_body "CV First ${SUFFIX}" "First desc" 5 "$CODE1")" -H "Authorization: Bearer $TOKEN"
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected 201 adding first product got $CV_HTTP_STATUS" $LINENO
ID1=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.product.id // empty')
cv_http POST /products "$(product_body "CV Second ${SUFFIX}" "Second desc" 7.5 "$CODE2")" -H "Authorization: Bearer $TOKEN"
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected 201 adding second product got $CV_HTTP_STATUS" $LINENO
ID2=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.product.id // empty')
[ -n "$ID1" ] && [ -n "$ID2" ] || cv_fail "expected product ids from create got '$ID1' '$ID2'" $LINENO

# When
cv_step When "a visitor who is not signed in requests the full catalog" $LINENO
cv_http GET /products
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 on catalog got $CV_HTTP_STATUS" $LINENO

# Then
cv_step Then "both new products are listed with their details" $LINENO
P1=$(printf '%s' "$CV_HTTP_BODY" | jq -c --arg id "$ID1" '.products[] | select(.id==$id)')
P2=$(printf '%s' "$CV_HTTP_BODY" | jq -c --arg id "$ID2" '.products[] | select(.id==$id)')
[ -n "$P1" ] || cv_fail "expected product $ID1 in catalog got none" $LINENO
[ -n "$P2" ] || cv_fail "expected product $ID2 in catalog got none" $LINENO
[ "$(printf '%s' "$P1" | jq -r '.name')" = "CV First ${SUFFIX}" ] || cv_fail "expected first product name got $(printf '%s' "$P1" | jq -r '.name')" $LINENO
[ "$(printf '%s' "$P1" | jq -r '.description')" = "First desc" ] || cv_fail "expected first description got $(printf '%s' "$P1" | jq -r '.description')" $LINENO
[ "$(printf '%s' "$P1" | jq -r '.price == 5')" = "true" ] || cv_fail "expected first price 5 got $(printf '%s' "$P1" | jq -r '.price')" $LINENO
[ "$(printf '%s' "$P2" | jq -r '.name')" = "CV Second ${SUFFIX}" ] || cv_fail "expected second product name got $(printf '%s' "$P2" | jq -r '.name')" $LINENO
[ "$(printf '%s' "$P2" | jq -r '.price == 7.5')" = "true" ] || cv_fail "expected second price 7.5 got $(printf '%s' "$P2" | jq -r '.price')" $LINENO
[ "$(printf '%s' "$P1" | jq -r '.productCode // .code // empty')" = "$CODE1" ] || cv_fail "expected first product code $CODE1 got '$(printf '%s' "$P1" | jq -r '.productCode // .code // empty')'" $LINENO
[ "$(printf '%s' "$P2" | jq -r '.productCode // .code // empty')" = "$CODE2" ] || cv_fail "expected second product code $CODE2 got '$(printf '%s' "$P2" | jq -r '.productCode // .code // empty')'" $LINENO

# Cleanup
cv_step Cleanup "catalog is in-memory; no delete endpoint exists" $LINENO
echo "nothing to remove"
echo "CODEVALID_TEST_ASSERTION_OK:api_22455501_3"
