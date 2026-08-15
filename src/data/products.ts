export type CategorieKey = "gazon" | "revetements" | "finition" | "decor" | "panneaux";

export interface Produit {
  id: string;
  nom: string;
  categorie: string;
  categorieKey: CategorieKey;
  image: string;
  accroche: string;
  description: string;
  caracteristiques: string[];
  usages: string;
}

export const CATEGORIES: { key: CategorieKey | "tout"; label: string }[] = [
  { key: "tout", label: "Tous" },
  { key: "gazon", label: "Gazon & Sols extérieurs" },
  { key: "revetements", label: "Revêtements de sol" },
  { key: "finition", label: "Finitions & Menuiserie" },
  { key: "decor", label: "Décoration" },
  { key: "panneaux", label: "Panneaux & Bois" }
];

export const PRODUITS: Produit[] = [
  {
    id: "gazon-fillier",
    nom: "Gazon Filliér",
    categorie: "Gazon & Sols extérieurs",
    categorieKey: "gazon",
    image: "/img/gazon-fillier.svg",
    accroche:
      "Gazon synthétique haute densité pour aménagement paysager, terrasses et espaces verts.",
    description:
      "Le Gazon Filliér est un gazon synthétique premium conçu pour les espaces extérieurs : jardins, terrasses, collectivités et hôtels. Sa fibre dense et douce offre un rendu très naturel tout en restant résistant aux intempéries et au piétinement intense.",
    caracteristiques: [
      "Fibre haute densité, toucher naturel",
      "Résistant UV et intempéries",
      "Évacuation d'eau optimisée",
      "Convient aux collectivités et négoces"
    ],
    usages: "Terrasses, jardins, espaces verts, hôtels, aire de jeux"
  },
  {
    id: "gazon-sol",
    nom: "Gazon Sol (stades)",
    categorie: "Gazon & Sols extérieurs",
    categorieKey: "gazon",
    image: "/img/gazon-sol.svg",
    accroche:
      "Gazon sportif de dernière génération pour stades, terrains de football et complexes sportifs.",
    description:
      "Le Gazon Sol est un revêtement sportif professionnel certifié pour les terrains de football, stades et complexes multisports. Il garantit un excellent rebond, une absorption des chocs et une tenue parfaite dans la durée, même en usage intensif.",
    caracteristiques: [
      "Certifié pour usage sportif intensif",
      "Absorption des chocs renforcée",
      "Rebond de balle régulier",
      "Adapté stades et clubs sportifs"
    ],
    usages: "Stades, terrains de football, gymnases, terrains multisports"
  },
  {
    id: "gerflex",
    nom: "Gerflex",
    categorie: "Revêtements de sol PVC",
    categorieKey: "revetements",
    image: "/img/gerflex.svg",
    accroche:
      "Revêtement de sol PVC résistant pour locaux professionnels, tertiaires et sanitaires.",
    description:
      "Gerflex est la référence du sol PVC lourd en France. Idéal pour les hôpitaux, écoles, bureaux et locaux d'activité, il offre une excellente résistance à l'usure, un entretien facile et une très large gamme de décors.",
    caracteristiques: [
      "PVC lourd, très grande résistance",
      "Entretien facile, hygiénique",
      "Large choix de décors et coloris",
      "Usage tertiaire, médical et scolaire"
    ],
    usages: "Hôpitaux, écoles, bureaux, locaux commerciaux, cuisines"
  },
  {
    id: "seuil-cornier-plinthes",
    nom: "Seuil cornier plinthes",
    categorie: "Finitions & Menuiserie",
    categorieKey: "finition",
    image: "/img/seuil-cornier-plinthes.svg",
    accroche:
      "Seuils de porte, corniers et plinthes pour une finition soignée de vos sols.",
    description:
      "Notre gamme de seuils, corniers et plinthes assure une finition nette et durable entre les différents revêtements de sol. Disponible en PVC, aluminium et bois, elle s'adapte à tous les types de pose.",
    caracteristiques: [
      "PVC, aluminium et bois",
      "Finition nette entre les sols",
      "Facile à poser et à couper",
      "Toutes longueurs et coloris"
    ],
    usages: "Seuils de porte, raccords de sols, plinthes murales"
  },
  {
    id: "autocollant-papier",
    nom: "Autocollant papier",
    categorie: "Décoration",
    categorieKey: "decor",
    image: "/img/autocollant-papier.svg",
    accroche:
      "Papier autocollant et adhésifs décoratifs pour rénover meubles et murs sans travaux.",
    description:
      "Le papier autocollant RITEDJ DECO permet de relooker rapidement meubles, plans de travail, murs et vitrines. Large gamme de motifs, couleurs et finitions (mat, brillant, bois, béton) pour les professionnels comme les particuliers.",
    caracteristiques: [
      "Pose facile, repositionnable",
      "Grand choix de motifs et finitions",
      "Résistant et lessivable",
      "Idéal rénovation et vitrines"
    ],
    usages: "Rénovation de meubles, décoration murale, vitrines, PLV"
  },
  {
    id: "parquet",
    nom: "Parquet",
    categorie: "Revêtements de sol PVC",
    categorieKey: "revetements",
    image: "/img/parquet.svg",
    accroche:
      "Parquet massif, contrecollé ou stratifié pour un rendu chaleureux et durable.",
    description:
      "Nous proposons une large gamme de parquets massifs, contrecollés et stratifiés. Essences variées, finitions huilées ou vernies, pour particuliers et grands chantiers, avec un stock permanent pour les négoces.",
    caracteristiques: [
      "Massif, contrecollé ou stratifié",
      "Plusieurs essences et finitions",
      "Pose collée, clouée ou flottante",
      "Stock permanent pour négoces"
    ],
    usages: "Salons, chambres, bureaux, hôtels, grands chantiers"
  },
  {
    id: "mdf",
    nom: "MDF",
    categorie: "Panneaux & Bois",
    categorieKey: "panneaux",
    image: "/img/mdf.svg",
    accroche:
      "Panneaux MDF bruts, mélaminés ou hydrofuges pour menuiserie et agencement.",
    description:
      "Le MDF (panneau de fibres moyenne densité) est incontournable en menuiserie et agencement. Disponible brut, mélaminé ou hydrofuge, en plusieurs épaisseurs et formats, il se découpe et s'usine facilement.",
    caracteristiques: [
      "Brut, mélaminé ou hydrofuge",
      "Plusieurs épaisseurs et formats",
      "Usinage et découpe faciles",
      "Idéal menuiserie et agencement"
    ],
    usages: "Menuiserie, agencement de magasins, mobilier, portes"
  }
];

export function getProduit(id: string): Produit | undefined {
  return PRODUITS.find((p) => p.id === id);
}
