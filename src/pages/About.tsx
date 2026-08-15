import { Handshake, Wrench, Zap } from "lucide-react";

import { PageHeader } from "@/components/PageHeader";
import { Card, CardContent } from "@/components/ui/card";

const VALEURS = [
  {
    icone: Handshake,
    titre: "Confiance",
    texte:
      "Des produits conformes, des prix honnêtes et des engagements tenus pour chaque client."
  },
  {
    icone: Wrench,
    titre: "Expertise",
    texte:
      "Une équipe technique qui connaît les produits et vous guide vers la bonne solution."
  },
  {
    icone: Zap,
    titre: "Réactivité",
    texte:
      "Des délais de livraison respectés et des devis sous 24h ouvrées."
  }
];

const OFFRES = [
  {
    titre: "Particuliers",
    texte: "Vente au détail et conseil pour vos projets.",
    bg: "from-primary to-primary/80"
  },
  {
    titre: "Négoces & professionnels",
    texte: "Vente en gros, tarifs revendeurs, stock permanent.",
    bg: "from-bois to-[#7a5232]"
  },
  {
    titre: "Travaux publics",
    texte: "Stades, écoles, collectivités : devis et marchés.",
    bg: "from-slate-700 to-slate-900"
  }
];

export function About() {
  return (
    <main>
      <PageHeader
        title="À propos de RITEDJ DECO"
        lead="Le partenaire des particuliers, des négoces et des travaux publics."
      />

      <section className="py-16">
        <div className="mx-auto grid max-w-7xl items-center gap-10 px-4 lg:grid-cols-2">
          <div className="overflow-hidden rounded-3xl shadow">
            <img
              src="/img/gazon-sol.svg"
              alt="RITEDJ DECO - fournisseur pour travaux publics et stades"
              className="h-full w-full object-cover"
            />
          </div>
          <div>
            <h2 className="text-2xl font-extrabold tracking-tight sm:text-3xl">
              Notre histoire
            </h2>
            <div className="mt-4 space-y-4 text-muted-foreground">
              <p>
                RITEDJ DECO est une entreprise spécialisée dans la distribution
                de revêtements de sol, de gazon synthétique et de matériaux de
                finition. Nous accompagnons aussi bien les particuliers souhaitant
                rénover leur intérieur que les professionnels du bâtiment, les
                négoces et les collectivités engagés dans des travaux publics.
              </p>
              <p>
                Notre force réside dans notre double positionnement : la
                <strong className="text-foreground"> vente en gros</strong> pour
                les revendeurs et artisans, la
                <strong className="text-foreground"> vente au détail</strong> pour
                les particuliers, et une offre dédiée aux
                <strong className="text-foreground"> marchés publics</strong>{" "}
                (stades, écoles, espaces verts).
              </p>
              <p>
                Grâce à un stock permanent, des livraisons fiables et un conseil
                technique personnalisé, nous nous imposons comme un partenaire de
                confiance pour tous vos projets.
              </p>
            </div>
          </div>
        </div>
      </section>

      <section className="bg-secondary/40 py-16">
        <div className="mx-auto max-w-7xl px-4">
          <h2 className="text-center text-2xl font-extrabold tracking-tight sm:text-3xl">
            Ce qui nous anime au quotidien
          </h2>
          <div className="mt-10 grid gap-5 md:grid-cols-3">
            {VALEURS.map((v) => (
              <Card key={v.titre} className="rounded-2xl">
                <CardContent className="flex flex-col items-center gap-2 p-8 text-center">
                  <span className="grid h-14 w-14 place-items-center rounded-xl bg-primary/10 text-primary">
                    <v.icone className="h-7 w-7" />
                  </span>
                  <h3 className="text-lg font-bold">{v.titre}</h3>
                  <p className="text-sm text-muted-foreground">{v.texte}</p>
                </CardContent>
              </Card>
            ))}
          </div>
        </div>
      </section>

      <section className="py-16">
        <div className="mx-auto max-w-7xl px-4">
          <h2 className="text-center text-2xl font-extrabold tracking-tight sm:text-3xl">
            Trois clientèles, un même service
          </h2>
          <div className="mt-10 grid gap-5 md:grid-cols-3">
            {OFFRES.map((o) => (
              <div
                key={o.titre}
                className={`flex min-h-[200px] items-end rounded-2xl bg-gradient-to-br ${o.bg} p-6 text-white shadow`}
              >
                <div>
                  <h3 className="text-lg font-extrabold">{o.titre}</h3>
                  <p className="mt-1 text-sm text-white/85">{o.texte}</p>
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>
    </main>
  );
}
