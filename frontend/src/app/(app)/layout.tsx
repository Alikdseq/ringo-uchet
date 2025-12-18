import React from "react";
import { AppShell } from "@/shared/components/layout/AppShell";
import { AuthGuard } from "@/shared/components/auth/AuthGuard";

export default function AppLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <AuthGuard>
      <AppShell>{children}</AppShell>
    </AuthGuard>
  );
}
