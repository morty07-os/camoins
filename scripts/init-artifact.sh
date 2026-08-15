#!/usr/bin/env bash
# Initialise un projet frontend pour web-artifacts-builder.
# Usage : bash scripts/init-artifact.sh <project-name>
set -euo pipefail

PROJECT="${1:-ritedj-deco}"

echo "==> Création du projet ${PROJECT}..."
mkdir -p "${PROJECT}/src"
cat > "${PROJECT}/index.html" <<'EOF'
<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>RITEDJ DECO</title>
</head>
<body>
  <div id="root"></div>
  <script type="module" src="/src/main.tsx"></script>
</body>
</html>
EOF

cat > "${PROJECT}/package.json" <<'EOF'
{
  "name": "ritedj-deco",
  "private": true,
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "tsc -b && vite build",
    "preview": "vite preview",
    "bundle": "bash scripts/bundle-artifact.sh"
  }
}
EOF

echo "==> Prêt. Développez votre artifact dans ${PROJECT}/ puis lancez :"
echo "    cd ${PROJECT} && npm install"
echo "    bash scripts/bundle-artifact.sh"
