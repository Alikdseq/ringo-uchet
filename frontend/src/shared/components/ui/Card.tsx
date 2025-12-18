import React from "react";

interface CardProps {
  children: React.ReactNode;
  className?: string;
}

export function Card({ children, className }: CardProps) {
  return (
    <div
      className={`rounded-2xl border border-slate-200 bg-white/90 shadow-sm transition-all duration-200 hover:shadow-md ${className ?? ""}`.trim()}
    >
      {children}
    </div>
  );
}


