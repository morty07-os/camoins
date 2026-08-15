import { Link } from "react-router-dom";
import { ArrowRight } from "lucide-react";

import { Card, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";
import type { Produit } from "@/data/products";

interface ProductCardProps {
  produit: Produit;
  className?: string;
}

export function ProductCard({ produit, className }: ProductCardProps) {
  return (
    <Card
      className={cn(
        "group overflow-hidden transition-shadow hover:shadow-lg",
        className
      )}
    >
      <Link to={`/produit/${produit.id}`} className="block">
        <div className="aspect-[4/3] overflow-hidden bg-secondary">
          <img
            src={produit.image}
            alt={`${produit.nom} - RITEDJ DECO`}
            className="h-full w-full object-cover transition-transform duration-500 group-hover:scale-105"
            loading="lazy"
          />
        </div>
      </Link>
      <CardContent className="flex flex-col gap-2 p-5">
        <Badge variant="accent" className="w-fit text-[11px] uppercase tracking-wider">
          {produit.categorie}
        </Badge>
        <h3 className="text-lg font-bold leading-snug">
          <Link to={`/produit/${produit.id}`} className="hover:text-primary">
            {produit.nom}
          </Link>
        </h3>
        <p className="line-clamp-2 text-sm text-muted-foreground">
          {produit.accroche}
        </p>
        <div className="pt-2">
          <Button asChild variant="outline" size="sm" className="w-full">
            <Link to={`/produit/${produit.id}`}>
              Voir le produit <ArrowRight className="h-4 w-4" />
            </Link>
          </Button>
        </div>
      </CardContent>
    </Card>
  );
}
