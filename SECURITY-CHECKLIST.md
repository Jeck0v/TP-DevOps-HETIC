# Checklist Sécurité DevOps

## Images Docker
- [ ] Base image minimale (alpine)
- [ ] Pas de tag :latest
- [ ] User non-root
- [ ] HEALTHCHECK présent
- [ ] Scan Trivy sans vulnérabilité critique
- [ ] .dockerignore complet

## Kubernetes
- [ ] Resource limits sur chaque conteneur
- [ ] Pas de conteneur privilégié
- [ ] NetworkPolicies en place
- [ ] Secrets via Secret Manager (pas en clair)
- [ ] RBAC configuré

## Pipeline
- [ ] Secrets dans GitHub Secrets (pas dans le code)
- [ ] Scan de dépendances automatique
- [ ] Scan d'image automatique
- [ ] Détection de secrets (gitleaks)
- [ ] Environnements avec protection

## Infrastructure
- [ ] State Terraform chiffré
- [ ] Pas de credentials en dur dans les fichiers IaC
- [ ] Principe du moindre privilège (IAM)
