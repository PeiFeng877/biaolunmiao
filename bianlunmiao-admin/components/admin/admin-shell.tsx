"use client"

import {
  CalendarRange,
  Inbox,
  LogOut,
  ShieldCheck,
  Swords,
  Trophy,
  Users,
} from "lucide-react"
import Link from "next/link"
import { usePathname, useRouter } from "next/navigation"
import { useEffect } from "react"

import { useAuth } from "@/components/admin/auth-provider"
import { Badge } from "@/components/ui/badge"
import { Button, buttonVariants } from "@/components/ui/button"
import { cn } from "@/lib/utils"
import { getAppEnv } from "@/lib/api/client"

const navItems = [
  { href: "/dashboard", label: "收件箱", icon: Inbox },
  { href: "/users", label: "用户", icon: Users },
  { href: "/teams", label: "队伍", icon: Swords },
  { href: "/tournaments", label: "赛事", icon: Trophy },
  { href: "/matches", label: "场次", icon: CalendarRange },
]

const pageTitles: Record<string, string> = {
  "/dashboard": "收件箱",
  "/users": "用户",
  "/teams": "队伍",
  "/tournaments": "赛事",
  "/matches": "场次",
}

function envTone(env: string) {
  return env === "prod"
    ? "border-emerald-600/20 bg-emerald-600/10 text-emerald-700"
    : "border-sky-600/20 bg-sky-600/10 text-sky-700"
}

export function AdminShell({ children }: { children: React.ReactNode }) {
  const { ready, session, logout } = useAuth()
  const router = useRouter()
  const pathname = usePathname()
  const env = getAppEnv()

  useEffect(() => {
    if (ready && !session) {
      router.replace("/login")
    }
  }, [ready, router, session])

  if (!ready || !session) {
    return (
      <div className="flex min-h-screen items-center justify-center px-6">
        <div className="w-full max-w-sm rounded-[28px] bg-card/85 p-6 ring-1 ring-black/5 backdrop-blur-md">
          <div className="flex items-center justify-center">
            <div className="rounded-2xl bg-primary/10 p-3 text-primary">
              <ShieldCheck className="size-5" />
            </div>
          </div>
          <p className="mt-4 text-center font-display text-2xl text-foreground">会话校验中</p>
          <p className="mt-2 text-center text-sm leading-6 text-muted-foreground">
            正在确认管理员凭证和后台环境。
          </p>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen px-3 py-3 md:px-4 md:py-4">
      <div className="mx-auto flex max-w-[1640px] gap-3">
        <aside className="hidden w-[256px] shrink-0 rounded-[28px] bg-card/80 p-4 ring-1 ring-black/5 backdrop-blur-md lg:flex lg:flex-col">
          <div className="flex items-start gap-3">
            <div className="rounded-2xl bg-primary/10 p-2.5 text-primary">
              <ShieldCheck className="size-5" />
            </div>
            <div className="min-w-0">
              <p className="text-[11px] uppercase tracking-[0.32em] text-muted-foreground">
                BianLunMiao
              </p>
              <p className="mt-1 font-display text-2xl text-foreground">Admin Workbench</p>
            </div>
          </div>

          <nav className="mt-6 grid gap-1.5">
            {navItems.map((item) => {
              const Icon = item.icon
              const active = pathname === item.href

              return (
                <Link
                  key={item.href}
                  href={item.href}
                  className={cn(
                    buttonVariants({ variant: active ? "default" : "ghost", size: "lg" }),
                    "justify-start rounded-2xl px-4 text-left",
                    active ? "shadow-[0_12px_28px_-18px_rgba(15,23,42,0.3)]" : "text-muted-foreground"
                  )}
                >
                  <Icon className="mr-2 size-4" />
                  {item.label}
                </Link>
              )
            })}
          </nav>

          <div className="mt-auto space-y-3 rounded-[24px] border border-border/60 bg-background/50 p-4">
            <div className="flex items-center justify-between gap-2">
              <Badge variant="outline" className={cn("rounded-full px-3 py-1 text-[11px]", envTone(env))}>
                {env}
              </Badge>
              <span className="text-[11px] uppercase tracking-[0.2em] text-muted-foreground">
                session
              </span>
            </div>
            <div className="min-w-0">
              <p className="truncate text-sm font-medium text-foreground">{session.admin.displayName}</p>
              <p className="truncate text-xs text-muted-foreground">{session.admin.email}</p>
            </div>
          </div>
        </aside>

        <main className="min-w-0 flex-1 rounded-[28px] bg-card/70 px-4 py-4 ring-1 ring-black/5 backdrop-blur-md md:px-5 md:py-5">
          <header className="flex flex-col gap-4 border-b border-border/60 pb-4 lg:flex-row lg:items-center lg:justify-between">
            <div className="space-y-1">
              <p className="text-[11px] uppercase tracking-[0.34em] text-muted-foreground">
                {env === "prod" ? "正式服管理" : "本地调试"}
              </p>
              <p className="text-sm font-medium text-foreground">{pageTitles[pathname] ?? "后台"}</p>
            </div>

            <div className="flex items-center gap-2">
              <Badge variant="outline" className={cn("rounded-full px-3 py-1 text-[11px]", envTone(env))}>
                {env}
              </Badge>
              <Button
                variant="outline"
                size="lg"
                onClick={async () => {
                  await logout()
                  router.replace("/login")
                }}
              >
                <LogOut className="size-4" />
                退出
              </Button>
            </div>
          </header>

          <div className="pt-4">{children}</div>
        </main>
      </div>
    </div>
  )
}
