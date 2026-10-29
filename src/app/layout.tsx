import type { Metadata, Viewport } from "next";
import type { ReactNode } from "react";
import "./globals.css";
import { GameProvider } from "@/game/store/GameProvider";
import { SwRegister } from "@/components/SwRegister";
import { SoundController } from "@/components/SoundController";

export const metadata: Metadata = {
  title: "受験生の鏡",
  description: "閉じるほど、物語が動き出す。",
  applicationName: "受験生の鏡",
  manifest: "/manifest.webmanifest",
  appleWebApp: { capable: true, statusBarStyle: "default", title: "受験生の鏡" },
  icons: {
    icon: [{ url: "/icons/icon.svg", type: "image/svg+xml" }, { url: "/icons/icon-192.png", sizes: "192x192" }],
    apple: [{ url: "/icons/icon-180.png", sizes: "180x180" }],
  },
};

export const viewport: Viewport = {
  themeColor: "#fbf4e8",
  width: "device-width",
  initialScale: 1,
  viewportFit: "cover",
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="ja" className="h-full antialiased">
      <body className="flex min-h-full flex-col">
        <GameProvider>
          {children}
          <SoundController />
        </GameProvider>
        <SwRegister />
      </body>
    </html>
  );
}
