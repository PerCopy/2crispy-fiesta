#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
EMAIL="prod.${SUFFIX}@example.com"
PASSWORD="Str0ngPass-${SUFFIX}"
register() {
  cv_prereq "register signed-in user" $LINENO
  cv_http POST /auth/register "$(jq -nc --arg e "$EMAIL" --arg p "$PASSWORD" '{email:$e,password:$p,name:"Catalog User"}')"
  [ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected register 201 got $CV_HTTP_STATUS" $LINENO
  TOKEN=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.token // empty')
  [ -n "$TOKEN" ] || cv_fail "expected token from register got none" $LINENO
}
product_json() { jq -nc --arg n "$1" --arg d "$2" --argjson p "$3" --arg c "$4" '{name:$n,description:$d,price:$p,code:$c,productCode:$c}'; }
code_of() { jq -r '(.code // .productCode // .product_code // .sku // "")'; }

# Given
cv_step Given "an unused product code and a registered user who can sign in" $LINENO
register
CODE="CLAIM-$SUFFIX"

# When
cv_step When "a visitor who is not signed in tries to add a product with that code" $LINENO
cv_http POST /products "$(product_json "Squat-$SUFFIX" "Squatter $SUFFIX" 1 "$CODE")"
ATTEMPT=$CV_HTTP_STATUS

# Then
cv_step Then "the attempt is refused and the signed-in user can still use the code" $LINENO
case "$ATTEMPT" in 2*) cv_fail "expected anonymous code claim to be refused got $ATTEMPT" $LINENO ;; esac
cv_http POST /products "$(product_json "Real-$SUFFIX" "Real $SUFFIX" 15 "$CODE")" -H "Authorization: Bearer $TOKEN"
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected signed-in add with code $CODE to return 201 got $CV_HTTP_STATUS: $CV_HTTP_BODY" $LINENO
[ "$(printf '%s' "$CV_HTTP_BODY" | jq -c '.product' | code_of)" = "$CODE" ] || cv_fail "expected product with code $CODE got $CV_HTTP_BODY" $LINENO
cv_http GET /products "" 200
LEAK=$(printf '%s' "$CV_HTTP_BODY" | jq -c --arg s "$SUFFIX" '[.products[] | select(.name == ("Squat-" + $s))]')
[ "$LEAK" = "[]" ] || cv_fail "expected no anonymous product in catalog got $LEAK" $LINENO

# Cleanup
cv_step Cleanup "no delete route exists; the product lives in memory until restart" $LINENO

echo "CODEVALID_TEST_ASSERTION_OK:api_89160387_8"
