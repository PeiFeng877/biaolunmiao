import type { Metadata } from "next"
import { Fraunces, Space_Grotesk } from "next/font/google"

import { Providers } from "@/components/admin/providers"

import "./globals.css"

const spaceGrotesk = Space_Grotesk({
  variable: "--font-sans",
  subsets: ["latin"],
})

const fraunces = Fraunces({
  variable: "--font-display",
  subsets: ["latin"],
})

export const metadata: Metadata = {
  title: "辩论喵后台",
  description: "辩论喵 Web 管理后台",
}

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode
}>) {
  return (
    <html
      lang="zh-CN"
      className={`${spaceGrotesk.variable} ${fraunces.variable} h-full antialiased`}
    >
      <body className="min-h-full">
        <Providers>{children}</Providers>
      </body>
    </html>
  )
}
