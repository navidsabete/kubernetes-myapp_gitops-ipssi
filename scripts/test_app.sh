#!/usr/bin/env bash

set -e

set -euo pipefail

# Charger les variables
set -a          # active l'export automatique pour toutes les variables définies
source ../.env     # ou . .env
set +a          # désactive l'export automatique


ARGO_NAMESPACE="argocd"
ARGO_SERVICE="argocd-server"

echo "🚀 Test de l'application Node.js"
echo "--------------------------------"

# 1. Port-forward App
kubectl port-forward svc/${APP_NAME} -n ${APP_NAMESPACE} ${APP_LOCAL_PORT}:80 \
  >/tmp/pf-app.log 2>&1 &
APP_PF_PID=$!
sleep 3

# 2. Test App
APP_RESPONSE=$(curl -s http://localhost:${APP_LOCAL_PORT} || true)

if [[ -z "$APP_RESPONSE" ]]; then
  echo "❌ L'app ne répond pas"
  kill $APP_PF_PID
  exit 1
fi

echo "✅ App répond :"
echo "$APP_RESPONSE"

# 3. Arrêt port-forward App
kill $APP_PF_PID
wait $APP_PF_PID 2>/dev/null || true

echo
echo "🔐 Test de Argo CD"
echo "-----------------"

# 4. Port-forward Argo CD
kubectl port-forward svc/${ARGO_SERVICE} -n ${ARGO_NAMESPACE} ${ARGOCD_LOCAL_PORT}:443 \
  >/tmp/pf-argocd.log 2>&1 &
ARGO_PF_PID=$!
sleep 3

# 5. Test Argo CD
ARGO_RESPONSE=$(curl -sk https://localhost:${ARGOCD_LOCAL_PORT} | head -n 5)

if [[ -z "$ARGO_RESPONSE" ]]; then
  echo "❌ Argo CD ne répond pas"
  kill $ARGO_PF_PID
  exit 1
fi

echo "✅ Argo CD répond (aperçu) :"
echo "$ARGO_RESPONSE"

# 6. Arrêt port-forward Argo CD
kill $ARGO_PF_PID
wait $ARGO_PF_PID 2>/dev/null || true

echo
echo "🎉 Tous les tests sont OK"
