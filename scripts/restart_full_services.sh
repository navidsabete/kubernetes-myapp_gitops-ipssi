#!/bin/bash

set -e

# Charger les variables
set -a          # active l'export automatique pour toutes les variables définies
source ../.env     # ou . .env
set +a          # désactive l'export automatique

ARGOCD_NAMESPACE="argocd"

echo "🚀 Restarting Argo CD and application services..."

# ---------------------------
# Kill ngrok and port-forward
# ---------------------------
echo "🧹 Killing existing ngrok and kubectl port-forward processes..."
pkill -f ngrok || true
pkill -f "kubectl port-forward" || true


# ---------------------------
# Restart Argo CD deployments
# ---------------------------
echo "♻️ Restarting all Argo CD deployments..."
kubectl get deployments -n $ARGOCD_NAMESPACE -o name | while read deploy; do
  echo "Restarting $deploy"
  kubectl rollout restart "$deploy" -n $ARGOCD_NAMESPACE
done

echo "⏳ Waiting for Argo CD pods to be ready..."
kubectl wait --for=condition=Ready pods -n $ARGOCD_NAMESPACE --all --timeout=300s

#kubectl rollout restart deployment argocd-server -n $ARGOCD_NAMESPACE
#kubectl rollout restart deployment argocd-repo-server -n $ARGOCD_NAMESPACE
#kubectl rollout restart deployment argocd-application-controller -n $ARGOCD_NAMESPACE
#kubectl rollout restart deployment argocd-dex-server -n $ARGOCD_NAMESPACE

# ---------------------------
# Port-forward Argo CD
# ---------------------------
echo "🔗 Starting kubectl port-forward for Argo CD..."
kubectl port-forward svc/argocd-server -n $ARGOCD_NAMESPACE $ARGOCD_LOCAL_PORT:443 > /tmp/argocd-port-forward.log 2>&1 &
PORT_FORWARD_PID=$!
sleep 5
echo "✅ Port-forward started on localhost:$ARGOCD_LOCAL_PORT"



# ---------------------------
# Start ngrok tunnel
# ---------------------------
echo "🌍 Starting ngrok tunnel..."
ngrok http https://localhost:$ARGOCD_LOCAL_PORT > /tmp/ngrok.log 2>&1 &
NGROK_PID=$!
sleep 8

# ---------------------------
# Get ngrok public URL
# ---------------------------
NGROK_URL=$(curl -s http://localhost:4040/api/tunnels | jq -r '.tunnels[] | select(.proto=="https") | .public_url')

if [ -z "$NGROK_URL" ] || [ "$NGROK_URL" == "null" ]; then
  echo "❌ Failed to retrieve ngrok URL"
  exit 1
fi

echo "✅ Argo CD is available at: $NGROK_URL"
echo "Port-forward PID: $PORT_FORWARD_PID, ngrok PID: $NGROK_PID"


# ---------------------------
# Check application pods in dev namespace
# ---------------------------
echo "🔍 Checking application '$APP_NAME' in namespace '$APP_NAMESPACE'..."
kubectl get pods -n $APP_NAMESPACE -l app=$APP_NAME

APP_POD=$(kubectl get pods -n $APP_NAMESPACE -l app=$APP_NAME -o jsonpath='{.items[0].metadata.name}')

if [ -z "$APP_POD" ]; then
  echo "❌ No pods found for application $APP_NAME in $APP_NAMESPACE"
else
  echo "✅ Pod '$APP_POD' found. Checking status..."
  kubectl get pod $APP_POD -n $APP_NAMESPACE -o wide
  echo "✅ Application appears to be running."
fi

echo "🎉 Restart complete. Argo CD and $APP_NAME are up."