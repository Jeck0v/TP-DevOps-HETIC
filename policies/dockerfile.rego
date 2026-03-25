package dockerfile

# Interdire l'exécution en root
deny[msg] {
    input[i].Cmd == "user"
    val := input[i].Value
    val[_] == "root"
    msg = "Les conteneurs ne doivent pas tourner en root"
}

# Exiger un USER dans le Dockerfile
deny[msg] {
    not any_user
    msg = "Le Dockerfile doit contenir une instruction USER"
}

any_user {
    input[i].Cmd == "user"
}

# Interdire le tag :latest
deny[msg] {
    input[i].Cmd == "from"
    val := input[i].Value
    contains(val[0], ":latest")
    msg = sprintf("Éviter le tag :latest, utiliser un tag spécifique : %s", [val[0]])
}

# Exiger un HEALTHCHECK
deny[msg] {
    not any_healthcheck
    msg = "Le Dockerfile doit contenir un HEALTHCHECK"
}

any_healthcheck {
    input[i].Cmd == "healthcheck"
}
