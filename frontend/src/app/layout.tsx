import type { Metadata, Viewport } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import "./globals.css";
import { AuthBootstrap } from "@/shared/components/providers/AuthBootstrap";
import { OfflineQueueBootstrap } from "@/shared/components/providers/OfflineQueueBootstrap";
import { ReactQueryProvider } from "@/shared/components/providers/ReactQueryProvider";
import { WebPushBootstrap } from "@/shared/components/providers/WebPushBootstrap";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "Ringo Учет",
  description: "Управление заявками, техникой и финансами",
  manifest: "/manifest.json",
};

export const viewport: Viewport = {
  themeColor: "#020617",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="ru">
      <body
        className={`${geistSans.variable} ${geistMono.variable} antialiased`}
      >
        <ReactQueryProvider>
          <AuthBootstrap>
            <WebPushBootstrap>
              <OfflineQueueBootstrap>{children}</OfflineQueueBootstrap>
            </WebPushBootstrap>
          </AuthBootstrap>
        </ReactQueryProvider>
      </body>
    </html>
  );
}
