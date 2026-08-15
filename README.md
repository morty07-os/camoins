# RITEDJ DECO

Site vitrine pour **RITEDJ DECO**, fournisseur de revêtements de sol, gazon synthétique et matériaux pour particuliers, négoces et travaux publics.

## Stack

React 18 + TypeScript + Vite + Tailwind CSS + shadcn/ui + React Router.## Pages

- `/` — Accueil
- `/produits` — Catalogue complet avec filtres et recherche
- `/produit/:id` — Fiches produits (Gazon Filliér, Gazon Sol stades, Gerflex, Seuil cornier plinthes, Autocollant papier, Parquet, MDF)
- `/a-propos` — À propos
- `/contact` — Contact et demande de devis

## Développement

```bash
npm install
npm run dev
```

## Bundle en fichier unique

```bash
npm run bundle   # ou : bash scripts/bundle-artifact.sh (ou .ps1 sous Windows)
```

Génère `bundle.html`, un artifact HTML autonome (tous les assets inlinés)
via Vite + `vite-plugin-singlefile`.

## Déploiement

Déploiement automatique sur GitHub Pages via `.github/workflows/deploy.yml`
(à activer dans Settings → Pages → Source : GitHub Actions).

Site : https://morty07-os.github.io/2026/
