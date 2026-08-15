import { Link } from "react-router-dom";
import {
  ArrowRight,
  Truck,
  BadgeDollarSign,
  Boxes,
  Handshake
} from "lucide-react";

import { Button } from "@/components/ui/button";
import { ProductCard } from "@/components/ProductCard";
import { CategorieCartes } from "@/components/CategorieCartes";
import { Card, CardContent } from "@/components/ui/card";
import { PRODUITS } from "@/data/products";

const ATOUTS = [
  {
    icone: Truck,
    titre: "Livraison chantier",
    texte: "Livraison directe sur vos chantiers et magasins selon vos délais."
  },
  {
    icone: BadgeDollarSign,
    titre: "Prix compétitifs",
    texte: "Tarifs négociants pour la revente et prix de gros pour vos chantiers."
  },
  {
    icone: Boxes,
    titre: "Stock permanent",
    texte: "Disponibilité régulière sur toute la gamme : sols, gazon, panneaux."
  },
  {
    icone: Handshake,
    titre: "Conseil expert",
    texte: "Un accompagnement technique pour choisir le bon produit pour chaque usage."
  }
];

const TEMOIGNAGES = [
  {
    texte:
      "Nous approvisionnons notre négoce en gazon et parquet. Livraisons fiables et prix très intéressants pour la revente.",
    qui: "Gérant de négoce - revêtements de sol"
  },
  {
    texte:
      "Le gazon Sol a parfaitement répondu à notre cahier des charges pour le stade municipal. Un accompagnement au top.",
    qui: "Mairie - services travaux publics"
  },
  {
    texte:
      "Très bon conseil pour le choix de mon sol PVC Gerflex. Pose simple et rendu magnifique. Je recommande.",
    qui: "Particulier - rénovation complète"
  }
];

export function Home() {
  const phares = PRODUITS.slice(0, 4);

  return (
    <main>
      {/* Hero */}
      <section className="bg-gradient-to-br from-primary via-primary to-[#0f3d12] text-primary-foreground">
        <div className="mx-auto grid max-w-7xl items-center gap-10 px-4 py-16 lg:grid-cols-2 lg:py-20">
          <div>
            <h1 className="text-3xl font-extrabold leading-tight tracking-tight sm:text-4xl lg:text-5xl">
              Votre partenaire <span className="text-[#a5d6a7]">revêtements de sol</span> et
              matériaux
            </h1>
            <p className="mt-4 max-w-xl text-base text-primary-foreground/85">
              RITEDJ DECO fournit particuliers, négoces et collectivités : gazon
              synthétique, sol PVC Gerflex, parquet, MDF, plinthes et autocollants.
              Gros, détail et travaux publics.
            </p>
            <div className="mt-6 flex flex-wrap gap-3">
              <Button asChild size="lg" variant="light">
                <Link to="/produits">Voir nos produits</Link>
              </Button>
              <Button
                asChild
                size="lg"
                variant="outline"
                className="border-white/70 text-primary-foreground hover:bg-white/10 hover:text-primary-foreground"
              >
                <Link to="/contact">Demander un devis</Link>
              </Button>
            </div>
            <ul className="mt-8 grid grid-cols-1 gap-2 sm:grid-cols-2">
              {[
                "Prix négociants & particuliers",
                "Stock permanent",
                "Fournisseur travaux publics",
                "Conseil & accompagnement chantier"
              ].map((t) => (
                <li
                  key={t}
                  className="rounded-lg bg-white/10 px-3 py-2 text-sm font-medium"
                >
                  <span className="mr-2 text-[#a5d6a7]">&#10003;</span>
                  {t}
                </li>
              ))}
            </ul>
          </div>
          <div className="grid grid-cols-2 gap-4">
            {phares.slice(0, 4).map((p) => (
              <Link
                key={p.id}
                to={`/produit/${p.id}`}
                className="overflow-hidden rounded-2xl bg-white shadow-lg transition-transform hover:-translate-y-1"
              >
                <img
                  src={p.image}
                  alt={p.nom}
                  className="aspect-square w-full object-cover"
                  loading="lazy"
                />
              </Link>
            ))}
          </div>
        </div>
      </section>

      {/* Atouts */}
      <section className="bg-[#f0f7f1] py-16">
        <div className="mx-auto max-w-7xl px-4">
          <h2 className="text-center text-2xl font-extrabold tracking-tight sm:text-3xl">
            Un service pensé pour les professionnels
          </h2>
          <div className="mt-10 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
            {ATOUTS.map((a) => (
              <Card key={a.titre} className="rounded-2xl">
                <CardContent className="flex flex-col items-center gap-2 p-6 text-center">
                  <span className="grid h-12 w-12 place-items-center rounded-xl bg-primary/10 text-primary">
                    <a.icone className="h-6 w-6" />
                  </span>
                  <h3 className="text-base font-bold">{a.titre}</h3>
                  <p className="text-sm text-muted-foreground">{a.texte}</p>
                </CardContent>
              </Card>
            ))}
          </div>
        </div>
      </section>

      {/* Produits phares */}
      <section className="py-16">
        <div className="mx-auto max-w-7xl px-4">
          <div className="mb-10 flex flex-wrap items-end justify-between gap-4">
            <div>
              <span className="text-xs font-bold uppercase tracking-widest text-primary">
                Catalogue
              </span>
              <h2 className="mt-1 text-2xl font-extrabold tracking-tight sm:text-3xl">
                Nos produits phares
              </h2>
            </div>
            <Button asChild variant="outline">
              <Link to="/produits">
                Voir tout le catalogue <ArrowRight className="h-4 w-4" />
              </Link>
            </Button>
          </div>
          <div className="grid gap-5 sm:grid-cols-2 lg:grid-cols-4">
            {phares.map((p) => (
              <ProductCard key={p.id} produit={p} />
            ))}
          </div>
        </div>
      </section>

      {/* Catégories */}
      <section className="bg-secondary/40 py-16">
        <div className="mx-auto max-w-7xl px-4">
          <h2 className="text-center text-2xl font-extrabold tracking-tight sm:text-3xl">
            Explorez par catégorie
          </h2>
          <div className="mt-10">
            <CategorieCartes />
          </div>
        </div>
      </section>

      {/* Témoignages */}
      <section className="py-16">
        <div className="mx-auto max-w-7xl px-4">
          <h2 className="text-center text-2xl font-extrabold tracking-tight sm:text-3xl">
            Ce que disent nos clients
          </h2>
          <div className="mt-10 grid gap-5 md:grid-cols-3">
            {TEMOIGNAGES.map((t) => (
              <Card key={t.qui} className="rounded-2xl">
                <CardContent className="flex h-full flex-col gap-3 p-6">
                  <div className="text-amber-500" aria-label="5 étoiles">
                    &#9733;&#9733;&#9733;&#9733;&#9733;
                  </div>
                  <p className="text-sm italic leading-relaxed">&laquo; {t.texte} &raquo;</p>
                  <p className="mt-auto text-sm font-bold">{t.qui}</p>
                </CardContent>
              </Card>
            ))}
          </div>
        </div>
      </section>

      {/* Bandeau devis */}
      <section className="bg-gradient-to-r from-bois to-[#7a5232] py-14 text-white">
        <div className="mx-auto flex max-w-7xl flex-wrap items-center justify-between gap-6 px-4">
          <div>
            <h2 className="text-2xl font-extrabold tracking-tight">
              Un projet de sols ou de travaux publics ?
            </h2>
            <p className="mt-1 text-white/85">
              Recevez un devis gratuit et personnalisé sous 24h ouvrées.
            </p>
          </div>
          <Button asChild size="lg" variant="light">
            <Link to="/contact">Demander un devis</Link>
          </Button>
        </div>
      </section>
    </main>
  );
}
