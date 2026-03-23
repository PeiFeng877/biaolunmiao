"use client"

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query"
import { Check, RefreshCw, RotateCcw } from "lucide-react"
import Link from "next/link"
import { useState } from "react"

import { useAuth } from "@/components/admin/auth-provider"
import {
  WorkspaceDetailEmpty,
  WorkspaceHero,
  WorkspaceListItem,
  WorkspaceSection,
  WorkspaceStat,
  WorkspaceTag,
} from "@/components/admin/workspace"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import {
  approveTeamJoinRequest,
  getOverview,
  getTeamJoinRequests,
  getTeams,
  getTournaments,
  getUsers,
  rejectTeamJoinRequest,
} from "@/lib/api/admin"
import { formatDateTime } from "@/lib/format"

function statusTone(status: string) {
  if (status === "approved") return "border-emerald-600/20 bg-emerald-600/10 text-emerald-700"
  if (status === "rejected") return "border-slate-500/20 bg-slate-500/10 text-slate-700"
  return "border-amber-600/20 bg-amber-600/10 text-amber-700"
}

export default function DashboardPage() {
  const { request } = useAuth()
  const queryClient = useQueryClient()
  const [recentTab, setRecentTab] = useState<"users" | "teams" | "tournaments">("users")

  const overviewQuery = useQuery({
    queryKey: ["admin-overview"],
    queryFn: () => getOverview(request),
  })

  const pendingRequestsQuery = useQuery({
    queryKey: ["admin-team-join-requests", "pending"],
    queryFn: () => getTeamJoinRequests(request, { status: "pending" }),
  })

  const usersQuery = useQuery({
    queryKey: ["admin-users", "dashboard"],
    queryFn: () => getUsers(request, { q: "", status: "all" }),
  })

  const teamsQuery = useQuery({
    queryKey: ["admin-teams", "dashboard"],
    queryFn: () => getTeams(request, { q: "", status: "all" }),
  })

  const tournamentsQuery = useQuery({
    queryKey: ["admin-tournaments", "dashboard"],
    queryFn: () => getTournaments(request, { q: "", status: "all" }),
  })

  const approveMutation = useMutation({
    mutationFn: (id: string) => approveTeamJoinRequest(request, id),
    onSuccess: async () => {
      await Promise.all([
        queryClient.invalidateQueries({ queryKey: ["admin-team-join-requests"] }),
        queryClient.invalidateQueries({ queryKey: ["admin-teams"] }),
      ])
    },
  })

  const rejectMutation = useMutation({
    mutationFn: (id: string) => rejectTeamJoinRequest(request, id),
    onSuccess: async () => {
      await Promise.all([
        queryClient.invalidateQueries({ queryKey: ["admin-team-join-requests"] }),
        queryClient.invalidateQueries({ queryKey: ["admin-teams"] }),
      ])
    },
  })

  const overview = overviewQuery.data
  const pendingRequests = pendingRequestsQuery.data?.items ?? []
  const recentUsers = usersQuery.data?.items.slice(0, 5) ?? []
  const recentTeams = teamsQuery.data?.items.slice(0, 5) ?? []
  const recentTournaments = tournamentsQuery.data?.items.slice(0, 5) ?? []
  const recentPanel =
    recentTab === "users"
      ? { title: "用户", href: "/users" as const }
      : recentTab === "teams"
        ? { title: "队伍", href: "/teams" as const }
        : { title: "赛事", href: "/tournaments" as const }

  return (
    <div className="space-y-4">
      <WorkspaceHero
        eyebrow="control inbox"
        title="收件箱"
        description="先处理待办，再跳到具体资源页。"
        meta={<WorkspaceTag tone="soft">{pendingRequests.length} 个待处理</WorkspaceTag>}
        actions={
          <Button
            variant="outline"
            size="lg"
            onClick={async () => {
              await Promise.all([
                overviewQuery.refetch(),
                pendingRequestsQuery.refetch(),
                usersQuery.refetch(),
                teamsQuery.refetch(),
                tournamentsQuery.refetch(),
              ])
            }}
          >
            <RefreshCw className="size-4" />
            刷新
          </Button>
        }
      />

      <section className="grid gap-3 md:grid-cols-2 xl:grid-cols-4">
        <WorkspaceStat
          label="待处理申请"
          value={pendingRequests.length}
          hint="入队申请优先处理。"
        />
        <WorkspaceStat
          label="用户"
          value={overview ? overview.users.total : "—"}
          hint={overview ? `正常 ${overview.users.normal} / 封禁 ${overview.users.banned}` : "加载中"}
        />
        <WorkspaceStat
          label="队伍"
          value={overview ? overview.teams.total : "—"}
          hint={overview ? `活跃 ${overview.teams.active} / 非活跃 ${overview.teams.inactive}` : "加载中"}
        />
        <WorkspaceStat
          label="赛事"
          value={overview ? overview.tournaments.total : "—"}
          hint={
            overview
              ? `开放 ${overview.tournaments.open} / 进行中 ${overview.tournaments.ongoing}`
              : "加载中"
          }
        />
      </section>

      <WorkspaceSection title="待审批入队申请" hint="这里应该是第一优先级。">
        <div className="space-y-2">
          {pendingRequests.length ? (
            pendingRequests.map((item) => (
              <div
                key={item.id}
                className="rounded-[24px] border border-border/60 bg-background/55 p-4 md:p-5"
              >
                <div className="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
                  <div className="min-w-0 space-y-2">
                    <div className="flex flex-wrap items-center gap-2">
                      <p className="text-base font-medium text-foreground">{item.teamName}</p>
                      <Badge variant="outline" className={statusTone(item.status)}>
                        {item.status}
                      </Badge>
                    </div>
                    <p className="text-sm text-muted-foreground">
                      {item.applicantNickname} · {item.applicantPublicId}
                    </p>
                    <p className="max-w-3xl text-sm leading-6 text-muted-foreground">
                      {item.personalNote}
                    </p>
                  </div>

                  <div className="flex min-w-fit flex-wrap items-center gap-2 lg:justify-end">
                    <span className="text-xs text-muted-foreground">{formatDateTime(item.createdAt)}</span>
                    <Button
                      size="sm"
                      variant="outline"
                      disabled={approveMutation.isPending}
                      onClick={() => approveMutation.mutate(item.id)}
                    >
                      <Check className="size-3.5" />
                      通过
                    </Button>
                    <Button
                      size="sm"
                      variant="destructive"
                      disabled={rejectMutation.isPending}
                      onClick={() => rejectMutation.mutate(item.id)}
                    >
                      <RotateCcw className="size-3.5" />
                      拒绝
                    </Button>
                  </div>
                </div>
              </div>
            ))
          ) : (
            <WorkspaceDetailEmpty title="没有待处理申请" hint="新的申请会自动出现在这里。" />
          )}
        </div>
      </WorkspaceSection>

      <WorkspaceSection
        title="最近更新"
        hint="只保留一个列表，避免并列分栏抢注意力。"
        action={
          <div className="flex flex-wrap items-center gap-2">
            <Button
              variant={recentTab === "users" ? "default" : "outline"}
              size="sm"
              onClick={() => setRecentTab("users")}
            >
              用户
            </Button>
            <Button
              variant={recentTab === "teams" ? "default" : "outline"}
              size="sm"
              onClick={() => setRecentTab("teams")}
            >
              队伍
            </Button>
            <Button
              variant={recentTab === "tournaments" ? "default" : "outline"}
              size="sm"
              onClick={() => setRecentTab("tournaments")}
            >
              赛事
            </Button>
          </div>
        }
      >
        <div className="rounded-[24px] border border-border/60 bg-background/55 p-4">
          <div className="mb-3 flex items-center justify-between gap-3">
            <p className="text-sm font-medium text-foreground">{recentPanel.title}</p>
            <Link href={recentPanel.href} className="text-xs text-primary hover:underline">
              打开列表
            </Link>
          </div>
          <div className="space-y-2">
            {recentTab === "users" && recentUsers.length
              ? recentUsers.map((item) => (
                  <WorkspaceListItem
                    key={item.id}
                    title={item.nickname}
                    subtitle={item.publicId}
                    meta={formatDateTime(item.updatedAt)}
                    badge={<WorkspaceTag tone="soft">{item.status}</WorkspaceTag>}
                    onClick={() => {
                      window.location.href = "/users"
                    }}
                  />
                ))
              : null}

            {recentTab === "teams" && recentTeams.length
              ? recentTeams.map((item) => (
                  <WorkspaceListItem
                    key={item.id}
                    title={item.name}
                    subtitle={item.publicId}
                    meta={`${item.memberCount} 人`}
                    badge={<WorkspaceTag tone="soft">{item.status}</WorkspaceTag>}
                    onClick={() => {
                      window.location.href = "/teams"
                    }}
                  />
                ))
              : null}

            {recentTab === "tournaments" && recentTournaments.length
              ? recentTournaments.map((item) => (
                  <WorkspaceListItem
                    key={item.id}
                    title={item.name}
                    subtitle={item.id}
                    meta={`${item.participantCount} 队 / ${item.matchCount} 场`}
                    badge={<WorkspaceTag tone="soft">{item.status}</WorkspaceTag>}
                    onClick={() => {
                      window.location.href = "/tournaments"
                    }}
                  />
                ))
              : null}

            {((recentTab === "users" && !recentUsers.length) ||
              (recentTab === "teams" && !recentTeams.length) ||
              (recentTab === "tournaments" && !recentTournaments.length)) ? (
              <div className="rounded-[22px] border border-dashed border-border/70 bg-background/50 p-4 text-sm text-muted-foreground">
                暂无数据
              </div>
            ) : null}
          </div>
        </div>
      </WorkspaceSection>
    </div>
  )
}
