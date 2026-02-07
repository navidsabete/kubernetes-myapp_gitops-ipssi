# Kubernetes CI/CD - IPSSI

## Infrastructure Kubernetes avec Argo CD

Ce projet met en place une infrastructure Kubernetes pour l'intégration continue d'une application Docker.

### Contenu

- Création d'un cluster Kubernetes
- Installation et onfiguration des services Docker, Argo CD, ngrok, etc.
- Création de deux namespaces :
  - `argocd` : pour Argo CD
  - `dev` : pour l'application
- Configuration d’Argo CD avec mot de passe spécifique
- Exposition des services via ngrok
- Application déployée sur un dépôt Docker Hub


### Fichiers clés

- `install_vm.sh` : installe les services nécessaires, crée le cluster et configure Argo CD + ngrok
- `webhook.sh` : configure un webhook GitHub pour déclencher des déploiements automatiques