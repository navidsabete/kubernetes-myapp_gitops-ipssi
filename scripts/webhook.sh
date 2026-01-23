#!/bin/bash

set -e

# Charger les variables
set -a          # active l'export automatique pour toutes les variables définies
source ../.env     # ou . .env
set +a          # désactive l'export automatique

# ==============================
# Configuration
# ==============================
GITHUB_API="https://api.github.com"
EVENTS='["push"]'
WEBHOOK_PATH="/api/webhook"
CONTENT_TYPE="json"

# ==============================
# Vérifications
# ==============================
if [[ -z "$GITHUB_TOKEN" || -z "$GITHUB_OWNER" || -z "$GITHUB_REPO" ]]; then
  echo "❌ Missing required environment variables"
  echo "Required: GITHUB_TOKEN, GITHUB_OWNER, GITHUB_REPO"
  exit 1
fi

command -v jq >/dev/null 2>&1 || {
  echo "❌ jq is required"
  exit 1
}

# ==============================
# Récupérer URL ngrok
# ==============================
echo "🌍 Retrieving ngrok public URL..."

NGROK_URL=$(curl -s http://localhost:4040/api/tunnels \
  | jq -r '.tunnels[] | select(.proto=="https") | .public_url')

if [[ -z "$NGROK_URL" || "$NGROK_URL" == "null" ]]; then
  echo "❌ Unable to retrieve ngrok URL"
  exit 1
fi


WEBHOOK_URL="${NGROK_URL}${WEBHOOK_PATH}"

echo "✅ Webhook URL:"
echo "👉 $WEBHOOK_URL"

# ==============================
# Supprimer anciens webhooks (optionnel mais propre)
# ==============================
echo "🧹 Cleaning existing webhooks..."

HOOKS=$(curl -s \
  -H "Authorization: token $GITHUB_TOKEN" \
  "$GITHUB_API/repos/$GITHUB_OWNER/$GITHUB_REPO/hooks")

echo "$HOOKS" | jq -r '.[].id' | while read -r HOOK_ID; do
  curl -s -X DELETE \
    -H "Authorization: token $GITHUB_TOKEN" \
    "$GITHUB_API/repos/$GITHUB_OWNER/$GITHUB_REPO/hooks/$HOOK_ID"
done

# ==============================
# Créer le webhook
# ==============================
echo "🔔 Creating GitHub webhook..."

PAYLOAD=$(jq -n \
  --arg url "$WEBHOOK_URL" \
  --argjson events "$EVENTS" \
  '{
    name: "web",
    active: true,
    events: $events,
    config: {
      url: $url,
      content_type: "json",
      insecure_ssl: "1"
    }
  }')


RESPONSE=$(curl -s -X POST \
-H "Authorization: token $GITHUB_TOKEN" \
-H "Content-Type: application/json" \
-d "$PAYLOAD" \
"$GITHUB_API/repos/$GITHUB_OWNER/$GITHUB_REPO/hooks")

if echo "$RESPONSE" | jq -e '.id' >/dev/null; then
  echo "✅ Webhook successfully created"
else
  echo "❌ Failed to create webhook"
  echo "$RESPONSE"
  exit 1
fi