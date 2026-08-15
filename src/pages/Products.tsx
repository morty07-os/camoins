import { useMemo, useState } from "react";
import { Search, SearchX } from "lucide-react";

import { PageHeader } from "@/components/PageHeader";
import { ProductCard } from "@/components/ProductCard";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";
import { CATEGORIES, PRODUITS, type CategorieKey } from "@/data/products";

export function Products() {
  const [filtre, setFiltre] = useState<CategorieKey | "tout">("tout");
  const [recherche, setRecherche] = useState("");

  const resultats = useMemo(() => {
    const q = recherche.toLowerCase().trim();
    return PRODUITS.filter((p) => {
      const okCat = filtre === "tout" || p.categorieKey === filtre;
      const okTexte =
        !q ||
        p.nom.toLowerCase().includes(q) ||
        p.categorie.toLowerCase().includes(q) ||
        p.accroche.toLowerCase().includes(q);
      return okCat && okTexte;
    });
  }, [filtre, recherche]);

  return (
    <main>
      <PageHeader
        title="Nos produits"
        lead="Toute la gamme RITEDJ DECO pour les particuliers, les négoces et les travaux publics."
      />

      <section className="py-12">
        <div className="mx-auto max-w-7xl px-4">
          <div className="mx-auto mb-6 max-w-md">
            <div className="relative">
              <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
              <Input
                type="search"
                placeholder="Rechercher un produit... (gazon, parquet, MDF, plinthe...)"
                value={recherche}
                onChange={(e) => setRecherche(e.target.value)}
                className="pl-9"
                aria-label="Rechercher un produit"
              />
            </div>
          </div>

          <div className="mb-8 flex flex-wrap justify-center gap-2" role="group" aria-label="Filtrer les produits">
            {CATEGORIES.map((c) => (
              <Button
                key={c.key}
                variant={filtre === c.key ? "default" : "outline"}
                size="sm"
                onClick={() => setFiltre(c.key)}
                className={cn("rounded-full", filtre === c.key && "bg-primary")}
              >
                {c.label}
              </Button>
            ))}
          </div>

          {resultats.length > 0 ? (
            <div className="grid gap-5 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
              {resultats.map((p) => (
                <ProductCard key={p.id} produit={p} />
              ))}
            </div>
          ) : (
            <div className="flex flex-col items-center gap-3 py-20 text-center">
              <SearchX className="h-10 w-10 text-muted-foreground" />
              <p className="font-semibold text-muted-foreground">
                Aucun produit ne correspond à votre recherche.
              </p>
            </div>
          )}
        </div>
      </section>
    </main>
  );
}
