#!/bin/bash

set -e

# Charger les variables
set -a          # active l'export automatique pour toutes les variables définies
source ../.env     # ou . .env
set +a          # désactive l'export automatique

echo "🚀 Installation de l'environnement Kubernetes + Argo CD"

if ! command -v docker &> /dev/null; then
  echo "📦 Installation de Docker"
  curl -fsSL https://get.docker.com | sh
  sudo usermod -aG docker $USER
else
  echo "✅ Docker déjà installé"
fi

if ! command -v kubectl &> /dev/null; then
  echo "📦 Installation de kubectl"
  curl -LO "https://dl.k8s.io/release/$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  chmod +x kubectl
  sudo mv kubectl /usr/local/bin/
else
  echo "✅ kubectl déjà installé"
fi

if ! command -v k3d &> /dev/null; then
  echo "📦 Installation de k3d"
  curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
else
  echo "✅ k3d déjà installé"
fi


echo "Cluster name à créer : $CLUSTER_NAME"
if ! k3d cluster list | grep -q $CLUSTER_NAME; then
  echo "☸️ Création du cluster k3d"
  k3d cluster create $CLUSTER_NAME \
    --port "8080:80@loadbalancer" \
    --port "8443:443@loadbalancer"
else
  echo "✅ Cluster k3d déjà existant"
fi

kubectl config use-context k3d-$CLUSTER_NAME


echo "📦 Installation d'Argo CD"

kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "⏳ Attente du démarrage d'Argo CD"
kubectl wait --for=condition=available deployment/argocd-server \
  -n argocd --timeout=180s


echo "🔐 Configuration du mot de passe Argo CD"

HASHED_PASSWORD=$(htpasswd -nbBC 10 "" $ARGOCD_PASSWORD | tr -d ':\n')

kubectl patch secret argocd-secret -n argocd \
  -p "{\"stringData\": {
    \"admin.password\": \"$HASHED_PASSWORD\",
    \"admin.passwordMtime\": \"$(date +%FT%T%Z)\"
  }}"


echo "🔍 Vérification de l'installation de l'Ingress Controller NGINX..."

if kubectl get namespace ingress-nginx &> /dev/null; then
  echo "✅ Namespace ingress-nginx déjà présent"
else
  echo "📦 Installation de l'Ingress Controller NGINX..."
  kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.14.1/deploy/static/provider/cloud/deploy.yaml
fi


echo "⏳ Attente du contrôleur Ingress NGINX..."
kubectl wait --namespace ingress-nginx \
  --for=condition=Ready pods \
  --all \
  --timeout=180s

echo "✅ Ingress NGINX opérationnel"

echo "🔹 Liste des pods Ingress NGINX pour vérification:"
kubectl get pods -n ingress-nginx

echo "🔹 Création de l'Ingress pour Argo CD..."
echo "🔹 Application de l'Ingress Argo CD depuis argocd/ingress.yaml..."
kubectl apply -f ../argocd/ingress.yaml


echo "🔹 Vérification que l'Ingress Argo CD est créé..."
kubectl get ingress -n argocd