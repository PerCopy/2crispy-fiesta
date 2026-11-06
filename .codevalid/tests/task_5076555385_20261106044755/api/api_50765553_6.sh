#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
EMAIL="catalog6.${SUFFIX}@example.com"
PASSWORD="Str0ngPass-${SUFFIX}"
NAME="Chair-$SUFFIX"; DESC="Oak chair $SUFFIX"; PRICE=120; CODE="CHR-$SUFFIX"
ATTACK_NAME="Anon-$SUFFIX"

# Given
cv_step Given "an owner's product in the catalog and an anonymous visitor with no token" $LINENO
cv_prereq "register product owner" $LINENO
cv_http POST /auth/register "$(jq -nc --arg e "$EMAIL" --arg p "$PASSWORD" '{email:$e,password:$p,name:"Catalog Owner"}')"
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected register 201 got $CV_HTTP_STATUS" $LINENO
TOKEN=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.token // empty')
[ -n "$TOKEN" ] || cv_fail "expected token from register got none" $LINENO
cv_prereq "owner adds product" $LINENO
cv_http POST /products "$(jq -nc --arg n "$NAME" --arg d "$DESC" --argjson p "$PRICE" --arg c "$CODE" '{name:$n,description:$d,price:$p,code:$c,productCode:$c}')" -H "Authorization: Bearer $TOKEN"
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected product create 201 got $CV_HTTP_STATUS" $LINENO
BEFORE=$(printf '%s' "$CV_HTTP_BODY" | jq -c '.product')
PID=$(printf '%s' "$BEFORE" | jq -r '.id // empty')
[ -n "$PID" ] || cv_fail "expected product id got none" $LINENO

# When
cv_step When "the anonymous visitor tries to add a product, reusing the owner's product id at a changed price" $LINENO
cv_http POST /products "$(jq -nc --arg id "$PID" --arg n "$ATTACK_NAME" '{id:$id,name:$n,description:"injected",price:0.01}')"
ATTEMPT_STATUS="$CV_HTTP_STATUS"
ATTEMPT_BODY="$CV_HTTP_BODY"

# Then
cv_step Then "no product was added and the owner's product is unchanged" $LINENO
case "$ATTEMPT_STATUS" in 2??) cv_fail "expected anonymous add to be refused got $ATTEMPT_STATUS: $ATTEMPT_BODY" $LINENO;; esac
cv_http GET /products "" 200
ADDED=$(printf '%s' "$CV_HTTP_BODY" | jq --arg n "$ATTACK_NAME" '[.products[] | select(.name == $n)] | length')
[ "$ADDED" = "0" ] || cv_fail "expected no product named $ATTACK_NAME in catalog got $ADDED" $LINENO
cv_http GET "/products/$PID" "" 200
AFTER=$(printf '%s' "$CV_HTTP_BODY" | jq -c '.product')
[ "$AFTER" = "$BEFORE" ] || cv_fail "expected product unchanged $BEFORE got $AFTER" $LINENO

# Cleanup
cv_step Cleanup "no delete route exists; owner's product stays in the in-memory store until restart" $LINENO
echo "product $PID remains in memory"

echo "CODEVALID_TEST_ASSERTION_OK:api_50765553_6"
