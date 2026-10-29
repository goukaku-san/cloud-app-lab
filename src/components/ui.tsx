"use client";

import Link from "next/link";
import type { ButtonHTMLAttributes, ReactNode } from "react";

type Variant = "primary" | "secondary" | "ghost" | "danger";
type Size = "md" | "sm";

const SIZE_CLASS: Record<Size, string> = {
  md: "min-h-12 px-5 text-base",
  sm: "min-h-11 px-2 text-sm",
};

const VARIANT_CLASS: Record<Variant, string> = {
  primary: "bg-terracotta text-white hover:bg-terracotta-deep",
  secondary: "bg-paper text-ink border border-line hover:bg-white",
  ghost: "text-ink-soft hover:bg-paper",
  danger: "bg-white text-terracotta-deep border border-terracotta hover:bg-paper",
};

const BASE_CLASS =
  "inline-flex items-center justify-center rounded-2xl font-semibold transition-colors focus-visible:outline-3 focus-visible:outline-offset-2 focus-visible:outline-dusk disabled:opacity-50";

export function Button({
  variant = "primary",
  size = "md",
  className = "",
  ...props
}: ButtonHTMLAttributes<HTMLButtonElement> & { variant?: Variant; size?: Size }) {
  return <button className={`${BASE_CLASS} ${SIZE_CLASS[size]} ${VARIANT_CLASS[variant]} ${className}`} {...props} />;
}

export function LinkButton({
  href,
  variant = "secondary",
  size = "md",
  className = "",
  children,
}: {
  href: string;
  variant?: Variant;
  size?: Size;
  className?: string;
  children: ReactNode;
}) {
  return (
    <Link href={href} className={`${BASE_CLASS} ${SIZE_CLASS[size]} ${VARIANT_CLASS[variant]} ${className}`}>
      {children}
    </Link>
  );
}

export function PageShell({
  title,
  children,
  backHref,
  backLabel = "戻る",
}: {
  title: string;
  children: ReactNode;
  backHref?: string;
  backLabel?: string;
}) {
  return (
    <div className="mx-auto flex min-h-dvh w-full max-w-md flex-col px-4 pb-10 pt-3">
      <header className="flex items-center gap-2 py-2">
        {backHref ? (
          <Link
            href={backHref}
            className="rounded-full px-3 py-2 text-sm text-ink-soft hover:bg-paper focus-visible:outline-3 focus-visible:outline-offset-2 focus-visible:outline-dusk"
          >
            ← {backLabel}
          </Link>
        ) : null}
        <h1 className="text-xl font-bold">{title}</h1>
      </header>
      <main className="flex flex-1 flex-col gap-4">{children}</main>
    </div>
  );
}

export function Card({ children, className = "" }: { children: ReactNode; className?: string }) {
  return <section className={`rounded-3xl border border-line bg-paper p-4 shadow-sm ${className}`}>{children}</section>;
}

export function Note({ children, role }: { children: ReactNode; role?: string }) {
  return (
    <p role={role} className="text-sm leading-relaxed text-ink-soft">
      {children}
    </p>
  );
}

export function Loading({ text = "鏡を磨いています…" }: { text?: string }) {
  return (
    <div className="flex min-h-dvh items-center justify-center">
      <p role="status" className="text-ink-soft">
        {text}
      </p>
    </div>
  );
}
