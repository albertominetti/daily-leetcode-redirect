#!/usr/bin/env bash
# Fetches today's LeetCode daily challenge and regenerates index.html from template.html.
# Exits non-zero (and leaves index.html untouched) if the fetch or response shape looks wrong,
# so a bad run never publishes a broken page.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

QUERY='query questionOfToday { activeDailyCodingChallengeQuestion { date question { questionFrontendId title titleSlug difficulty } } }'
PAYLOAD=$(jq -n --arg q "$QUERY" '{query: $q}')

RESPONSE_FILE="$(mktemp)"
trap 'rm -f "$RESPONSE_FILE"' EXIT

http_status=$(curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' \
  -X POST "https://leetcode.com/graphql" \
  -H "Content-Type: application/json" \
  -H "User-Agent: Mozilla/5.0 (compatible; leetcode-daily-redirect/1.0; +https://github.com)" \
  -H "Referer: https://leetcode.com" \
  --max-time 20 \
  --data "$PAYLOAD") || {
    echo "::error::curl request to leetcode.com/graphql failed to complete"
    exit 1
  }

if [ "$http_status" != "200" ]; then
  echo "::error::leetcode.com/graphql returned HTTP $http_status"
  cat "$RESPONSE_FILE" >&2
  exit 1
fi

if ! jq -e '.data.activeDailyCodingChallengeQuestion.question.titleSlug' "$RESPONSE_FILE" >/dev/null 2>&1; then
  echo "::error::Response did not contain the expected daily challenge fields"
  cat "$RESPONSE_FILE" >&2
  exit 1
fi

SLUG=$(jq -r '.data.activeDailyCodingChallengeQuestion.question.titleSlug' "$RESPONSE_FILE")
TITLE_RAW=$(jq -r '.data.activeDailyCodingChallengeQuestion.question.title' "$RESPONSE_FILE")
FRONTEND_ID=$(jq -r '.data.activeDailyCodingChallengeQuestion.question.questionFrontendId' "$RESPONSE_FILE")
DIFFICULTY=$(jq -r '.data.activeDailyCodingChallengeQuestion.question.difficulty' "$RESPONSE_FILE")
CHALLENGE_DATE=$(jq -r '.data.activeDailyCodingChallengeQuestion.date' "$RESPONSE_FILE")

URL="https://leetcode.com/problems/${SLUG}/"
SYNCED_AT="$(date -u +'%Y-%m-%d %H:%M UTC')"
DIFFICULTY_CLASS=$(printf '%s' "$DIFFICULTY" | tr '[:upper:]' '[:lower:]')

html_escape() {
  sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e "s/'/\&#39;/g" -e 's/"/\&quot;/g'
}
TITLE=$(printf '%s' "$TITLE_RAW" | html_escape)

sed \
  -e "s#__TITLE__#${TITLE}#g" \
  -e "s#__FRONTEND_ID__#${FRONTEND_ID}#g" \
  -e "s#__DIFFICULTY_CLASS__#${DIFFICULTY_CLASS}#g" \
  -e "s#__DIFFICULTY__#${DIFFICULTY}#g" \
  -e "s#__URL__#${URL}#g" \
  -e "s#__DATE__#${CHALLENGE_DATE}#g" \
  -e "s#__SYNCED_AT__#${SYNCED_AT}#g" \
  template.html > index.html

echo "Synced: ${FRONTEND_ID}. ${TITLE_RAW} [${DIFFICULTY}] -> ${URL}"
