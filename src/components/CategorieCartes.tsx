import { Link } from "react-router-dom";
import { ArrowRight } from "lucide-react";
import { cn } from "@/lib/utils";

const CATEGORIE_CARTES = [
  {
    titre: "Gazon & Sols extérieurs",
    sous: "Gazon Filliér, stades",
    image: "/img/gazon-fillier.svg",
    className: "from-primary/90 to-primary"
  },
  {
    titre: "Revêtements de sol PVC",
    sous: "Gerflex, Parquet",
    image: "/img/gerflex.svg",
    className: "from-bois/90 to-[#7a5232]"
  },
  {
    titre: "Finitions & Menuiserie",
    sous: "Seuils, corniers, plinthes",
    image: "/img/seuil-cornier-plinthes.svg",
    className: "from-slate-700 to-slate-900"
  },
  {
    titre: "Panneaux & Bois",
    sous: "MDF, Autocollant papier",
    image: "/img/mdf.svg",
    className: "from-[#8a6d3b] to-[#5d4a23]"
  }
];

export function CategorieCartes() {
  return (
    <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
      {CATEGORIE_CARTES.map((c) => (
        <Link
          key={c.titre}
          to="/produits"
          className={cn(
            "group relative flex aspect-[4/3] items-end overflow-hidden rounded-2xl bg-gradient-to-br text-white shadow transition-transform hover:-translate-y-0.5",
            c.className
          )}
        >
          <img
            src={c.image}
            alt={c.titre}
            className="absolute inset-0 h-full w-full object-cover opacity-40 transition-opacity group-hover:opacity-30"
            loading="lazy"
          />
          <div className="relative z-10 flex w-full items-end justify-between gap-2 p-5">
            <div>
              <h3 className="font-bold leading-snug">{c.titre}</h3>
              <p className="text-xs opacity-90">{c.sous}</p>
            </div>
            <ArrowRight className="h-5 w-5 shrink-0 transition-transform group-hover:translate-x-1" />
          </div>
        </Link>
      ))}
    </div>
  );
}
