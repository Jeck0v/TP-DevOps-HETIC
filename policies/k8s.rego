package kubernetes

# Interdire les conteneurs privilégiés
deny[msg] {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    container.securityContext.privileged == true
    msg = sprintf("Le conteneur %s ne doit pas être privilégié", [container.name])
}

# Exiger des resource limits
deny[msg] {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    not container.resources.limits
    msg = sprintf("Le conteneur %s doit avoir des resource limits", [container.name])
}

# Interdire les images sans tag ou avec :latest
deny[msg] {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    not contains(container.image, ":")
    msg = sprintf("L'image %s doit avoir un tag spécifique", [container.image])
}

deny[msg] {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    endswith(container.image, ":latest")
    msg = sprintf("L'image %s ne doit pas utiliser le tag :latest", [container.image])
}
