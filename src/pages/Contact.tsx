import { useState, type FormEvent } from "react";
import { Phone, Mail, MapPin, Clock, CheckCircle2 } from "lucide-react";

import { PageHeader } from "@/components/PageHeader";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue
} from "@/components/ui/select";
import { Card, CardContent } from "@/components/ui/card";
import { PRODUITS } from "@/data/products";

const COORDS = [
  { icone: Phone, titre: "Téléphone", texte: "+213 000 000 000" },
  { icone: Mail, titre: "Email", texte: "contact@ritedjdeco.com" },
  { icone: MapPin, titre: "Adresse", texte: "Adresse de l'agence, Ville" },
  { icone: Clock, titre: "Horaires", texte: "Lun - Sam : 8h00 - 18h00" }
];

const TYPES_CLIENT = [
  "Particulier",
  "Négoce / revendeur",
  "Artisan / entreprise BTP",
  "Collectivité / travaux publics"
];

export function Contact() {
  const [envoye, setEnvoye] = useState(false);

  function handleSubmit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setEnvoye(true);
    e.currentTarget.reset();
    setTimeout(() => setEnvoye(false), 6000);
  }

  return (
    <main>
      <PageHeader
        title="Contactez-nous"
        lead="Demandez un devis gratuit et personnalisé sous 24h ouvrées."
      />

      <section className="py-12">
        <div className="mx-auto grid max-w-7xl gap-12 px-4 lg:grid-cols-2">
          <div>
            <h2 className="text-2xl font-extrabold tracking-tight">Demande de devis</h2>
            <p className="mt-2 text-sm text-muted-foreground">
              Précisez votre besoin (produit, quantités, type de client) et notre
              équipe vous répond rapidement.
            </p>

            {envoye && (
              <div className="mt-4 flex items-center gap-2 rounded-lg border border-primary bg-[#e8f5e9] px-4 py-3 text-sm font-semibold text-primary">
                <CheckCircle2 className="h-5 w-5" />
                Merci ! Votre demande a bien été envoyée. Notre équipe vous
                recontacte rapidement.
              </div>
            )}

            <form onSubmit={handleSubmit} className="mt-6 space-y-4">
              <div className="grid gap-4 sm:grid-cols-2">
                <div>
                  <label htmlFor="nom" className="mb-1.5 block text-sm font-semibold">
                    Nom complet *
                  </label>
                  <Input id="nom" name="nom" required placeholder="Votre nom" />
                </div>
                <div>
                  <label htmlFor="societe" className="mb-1.5 block text-sm font-semibold">
                    Société (optionnel)
                  </label>
                  <Input id="societe" name="societe" placeholder="Nom de l'entreprise" />
                </div>
              </div>
              <div className="grid gap-4 sm:grid-cols-2">
                <div>
                  <label htmlFor="email" className="mb-1.5 block text-sm font-semibold">
                    Email *
                  </label>
                  <Input id="email" name="email" type="email" required placeholder="vous@email.com" />
                </div>
                <div>
                  <label htmlFor="tel" className="mb-1.5 block text-sm font-semibold">
                    Téléphone *
                  </label>
                  <Input id="tel" name="tel" type="tel" required placeholder="+213 ..." />
                </div>
              </div>
              <div className="grid gap-4 sm:grid-cols-2">
                <div>
                  <label htmlFor="type" className="mb-1.5 block text-sm font-semibold">
                    Type de client
                  </label>
                  <Select name="type">
                    <SelectTrigger id="type" className="w-full">
                      <SelectValue placeholder="Sélectionner" />
                    </SelectTrigger>
                    <SelectContent>
                      {TYPES_CLIENT.map((t) => (
                        <SelectItem key={t} value={t}>
                          {t}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
                <div>
                  <label htmlFor="produit" className="mb-1.5 block text-sm font-semibold">
                    Produit concerné
                  </label>
                  <Select name="produit">
                    <SelectTrigger id="produit" className="w-full">
                      <SelectValue placeholder="Sélectionner" />
                    </SelectTrigger>
                    <SelectContent>
                      {PRODUITS.map((p) => (
                        <SelectItem key={p.id} value={p.nom}>
                          {p.nom}
                        </SelectItem>
                      ))}
                      <SelectItem value="autre">Autre / plusieurs produits</SelectItem>
                    </SelectContent>
                  </Select>
                </div>
              </div>
              <div>
                <label htmlFor="message" className="mb-1.5 block text-sm font-semibold">
                  Votre message *
                </label>
                <Textarea
                  id="message"
                  name="message"
                  required
                  rows={5}
                  placeholder="Quantités, dimensions, délais, lieu du chantier..."
                />
              </div>
              <Button type="submit" size="lg">
                Envoyer ma demande
              </Button>
            </form>
          </div>

          <div>
            <h2 className="text-2xl font-extrabold tracking-tight">Nos coordonnées</h2>
            <div className="mt-6 grid gap-4 sm:grid-cols-2">
              {COORDS.map((c) => (
                <Card key={c.titre} className="rounded-2xl">
                  <CardContent className="p-5">
                    <span className="grid h-11 w-11 place-items-center rounded-lg bg-primary/10 text-primary">
                      <c.icone className="h-5 w-5" />
                    </span>
                    <h3 className="mt-3 text-sm font-bold">{c.titre}</h3>
                    <p className="mt-0.5 text-sm text-muted-foreground">{c.texte}</p>
                  </CardContent>
                </Card>
              ))}
            </div>

            <div className="mt-4 overflow-hidden rounded-2xl border shadow-sm">
              <iframe
                title="Localisation RITEDJ DECO"
                src="https://www.openstreetmap.org/export/embed.html?bbox=2.90%2C36.65%2C3.20%2C36.85&layer=mapnik&marker=36.75%2C3.05"
                width="100%"
                height="260"
                style={{ border: 0 }}
                loading="lazy"
              />
            </div>

            <Card className="mt-4 rounded-2xl bg-secondary/60">
              <CardContent className="p-6">
                <h3 className="text-base font-bold">Vous êtes un professionnel ?</h3>
                <p className="mt-1 text-sm text-muted-foreground">
                  Tarifs dégressifs, facilités pour les négoces et réponse rapide
                  sur les marchés publics.
                </p>
              </CardContent>
            </Card>
          </div>
        </div>
      </section>
    </main>
  );
}
