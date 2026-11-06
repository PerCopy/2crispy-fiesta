#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
EMAIL="catalog4.${SUFFIX}@example.com"
PASSWORD="Str0ngPass-${SUFFIX}"
NAME="Toaster-$SUFFIX"; DESC="Two-slot toaster $SUFFIX"; PRICE=33.99; CODE="TST-$SUFFIX"

# Given
cv_step Given "a product has just been added to the catalog" $LINENO
cv_prereq "register product owner" $LINENO
cv_http POST /auth/register "$(jq -nc --arg e "$EMAIL" --arg p "$PASSWORD" '{email:$e,password:$p,name:"Catalog Owner"}')"
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected register 201 got $CV_HTTP_STATUS" $LINENO
TOKEN=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.token // empty')
[ -n "$TOKEN" ] || cv_fail "expected token from register got none" $LINENO
cv_prereq "add product" $LINENO
cv_http POST /products "$(jq -nc --arg n "$NAME" --arg d "$DESC" --argjson p "$PRICE" --arg c "$CODE" '{name:$n,description:$d,price:$p,code:$c,productCode:$c}')" -H "Authorization: Bearer $TOKEN"
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected product create 201 got $CV_HTTP_STATUS" $LINENO
PID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.product.id // empty')
[ -n "$PID" ] || cv_fail "expected product id got none" $LINENO

# When
cv_step When "a visitor without sign-in views the catalog" $LINENO
cv_http GET /products "" 200
LIST_BODY="$CV_HTTP_BODY"

# Then
cv_step Then "the new product is listed and opening it returns the details it was added with" $LINENO
ITEM=$(printf '%s' "$LIST_BODY" | jq -c --arg id "$PID" '.products[]? | select(.id == $id)')
[ -n "$ITEM" ] || cv_fail "expected new product $PID in catalog got none" $LINENO
[ "$(printf '%s' "$ITEM" | jq -r '.name')" = "$NAME" ] || cv_fail "expected listed name $NAME got $ITEM" $LINENO
cv_http GET "/products/$PID" "" 200
GOT=$(printf '%s' "$CV_HTTP_BODY" | jq -c '.product // empty')
[ -n "$GOT" ] || cv_fail "expected product in response got $CV_HTTP_BODY" $LINENO
[ "$(printf '%s' "$GOT" | jq -r '.name')" = "$NAME" ] || cv_fail "expected name $NAME got $GOT" $LINENO
[ "$(printf '%s' "$GOT" | jq -r '.description')" = "$DESC" ] || cv_fail "expected description $DESC got $GOT" $LINENO
printf '%s' "$GOT" | jq -e --argjson p "$PRICE" '.price == $p' >/dev/null || cv_fail "expected price $PRICE got $GOT" $LINENO

# Cleanup
cv_step Cleanup "no delete route exists; product stays in the in-memory store until restart" $LINENO
echo "product $PID remains in memory"

echo "CODEVALID_TEST_ASSERTION_OK:api_50765553_4"
