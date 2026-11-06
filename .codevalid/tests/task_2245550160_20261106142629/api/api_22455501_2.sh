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

CODE="CV-DUP-${SUFFIX}"

# Given
cv_step Given "a signed-in user and an existing product using a product code" $LINENO
register_user dup
cv_http POST /products "$(product_body "CV Original ${SUFFIX}" "Original desc" 10 "$CODE")" -H "Authorization: Bearer $TOKEN"
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected 201 adding original product got $CV_HTTP_STATUS" $LINENO
PID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.product.id // empty')
[ -n "$PID" ] || cv_fail "expected product id from create got none" $LINENO

# When
cv_step When "the user adds another product with the same product code" $LINENO
cv_http POST /products "$(product_body "CV Duplicate ${SUFFIX}" "Duplicate desc" 99 "$CODE")" -H "Authorization: Bearer $TOKEN"
DUP_STATUS=$CV_HTTP_STATUS

# Then
cv_step Then "the addition is refused, only one product has the code and the original is unchanged" $LINENO
case "$DUP_STATUS" in 4??) ;; *) cv_fail "expected 4xx refusal for duplicate product code got $DUP_STATUS" $LINENO ;; esac
cv_http GET /products 200
DUPS=$(printf '%s' "$CV_HTTP_BODY" | jq --arg n "CV Duplicate ${SUFFIX}" '[.products[] | select(.name==$n)] | length')
[ "$DUPS" = "0" ] || cv_fail "expected no duplicate product in catalog got $DUPS" $LINENO
WITH_CODE=$(printf '%s' "$CV_HTTP_BODY" | jq --arg c "$CODE" '[.products[] | select((.productCode // .code)==$c)] | length')
[ "$WITH_CODE" = "1" ] || cv_fail "expected exactly 1 product with code $CODE got $WITH_CODE" $LINENO
cv_http GET "/products/$PID" 200
P=$(printf '%s' "$CV_HTTP_BODY" | jq -c '.product')
[ "$(printf '%s' "$P" | jq -r '.name')" = "CV Original ${SUFFIX}" ] || cv_fail "expected original name unchanged got $(printf '%s' "$P" | jq -r '.name')" $LINENO
[ "$(printf '%s' "$P" | jq -r '.price == 10')" = "true" ] || cv_fail "expected original price 10 got $(printf '%s' "$P" | jq -r '.price')" $LINENO

# Cleanup
cv_step Cleanup "catalog is in-memory; no delete endpoint exists" $LINENO
echo "nothing to remove"
echo "CODEVALID_TEST_ASSERTION_OK:api_22455501_2"
