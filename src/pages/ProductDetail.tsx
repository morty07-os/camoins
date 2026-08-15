import { Link, Navigate, useParams } from "react-router-dom";
import { ArrowRight, ChevronRight, Check } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { getProduit, PRODUITS } from "@/data/products";

export function ProductDetail() {
  const { id } = useParams<{ id: string }>();
  const produit = id ? getProduit(id) : undefined;

  if (!produit) {
    return <Navigate to="/produits" replace />;
  }

  const suggestions = PRODUITS.filter(
    (p) => p.id !== produit.id && p.categorieKey === produit.categorieKey
  ).slice(0, 3);
  const complement = suggestions.length
    ? suggestions
    : PRODUITS.filter((p) => p.id !== produit.id).slice(0, 3);

  return (
    <main className="py-10">
      <div className="mx-auto max-w-7xl px-4">
        {/* Fil d'Ariane */}
        <nav
          className="mb-6 flex flex-wrap items-center gap-1 text-sm text-muted-foreground"
          aria-label="Fil d'Ariane"
        >
          <Link to="/" className="hover:text-primary">Accueil</Link>
          <ChevronRight className="h-4 w-4" />
          <Link to="/produits" className="hover:text-primary">Produits</Link>
          <ChevronRight className="h-4 w-4" />
          <span className="font-semibold text-foreground">{produit.nom}</span>
        </nav>

        <div className="grid gap-10 lg:grid-cols-2">
          <div className="overflow-hidden rounded-3xl bg-secondary shadow-sm">
            <img
              src={produit.image}
              alt={`${produit.nom} - RITEDJ DECO`}
              className="h-full w-full object-cover"
            />
          </div>

          <div>
            <Badge variant="accent" className="text-xs uppercase tracking-wider">
              {produit.categorie}
            </Badge>
            <h1 className="mt-3 text-3xl font-extrabold tracking-tight sm:text-4xl">
              {produit.nom}
            </h1>
            <p className="mt-4 leading-relaxed">{produit.description}</p>

            <h2 className="mt-6 text-base font-bold">Caractéristiques</h2>
            <ul className="mt-3 space-y-2">
              {produit.caracteristiques.map((c) => (
                <li key={c} className="flex items-start gap-2 text-sm">
                  <Check className="mt-0.5 h-4 w-4 shrink-0 text-primary" />
                  {c}
                </li>
              ))}
            </ul>

            <p className="mt-6 text-sm">
              <span className="font-bold">Usages :</span> {produit.usages}
            </p>
            <p className="text-sm">
              <span className="font-bold">Disponibilité :</span> Gros, détail &amp;
              travaux publics
            </p>

            <Card className="mt-8 rounded-2xl bg-secondary/60">
              <CardContent className="p-6">
                <h2 className="text-lg font-bold">Prix sur devis</h2>
                <p className="mt-1 text-sm text-muted-foreground">
                  Tarifs dégressifs selon les quantités. Contactez-nous pour un
                  devis gratuit sous 24h ouvrées.
                </p>
                <Button asChild size="lg" className="mt-4">
                  <Link to="/contact">
                    Demander un devis <ArrowRight className="h-4 w-4" />
                  </Link>
                </Button>
              </CardContent>
            </Card>
          </div>
        </div>

        {/* Suggestions */}
        <section className="mt-16">
          <h2 className="mb-6 text-xl font-extrabold tracking-tight">
            Produits complémentaires
          </h2>
          <div className="grid gap-5 sm:grid-cols-2 lg:grid-cols-3">
            {complement.map((p) => (
              <Card key={p.id} className="group overflow-hidden rounded-2xl transition-shadow hover:shadow-lg">
                <Link to={`/produit/${p.id}`} className="block">
                  <div className="aspect-[16/10] overflow-hidden bg-secondary">
                    <img
                      src={p.image}
                      alt={p.nom}
                      className="h-full w-full object-cover transition-transform duration-500 group-hover:scale-105"
                      loading="lazy"
                    />
                  </div>
                </Link>
                <CardContent className="flex items-center justify-between gap-3 p-5">
                  <div>
                    <span className="text-xs font-bold uppercase tracking-wider text-primary">
                      {p.categorie}
                    </span>
                    <h3 className="text-base font-bold">
                      <Link to={`/produit/${p.id}`} className="hover:text-primary">
                        {p.nom}
                      </Link>
                    </h3>
                  </div>
                  <Button asChild variant="ghost" size="icon" aria-label={`Voir ${p.nom}`}>
                    <Link to={`/produit/${p.id}`}>
                      <ArrowRight className="h-4 w-4" />
                    </Link>
                  </Button>
                </CardContent>
              </Card>
            ))}
          </div>
        </section>
      </div>
    </main>
  );
}
