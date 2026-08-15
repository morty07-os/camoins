# Bundle le projet React en un seul fichier HTML autonome (bundle.html).
# Utilise Vite + vite-plugin-singlefile (fiable avec shadcn/radix-ui).
# Usage : powershell -File scripts/bundle-artifact.ps1

Write-Host "==> Installation des dependances de bundling..."
npm install --save-dev vite-plugin-singlefile

Write-Host "==> Build du bundle autonome..."
npx vite build --config vite.bundle.config.ts

Write-Host "==> Copie du bundle a la racine du projet..."
Copy-Item -LiteralPath "dist-bundle\index.html" -Destination "bundle.html" -Force
Remove-Item -Recurse -Force -LiteralPath "dist-bundle"

Write-Host "==> Termine : bundle.html genere a la racine du projet."
