"use client";

import React from "react";
import { AuthGuard } from "@/shared/components/auth/AuthGuard";
import { AppShell } from "@/shared/components/layout/AppShell";
import DashboardPage from "./(app)/page";

export default function RootPage() {
  return (
    <AuthGuard>
      <AppShell>
        <DashboardPage />
      </AppShell>
    </AuthGuard>
  );
}


