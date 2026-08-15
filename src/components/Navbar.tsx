import { useState } from "react";
import { Link, NavLink } from "react-router-dom";
import { Menu, X, Package, MapPin, Phone, Mail } from "lucide-react";

import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";

const LINKS = [
  { to: "/", label: "Accueil" },
  { to: "/produits", label: "Produits" },
  { to: "/a-propos", label: "À propos" },
  { to: "/contact", label: "Contact" }
];

export function Navbar() {
  const [open, setOpen] = useState(false);

  return (
    <header className="sticky top-0 z-50 bg-background shadow-sm">
      <div className="bg-primary text-primary-foreground text-sm">
        <div className="mx-auto flex max-w-7xl items-center justify-between gap-4 px-4 py-1.5">
          <span className="flex items-center gap-1.5">
            <TruckIcon className="h-4 w-4" />
            Livraison disponible sur toute la région
          </span>
          <Link to="/contact" className="font-medium hover:underline">
            Demander un devis gratuit &rarr;
          </Link>
        </div>
      </div>
      <div className="mx-auto flex max-w-7xl items-center justify-between gap-4 px-4 py-3">
        <Link to="/" className="flex items-center gap-2 text-lg font-extrabold tracking-tight">
          <span className="grid h-10 w-10 place-items-center rounded-lg bg-gradient-to-br from-primary to-primary/70 text-primary-foreground">
            R
          </span>
          RITEDJ <span className="text-bois">DECO</span>
        </Link>
        <nav className="hidden items-center gap-6 md:flex" aria-label="Navigation principale">
          {LINKS.map((l) => (
            <NavLink
              key={l.to}
              to={l.to}
              end={l.to === "/"}
              className={({ isActive }) =>
                cn(
                  "border-b-2 text-sm font-semibold transition-colors",
                  isActive
                    ? "border-primary text-primary"
                    : "border-transparent text-foreground hover:text-primary"
                )
              }
            >
              {l.label}
            </NavLink>
          ))}
          <Button asChild size="sm">
            <Link to="/contact">Devis</Link>
          </Button>
        </nav>
        <Button
          variant="ghost"
          size="icon"
          className="md:hidden"
          aria-label="Ouvrir le menu"
          onClick={() => setOpen((v) => !v)}
        >
          {open ? <X className="h-5 w-5" /> : <Menu className="h-5 w-5" />}
        </Button>
      </div>
      {open && (
        <nav className="border-t bg-background md:hidden" aria-label="Navigation mobile">
          <div className="mx-auto flex max-w-7xl flex-col gap-1 px-4 py-3">
            {LINKS.map((l) => (
              <NavLink
                key={l.to}
                to={l.to}
                end={l.to === "/"}
                onClick={() => setOpen(false)}
                className={({ isActive }) =>
                  cn(
                    "rounded-md px-3 py-2 text-sm font-semibold",
                    isActive ? "bg-accent text-primary" : "text-foreground"
                  )
                }
              >
                {l.label}
              </NavLink>
            ))}
            <Button asChild size="sm" className="mt-2">
              <Link to="/contact" onClick={() => setOpen(false)}>
                Demander un devis
              </Link>
            </Button>
          </div>
        </nav>
      )}
    </header>
  );
}

function TruckIcon({ className }: { className?: string }) {
  return (
    <svg
      className={className}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      <path d="M5 18H3c-.6 0-1-.4-1-1V7c0-.6.4-1 1-1h10c.6 0 1 .4 1 1v11" />
      <path d="M14 9h4l4 4v4c0 .6-.4 1-1 1h-2" />
      <circle cx="7" cy="18" r="2" />
      <circle cx="17" cy="18" r="2" />
    </svg>
  );
}

export function Footer() {
  const produits = [
    { to: "/produit/gazon-fillier", label: "Gazon Filliér" },
    { to: "/produit/gazon-sol", label: "Gazon Sol (stades)" },
    { to: "/produit/gerflex", label: "Gerflex" },
    { to: "/produit/parquet", label: "Parquet" },
    { to: "/produit/mdf", label: "MDF" }
  ];

  return (
    <footer className="bg-[#14281a] text-[#cfe3d3]">
      <div className="mx-auto grid max-w-7xl gap-10 px-4 py-14 md:grid-cols-2 lg:grid-cols-4">
        <div>
          <Link to="/" className="flex items-center gap-2 text-lg font-extrabold text-white">
            <span className="grid h-10 w-10 place-items-center rounded-lg bg-primary text-primary-foreground">
              R
            </span>
            RITEDJ <span className="text-[#a5d6a7]">DECO</span>
          </Link>
          <p className="mt-4 text-sm leading-relaxed">
            Fournisseur de revêtements de sol, gazon synthétique et matériaux
            pour particuliers, négoces et travaux publics.
          </p>
        </div>
        <div>
          <h4 className="mb-3 font-bold text-white">Produits</h4>
          <ul className="space-y-2 text-sm">
            {produits.map((p) => (
              <li key={p.to}>
                <Link to={p.to} className="hover:text-[#a5d6a7]">
                  {p.label}
                </Link>
              </li>
            ))}
          </ul>
        </div>
        <div>
          <h4 className="mb-3 font-bold text-white">Liens utiles</h4>
          <ul className="space-y-2 text-sm">
            <li><Link to="/produits" className="hover:text-[#a5d6a7]">Tous les produits</Link></li>
            <li><Link to="/a-propos" className="hover:text-[#a5d6a7]">À propos</Link></li>
            <li><Link to="/contact" className="hover:text-[#a5d6a7]">Contact</Link></li>
            <li><Link to="/contact" className="hover:text-[#a5d6a7]">Demander un devis</Link></li>
          </ul>
        </div>
        <div>
          <h4 className="mb-3 font-bold text-white">Contact</h4>
          <ul className="space-y-2 text-sm">
            <li className="flex items-center gap-2"><Phone className="h-4 w-4" /> +213 000 000 000</li>
            <li className="flex items-center gap-2"><Mail className="h-4 w-4" /> contact@ritedjdeco.com</li>
            <li className="flex items-center gap-2"><MapPin className="h-4 w-4" /> Adresse de l'agence, Ville</li>
            <li className="flex items-center gap-2"><Package className="h-4 w-4" /> Lun - Sam : 8h00 - 18h00</li>
          </ul>
        </div>
      </div>
      <div className="border-t border-white/15">
        <div className="mx-auto flex max-w-7xl flex-wrap items-center justify-between gap-2 px-4 py-4 text-xs">
          <span>&copy; {new Date().getFullYear()} RITEDJ DECO. Tous droits réservés.</span>
          <span>Vente gros, détail &amp; travaux publics</span>
        </div>
      </div>
    </footer>
  );
}
