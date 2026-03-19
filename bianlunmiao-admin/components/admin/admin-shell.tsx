"use client"

import { LayoutDashboard, LogOut, ShieldCheck, Swords, Trophy, Users } from "lucide-react"
import Link from "next/link"
import { usePathname, useRouter } from "next/navigation"
import { useEffect } from "react"

import { useAuth } from "@/components/admin/auth-provider"
import { Badge } from "@/components/ui/badge"
import { Button, buttonVariants } from "@/components/ui/button"
import { Separator } from "@/components/ui/separator"
import { getAppEnv } from "@/lib/api/client"
import { cn } from "@/lib/utils"

const navItems = [
  { href: "/dashboard", label: "总览", icon: LayoutDashboard },
  { href: "/users", label: "用户", icon: Users },
  { href: "/teams", label: "队伍", icon: Swords },
  { href: "/tournaments", label: "赛事", icon: Trophy },
]

const pageTitles: Record<string, string> = {
  "/dashboard": "控制总览",
  "/users": "用户管理",
  "/teams": "队伍管理",
  "/tournaments": "赛事管理",
}

function envTone(env: string) {
  if (env === "prod") {
    return "border-emerald-600/20 bg-emerald-600/10 text-emerald-700"
  }

  if (env === "stg") {
    return "border-amber-600/20 bg-amber-600/10 text-amber-700"
  }

  return "border-sky-600/20 bg-sky-600/10 text-sky-700"
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
        <div className="surface-panel w-full max-w-md rounded-[32px] border border-white/70 p-8 text-center">
          <p className="font-display text-3xl text-foreground">后台会话校验中</p>
          <p className="mt-3 text-sm leading-6 text-muted-foreground">
            正在确认管理员凭证与环境绑定，请稍候。
          </p>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen px-4 py-4 md:px-6 md:py-6">
      <div className="mx-auto flex max-w-[1600px] flex-col gap-4 md:flex-row">
        <aside className="surface-panel rounded-[30px] border border-white/70 p-5 md:sticky md:top-6 md:h-[calc(100vh-3rem)] md:w-[280px] md:flex-shrink-0">
          <div className="flex items-start justify-between gap-4">
            <div className="space-y-2">
              <p className="text-xs uppercase tracking-[0.32em] text-muted-foreground">BianLunMiao</p>
              <div className="space-y-1">
                <h1 className="font-display text-3xl leading-none text-foreground">Control Room</h1>
                <p className="text-sm leading-6 text-muted-foreground">
                  管理用户、队伍与赛事数据，所有写操作均落审计。
                </p>
              </div>
            </div>
            <div className="rounded-2xl border border-border/70 bg-background/75 p-3 text-primary">
              <ShieldCheck className="size-5" />
            </div>
          </div>

          <Separator className="my-5" />

          <nav className="grid gap-2">
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
                    active
                      ? "shadow-[0_16px_30px_-20px_color-mix(in_oklch,var(--primary)_55%,transparent)]"
                      : "text-muted-foreground"
                  )}
                >
                  <Icon className="mr-2 size-4" />
                  {item.label}
                </Link>
              )
            })}
          </nav>

          <div className="mt-6 rounded-[26px] border border-border/70 bg-background/70 p-4">
            <div className="flex items-center justify-between gap-3">
              <Badge variant="outline" className={cn("rounded-full px-3 py-1 text-xs uppercase", envTone(env))}>
                {env}
              </Badge>
              <span className="text-xs uppercase tracking-[0.2em] text-muted-foreground">session</span>
            </div>
            <p className="mt-3 font-medium text-foreground">{session.admin.displayName}</p>
            <p className="mt-1 text-sm text-muted-foreground">{session.admin.email}</p>
          </div>
        </aside>

        <main className="surface-panel min-h-[calc(100vh-3rem)] flex-1 rounded-[30px] border border-white/70 p-5 md:p-7">
          <header className="flex flex-col gap-4 border-b border-border/70 pb-5 lg:flex-row lg:items-end lg:justify-between">
            <div className="space-y-3">
              <p className="text-xs uppercase tracking-[0.32em] text-muted-foreground">
                {env === "prod" ? "正式服管理" : env === "stg" ? "测试服管理" : "本地调试"}
              </p>
              <div>
                <h2 className="font-display text-4xl leading-none tracking-tight text-foreground">
                  {pageTitles[pathname] ?? "后台"}
                </h2>
                <p className="mt-2 max-w-2xl text-sm leading-6 text-muted-foreground">
                  同步后端真实数据源，不依赖 App 用户界面做治理操作。
                </p>
              </div>
            </div>

            <Button
              variant="outline"
              size="lg"
              onClick={async () => {
                await logout()
                router.replace("/login")
              }}
            >
              <LogOut className="size-4" />
              退出后台
            </Button>
          </header>

          <div className="pt-6">{children}</div>
        </main>
      </div>
    </div>
  )
}
