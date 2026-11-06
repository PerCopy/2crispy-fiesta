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

NAME="CV Anon ${SUFFIX}"; CODE="CV-ANON-${SUFFIX}"

# Given
cv_step Given "a visitor without a sign-in token and an unused product name and code" $LINENO
cv_http GET /products 200
PRE=$(printf '%s' "$CV_HTTP_BODY" | jq --arg n "$NAME" '[.products[] | select(.name==$n)] | length')
[ "$PRE" = "0" ] || cv_fail "expected product $NAME absent before attempt got $PRE" $LINENO

# When
cv_step When "the visitor tries to add a product without signing in" $LINENO
cv_http POST /products "$(product_body "$NAME" "Anon desc" 3 "$CODE")"
ANON_STATUS=$CV_HTTP_STATUS

# Then
cv_step Then "the addition is refused and the product is not in the catalog" $LINENO
case "$ANON_STATUS" in 2??) cv_fail "expected refusal for anonymous add got $ANON_STATUS" $LINENO ;; esac
cv_http GET /products 200
POST_COUNT=$(printf '%s' "$CV_HTTP_BODY" | jq --arg n "$NAME" --arg c "$CODE" '[.products[] | select(.name==$n or (.productCode // .code)==$c)] | length')
[ "$POST_COUNT" = "0" ] || cv_fail "expected anonymous product absent from catalog got $POST_COUNT" $LINENO

# Cleanup
cv_step Cleanup "nothing was created" $LINENO
echo "nothing to remove"
echo "CODEVALID_TEST_ASSERTION_OK:api_22455501_7"
