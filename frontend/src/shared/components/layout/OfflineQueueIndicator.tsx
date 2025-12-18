"use client";

import React, { useEffect, useState } from "react";
import Link from "next/link";
import { OfflineQueueService } from "@/shared/offline/offlineQueue";

export function OfflineQueueIndicator() {
  const [count, setCount] = useState(0);

  useEffect(() => {
    const update = () => {
      try {
        setCount(OfflineQueueService.list().length);
      } catch {
        setCount(0);
      }
    };

    update();
    if (typeof window === "undefined") return;

    const id = window.setInterval(update, 5000);
    return () => {
      window.clearInterval(id);
    };
  }, []);

  if (count <= 0) {
    return null;
  }

  return (
    <Link
      href="/offline-queue"
      className="inline-flex items-center gap-1 rounded-full bg-slate-900/20 px-2 py-0.5 text-[10px] font-medium text-white hover:bg-slate-900/30"
    >
      <span className="h-1.5 w-1.5 rounded-full bg-amber-300" />
      <span>Оффлайн: {count}</span>
    </Link>
  );
}


