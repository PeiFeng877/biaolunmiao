"use client"

import { useQuery } from "@tanstack/react-query"
import { Activity, ShieldAlert, Swords, Trophy, Users } from "lucide-react"

import { useAuth } from "@/components/admin/auth-provider"
import { MetricCard } from "@/components/admin/metric-card"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { getOverview } from "@/lib/api/admin"
import { formatDateTime } from "@/lib/format"

type HealthProbeResult = {
  ok: boolean
  status: number
  body: string
}

async function fetchHealthProbe(): Promise<HealthProbeResult> {
  try {
    const response = await fetch("/api/proxy/healthz", { cache: "no-store" })
    const body = await response.text()

    return {
      ok: response.ok,
      status: response.status,
      body,
    }
  } catch (error) {
    return {
      ok: false,
      status: 0,
      body: error instanceof Error ? error.message : "请求失败",
    }
  }
}

export default function DashboardPage() {
  const { request } = useAuth()
  const overviewQuery = useQuery({
    queryKey: ["admin-overview"],
    queryFn: () => getOverview(request),
  })
  const healthQuery = useQuery({
    queryKey: ["stg-health-probe"],
    queryFn: fetchHealthProbe,
    retry: false,
    refetchOnWindowFocus: false,
  })

  const overview = overviewQuery.data
  const healthProbe = healthQuery.data

  return (
    <div className="space-y-6">
      <section className="grid gap-4 xl:grid-cols-3">
        <MetricCard
          title="用户池"
          value={overview ? `${overview.users.total}` : "—"}
          note={
            overview
              ? `正常 ${overview.users.normal} / 删除 ${overview.users.deleted} / 封禁 ${overview.users.banned}`
              : "加载中"
          }
          icon={<Users className="size-5" />}
        />
        <MetricCard
          title="队伍池"
          value={overview ? `${overview.teams.total}` : "—"}
          note={
            overview
              ? `活跃 ${overview.teams.active} / 非活跃 ${overview.teams.inactive}`
              : "加载中"
          }
          icon={<Swords className="size-5" />}
        />
        <MetricCard
          title="赛事池"
          value={overview ? `${overview.tournaments.total}` : "—"}
          note={
            overview
              ? `开放 ${overview.tournaments.open} / 进行中 ${overview.tournaments.ongoing} / 结束 ${overview.tournaments.ended}`
              : "加载中"
          }
          icon={<Trophy className="size-5" />}
        />
      </section>

      <section className="grid gap-4 xl:grid-cols-[1.2fr_0.8fr]">
        <Card className="surface-panel border-white/70">
          <CardHeader className="space-y-3">
            <Badge variant="outline" className="w-fit rounded-full px-3 py-1 text-xs uppercase tracking-[0.22em]">
              operational baseline
            </Badge>
            <div>
              <CardTitle className="font-display text-3xl text-foreground">
                后台收口规则
              </CardTitle>
              <p className="mt-2 max-w-2xl text-sm leading-7 text-muted-foreground">
                当前后台只管理用户、队伍、赛事三类主字段。更深层的业务关系仍由后端服务规则控制，避免在控制台里制造额外分叉。
              </p>
            </div>
          </CardHeader>
          <CardContent className="grid gap-4 md:grid-cols-3">
            <div className="rounded-[24px] border border-border/70 bg-background/70 p-4">
              <p className="text-xs uppercase tracking-[0.2em] text-muted-foreground">数据事实源</p>
              <p className="mt-3 text-sm leading-6 text-foreground">
                所有列表、详情和编辑都通过 `/api/proxy/rpc` 转发到 EMAS `/api`。
              </p>
            </div>
            <div className="rounded-[24px] border border-border/70 bg-background/70 p-4">
              <p className="text-xs uppercase tracking-[0.2em] text-muted-foreground">会话策略</p>
              <p className="mt-3 text-sm leading-6 text-foreground">
                浏览器只存后台管理员 sessionStorage，会话过期时自动尝试 refresh。
              </p>
            </div>
            <div className="rounded-[24px] border border-border/70 bg-background/70 p-4">
              <p className="text-xs uppercase tracking-[0.2em] text-muted-foreground">写操作审计</p>
              <p className="mt-3 text-sm leading-6 text-foreground">
                当前阶段先由后端统一做权限和字段校验；后台审计日志会在下一轮 serverless 增强时补齐。
              </p>
            </div>
          </CardContent>
        </Card>

        <Card className="surface-panel border-white/70">
          <CardHeader>
            <CardTitle className="flex items-center gap-2 text-lg text-foreground">
              <Activity className="size-4 text-primary" />
              最新活动基线
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-5">
            <div className="rounded-[24px] border border-border/70 bg-background/72 p-5">
              <p className="text-xs uppercase tracking-[0.2em] text-muted-foreground">latest activity</p>
              <p className="mt-3 font-display text-3xl text-foreground">
                {overview ? formatDateTime(overview.latestActivityAt) : "加载中"}
              </p>
            </div>

            <div className="rounded-[24px] border border-border/70 bg-amber-50/70 p-5">
              <div className="flex items-center gap-2 text-amber-700">
                <ShieldAlert className="size-4" />
                <p className="text-xs uppercase tracking-[0.2em]">治理提醒</p>
              </div>
              <p className="mt-3 text-sm leading-6 text-amber-900/90">
                正式环境建议先做低风险字段更新，再观察审计日志和列表刷新结果，避免首次上线直接做批量操作。
              </p>
            </div>
          </CardContent>
        </Card>
      </section>

      <Card className="surface-panel border-white/70">
        <CardHeader className="space-y-3">
          <Badge variant="outline" className="w-fit rounded-full px-3 py-1 text-xs uppercase tracking-[0.22em]">
            stg connectivity
          </Badge>
          <div className="flex flex-col gap-3 lg:flex-row lg:items-end lg:justify-between">
            <div>
              <CardTitle className="font-display text-3xl text-foreground">代理连通性检查</CardTitle>
              <p className="mt-2 max-w-2xl text-sm leading-7 text-muted-foreground">
                这一项只验证浏览器到 `/api/proxy/healthz` 的链路；后台业务可用性仍以登录、总览和 CRUD 页实际结果为准。
              </p>
            </div>
            <Button
              variant="outline"
              onClick={() => {
                void healthQuery.refetch()
              }}
            >
              <Activity className="size-4" />
              重新检测
            </Button>
          </div>
        </CardHeader>
        <CardContent className="grid gap-4 lg:grid-cols-[220px_1fr]">
          <div className="rounded-[24px] border border-border/70 bg-background/70 p-5">
            <p className="text-xs uppercase tracking-[0.2em] text-muted-foreground">endpoint</p>
            <p className="mt-3 font-mono text-sm text-foreground">/api/proxy/healthz</p>
            <div className="mt-4 flex items-center gap-2">
              <Badge
                variant="outline"
                className={healthProbe?.ok ? "border-emerald-600/20 bg-emerald-600/10 text-emerald-700" : "border-rose-600/20 bg-rose-600/10 text-rose-700"}
              >
                {healthQuery.isFetching ? "检测中" : healthProbe?.ok ? "连通" : "未连通"}
              </Badge>
              <span className="text-xs uppercase tracking-[0.18em] text-muted-foreground">
                {healthProbe ? `HTTP ${healthProbe.status}` : "等待结果"}
              </span>
            </div>
          </div>

          <div className="rounded-[24px] border border-border/70 bg-background/70 p-5">
            <p className="text-xs uppercase tracking-[0.2em] text-muted-foreground">response body</p>
            <pre className="mt-3 max-h-56 overflow-auto whitespace-pre-wrap break-words rounded-[18px] border border-border/70 bg-slate-950 px-4 py-3 text-sm leading-6 text-slate-100">
              {healthQuery.isFetching ? "正在请求 stg 后端..." : healthProbe?.body || "尚未执行"}
            </pre>
          </div>
        </CardContent>
      </Card>
    </div>
  )
}
