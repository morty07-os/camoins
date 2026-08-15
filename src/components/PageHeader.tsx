import type { ReactNode } from "react";

interface PageHeaderProps {
  title: string;
  lead?: string;
  children?: ReactNode;
}

export function PageHeader({ title, lead, children }: PageHeaderProps) {
  return (
    <section className="bg-gradient-to-br from-primary via-primary to-[#0f3d12] py-16 text-primary-foreground">
      <div className="mx-auto max-w-7xl px-4 text-center">
        <h1 className="text-3xl font-extrabold tracking-tight sm:text-4xl">{title}</h1>
        {lead && (
          <p className="mx-auto mt-3 max-w-2xl text-sm text-primary-foreground/85 sm:text-base">
            {lead}
          </p>
        )}
        {children}
      </div>
    </section>
  );
}
