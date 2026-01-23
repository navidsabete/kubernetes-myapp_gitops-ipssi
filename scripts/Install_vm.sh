#!/bin/bash

set -e

# Charger les variables
set -a          # active l'export automatique pour toutes les variables définies
source ../.env     # ou . .env
set +a          # désactive l'export automatique

# Utilisation
echo "Cluster name: $CLUSTER_NAME"

echo "🚀 Installation de l'environnement Kubernetes + Argo CD"

if ! command -v docker &> /dev/null; then
  echo "📦 Installation de Docker"
  curl -fsSL https://get.docker.com | sh
  sudo usermod -aG docker $USER
else
  echo "✅ Docker déjà installé"
fi