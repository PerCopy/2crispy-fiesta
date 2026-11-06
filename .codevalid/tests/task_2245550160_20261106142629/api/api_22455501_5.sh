#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
UNKNOWN_ID="00000000-0000-4000-8000-${SUFFIX: -12}"

# Given
cv_step Given "an identifier that no product has" $LINENO
cv_http GET /products 200
FOUND=$(printf '%s' "$CV_HTTP_BODY" | jq --arg id "$UNKNOWN_ID" '[.products[] | select(.id==$id)] | length')
[ "$FOUND" = "0" ] || cv_fail "expected identifier $UNKNOWN_ID to be unused got $FOUND matches" $LINENO

# When
cv_step When "a visitor opens a product with the unknown identifier" $LINENO
cv_http GET "/products/$UNKNOWN_ID"

# Then
cv_step Then "not found is returned with no product data" $LINENO
[ "$CV_HTTP_STATUS" = "404" ] || cv_fail "expected 404 for unknown product got $CV_HTTP_STATUS" $LINENO
HAS=$(printf '%s' "$CV_HTTP_BODY" | jq -r 'has("product")')
[ "$HAS" = "false" ] || cv_fail "expected no product data got $CV_HTTP_BODY" $LINENO
printf '%s' "$CV_HTTP_BODY" | jq -r '.error // empty' | grep -qi 'not found' || cv_fail "expected 'not found' message got $CV_HTTP_BODY" $LINENO

# Cleanup
cv_step Cleanup "nothing was created" $LINENO
echo "nothing to remove"
echo "CODEVALID_TEST_ASSERTION_OK:api_22455501_5"
