#!/usr/bin/env bash
# Bundle le projet React en un seul fichier HTML autonome (bundle.html).
# Utilise Vite + vite-plugin-singlefile (fiable avec shadcn/radix-ui).
set -euo pipefail

echo "==> Installation des dépendances de bundling..."
npm install --save-dev vite-plugin-singlefile

echo "==> Build du bundle autonome..."
npx vite build --config vite.bundle.config.ts

echo "==> Copie du bundle à la racine du projet..."
cp dist-bundle/index.html bundle.html
rm -rf dist-bundle

echo "==> Terminé : bundle.html généré à la racine du projet."
