#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"

# Given
cv_step Given "the catalog state before the visit (the in-memory store is empty after a fresh start)" $LINENO
cv_prereq "probe service health" $LINENO
cv_http GET /health "" 200
echo "this check adds no products; on a freshly started service the catalog is empty"

# When
cv_step When "a visitor views the catalog" $LINENO
cv_http GET /products

# Then
cv_step Then "a list is returned rather than an error, and it is empty when nothing has been added" $LINENO
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 got $CV_HTTP_STATUS" $LINENO
printf '%s' "$CV_HTTP_BODY" | jq -e '.products | type == "array"' >/dev/null || cv_fail "expected products array got $CV_HTTP_BODY" $LINENO
if printf '%s' "$CV_HTTP_BODY" | jq -e 'has("error")' >/dev/null; then cv_fail "expected no error got $CV_HTTP_BODY" $LINENO; fi
COUNT=$(printf '%s' "$CV_HTTP_BODY" | jq '.products | length')
[ "$COUNT" = "0" ] || cv_fail "expected empty catalog [] got $COUNT products (store not fresh)" $LINENO

# Cleanup
cv_step Cleanup "nothing was created" $LINENO
echo "no data to remove"

echo "CODEVALID_TEST_ASSERTION_OK:api_50765553_5"
