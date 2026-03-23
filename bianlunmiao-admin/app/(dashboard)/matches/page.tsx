"use client"

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query"
import { CalendarRange, Plus, Trash2 } from "lucide-react"
import { useDeferredValue, useEffect, useMemo, useState } from "react"
import { useSearchParams } from "next/navigation"
import { useForm, useWatch } from "react-hook-form"
import { toast } from "sonner"

import { useAuth } from "@/components/admin/auth-provider"
import { FieldGroup } from "@/components/admin/field-group"
import { SearchPicker } from "@/components/admin/search-picker"
import {
  WorkspaceDetailEmpty,
  WorkspaceGrid,
  WorkspaceHero,
  WorkspaceListItem,
  WorkspacePane,
  WorkspaceSearch,
  WorkspaceSection,
  WorkspaceTabs,
  WorkspaceTag,
} from "@/components/admin/workspace"
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogMedia,
  AlertDialogTitle,
} from "@/components/ui/alert-dialog"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Textarea } from "@/components/ui/textarea"
import {
  advanceMatchStatus,
  createMatch,
  deleteMatch,
  getMatchDetail,
  getMatches,
  getTeamDetail,
  getTeams,
  getTournaments,
  updateMatch,
  updateMatchResult,
  updateMatchRoster,
} from "@/lib/api/admin"
import { formatDateTime } from "@/lib/format"
import { applyZodIssues } from "@/lib/forms"
import {
  matchCreateSchema,
  matchResultUpdateSchema,
  type MatchCreateValues,
  type MatchResultUpdateValues,
} from "@/lib/schemas/admin"

const matchFormats = ["1v1", "2v2", "3v3", "4v4"] as const
const matchStatuses = ["scheduled", "ready", "ongoing", "finished"] as const

function toDateTimeInputValue(value?: string | null) {
  if (!value) return ""
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return ""
  const offsetMs = date.getTimezoneOffset() * 60_000
  return new Date(date.getTime() - offsetMs).toISOString().slice(0, 16)
}

function createDefaults(): MatchCreateValues {
  const start = new Date()
  start.setMinutes(Math.ceil(start.getMinutes() / 15) * 15, 0, 0)
  const end = new Date(start.getTime() + 60 * 60 * 1000)
  return {
    name: "",
    topic: "",
    start_time: toDateTimeInputValue(start.toISOString()),
    end_time: toDateTimeInputValue(end.toISOString()),
    location: "",
    format: "3v3",
    opponent_team_name: "",
    team_a_id: "",
    team_b_id: "",
  }
}

function buildFormValues(match: {
  name: string
  topic?: string | null
  startTime: string
  endTime: string
  location?: string | null
  format: string
  opponentTeamName?: string | null
  teamAId?: string | null
  teamBId?: string | null
}): MatchCreateValues {
  return {
    name: match.name,
    topic: match.topic ?? "",
    start_time: toDateTimeInputValue(match.startTime),
    end_time: toDateTimeInputValue(match.endTime),
    location: match.location ?? "",
    format: match.format,
    opponent_team_name: match.opponentTeamName ?? "",
    team_a_id: match.teamAId ?? "",
    team_b_id: match.teamBId ?? "",
  }
}

function positionsForFormat(format: string) {
  if (format === "1v1") return ["一辩"]
  if (format === "2v2") return ["一辩", "二辩"]
  if (format === "4v4") return ["一辩", "二辩", "三辩", "四辩"]
  return ["一辩", "二辩", "三辩"]
}

function createResultDraft(match?: {
  winnerTeamId?: string | null
  teamAScore?: number | null
  teamBScore?: number | null
  resultNote?: string | null
  bestDebaterPosition?: string | null
} | null): MatchResultUpdateValues {
  return {
    winner_team_id: match?.winnerTeamId ?? "",
    team_a_score: match?.teamAScore ?? 0,
    team_b_score: match?.teamBScore ?? 0,
    result_note: match?.resultNote ?? "",
    best_debater_position: match?.bestDebaterPosition ?? "",
  }
}

export default function MatchesPage() {
  const { request } = useAuth()
  const queryClient = useQueryClient()
  const searchParams = useSearchParams()

  const initialTournamentId = searchParams.get("tournamentId") ?? "all"
  const initialSelected = searchParams.get("selected")
  const initialCreate = searchParams.get("create") === "1"

  const [search, setSearch] = useState("")
  const [statusFilter, setStatusFilter] = useState("all")
  const [tournamentFilter, setTournamentFilter] = useState(initialTournamentId)
  const [teamFilterId, setTeamFilterId] = useState("")
  const [teamFilterSearch, setTeamFilterSearch] = useState("")
  const [selectedId, setSelectedId] = useState<string | null>(initialSelected)
  const [creating, setCreating] = useState(initialCreate)
  const [tab, setTab] = useState("base")
  const [matchTournamentId, setMatchTournamentId] = useState(initialTournamentId !== "all" ? initialTournamentId : "")
  const [teamSearchA, setTeamSearchA] = useState("")
  const [teamSearchB, setTeamSearchB] = useState("")
  const [deleteOpen, setDeleteOpen] = useState(false)
  const [rosterDraftsByMatch, setRosterDraftsByMatch] = useState<
    Record<string, Record<string, Record<string, string>>>
  >({})
  const [resultDraftsByMatch, setResultDraftsByMatch] = useState<Record<string, MatchResultUpdateValues>>({})

  const deferredSearch = useDeferredValue(search)
  const deferredTeamFilterSearch = useDeferredValue(teamFilterSearch)
  const deferredTeamSearchA = useDeferredValue(teamSearchA)
  const deferredTeamSearchB = useDeferredValue(teamSearchB)

  const form = useForm<MatchCreateValues>({ defaultValues: createDefaults() })
  const formatValue = useWatch({ control: form.control, name: "format" })
  const teamAIdValue = useWatch({ control: form.control, name: "team_a_id" })
  const teamBIdValue = useWatch({ control: form.control, name: "team_b_id" })

  const tournamentsQuery = useQuery({
    queryKey: ["admin-tournaments", "match-page"],
    queryFn: () => getTournaments(request, { q: "", status: "all" }),
  })

  const matchesQuery = useQuery({
    queryKey: ["admin-matches", deferredSearch, statusFilter, tournamentFilter, teamFilterId],
    queryFn: () =>
      getMatches(request, {
        q: deferredSearch || undefined,
        status: statusFilter === "all" ? undefined : statusFilter,
        tournament_id: tournamentFilter === "all" ? undefined : tournamentFilter,
        team_id: teamFilterId || undefined,
      }),
  })

  const list = matchesQuery.data?.items ?? []
  const effectiveSelectedId = creating ? null : selectedId ?? list[0]?.id ?? null

  const detailQuery = useQuery({
    queryKey: ["admin-match-detail", effectiveSelectedId],
    queryFn: () => getMatchDetail(request, effectiveSelectedId!),
    enabled: Boolean(effectiveSelectedId) && !creating,
  })

  const teamFilterCandidatesQuery = useQuery({
    queryKey: ["admin-teams", "match-filter-team", deferredTeamFilterSearch],
    queryFn: () => getTeams(request, { q: deferredTeamFilterSearch, status: "0" }),
  })

  const teamACandidatesQuery = useQuery({
    queryKey: ["admin-teams", "match-team-a", deferredTeamSearchA],
    queryFn: () => getTeams(request, { q: deferredTeamSearchA, status: "0" }),
  })

  const teamBCandidatesQuery = useQuery({
    queryKey: ["admin-teams", "match-team-b", deferredTeamSearchB],
    queryFn: () => getTeams(request, { q: deferredTeamSearchB, status: "0" }),
  })

  const activeMatch = detailQuery.data ?? list.find((item) => item.id === effectiveSelectedId) ?? null
  const activeTab = creating ? "base" : tab
  const activeMatchTournamentId = creating ? matchTournamentId : activeMatch?.tournamentId ?? ""

  const teamADetailQuery = useQuery({
    queryKey: ["admin-team-detail", activeMatch?.teamAId, "match-roster"],
    queryFn: () => getTeamDetail(request, activeMatch!.teamAId!),
    enabled: Boolean(activeMatch?.teamAId),
  })

  const teamBDetailQuery = useQuery({
    queryKey: ["admin-team-detail", activeMatch?.teamBId, "match-roster"],
    queryFn: () => getTeamDetail(request, activeMatch!.teamBId!),
    enabled: Boolean(activeMatch?.teamBId),
  })

  useEffect(() => {
    if (creating) {
      form.reset(createDefaults())
      return
    }

    if (activeMatch) {
      form.reset(buildFormValues(activeMatch))
    }
  }, [activeMatch, creating, form])

  const rosterDrafts = useMemo(() => {
    if (!activeMatch) return {}
    const existing = rosterDraftsByMatch[activeMatch.id]
    if (existing) return existing

    const nextDrafts: Record<string, Record<string, string>> = {}
    for (const teamId of [activeMatch.teamAId, activeMatch.teamBId]) {
      if (!teamId) continue
      nextDrafts[teamId] = {}
      for (const position of positionsForFormat(activeMatch.format)) {
        const current = activeMatch.rosters.find(
          (roster) => roster.teamId === teamId && roster.position === position
        )
        nextDrafts[teamId][position] = current?.userId ?? ""
      }
    }
    return nextDrafts
  }, [activeMatch, rosterDraftsByMatch])

  const resultDraft = useMemo(
    () => (activeMatch ? resultDraftsByMatch[activeMatch.id] ?? createResultDraft(activeMatch) : createResultDraft()),
    [activeMatch, resultDraftsByMatch]
  )

  const saveMutation = useMutation({
    mutationFn: async (values: MatchCreateValues) => {
      const parsed = matchCreateSchema.parse(values)
      if (creating) {
        if (!activeMatchTournamentId) {
          throw new Error("请先选择所属赛事")
        }
        return createMatch(request, activeMatchTournamentId, parsed)
      }
      return updateMatch(request, effectiveSelectedId!, parsed)
    },
    onSuccess: async (data) => {
      toast.success(creating ? "场次已创建" : "场次已更新")
      setCreating(false)
      setSelectedId(data.id)
      setTournamentFilter(data.tournamentId)
      await Promise.all([
        queryClient.invalidateQueries({ queryKey: ["admin-matches"] }),
        queryClient.invalidateQueries({ queryKey: ["admin-match-detail", data.id] }),
        queryClient.invalidateQueries({ queryKey: ["admin-tournament-detail", data.tournamentId] }),
      ])
    },
    onError: (error) => {
      toast.error(error instanceof Error ? error.message : "提交失败")
    },
  })

  const deleteMutation = useMutation({
    mutationFn: () => deleteMatch(request, effectiveSelectedId!),
    onSuccess: async () => {
      toast.success("场次已删除")
      setDeleteOpen(false)
      setSelectedId(null)
      setCreating(false)
      await queryClient.invalidateQueries({ queryKey: ["admin-matches"] })
    },
  })

  const rosterMutation = useMutation({
    mutationFn: ({ teamId, assignments }: { teamId: string; assignments: Array<{ user_id: string; position: string }> }) =>
      updateMatchRoster(request, effectiveSelectedId!, teamId, { assignments }),
    onSuccess: async () => {
      toast.success("名单已保存")
      setRosterDraftsByMatch((current) => {
        if (!effectiveSelectedId) return current
        const next = { ...current }
        delete next[effectiveSelectedId]
        return next
      })
      await Promise.all([
        queryClient.invalidateQueries({ queryKey: ["admin-match-detail", effectiveSelectedId] }),
        queryClient.invalidateQueries({ queryKey: ["admin-matches"] }),
      ])
    },
  })

  const statusMutation = useMutation({
    mutationFn: (status: string) => advanceMatchStatus(request, effectiveSelectedId!, { status }),
    onSuccess: async () => {
      toast.success("状态已推进")
      await Promise.all([
        queryClient.invalidateQueries({ queryKey: ["admin-match-detail", effectiveSelectedId] }),
        queryClient.invalidateQueries({ queryKey: ["admin-matches"] }),
      ])
    },
  })

  const resultMutation = useMutation({
    mutationFn: (values: MatchResultUpdateValues) =>
      updateMatchResult(request, effectiveSelectedId!, matchResultUpdateSchema.parse(values)),
    onSuccess: async () => {
      toast.success("赛果已保存")
      setResultDraftsByMatch((current) => {
        if (!effectiveSelectedId) return current
        const next = { ...current }
        delete next[effectiveSelectedId]
        return next
      })
      await Promise.all([
        queryClient.invalidateQueries({ queryKey: ["admin-match-detail", effectiveSelectedId] }),
        queryClient.invalidateQueries({ queryKey: ["admin-matches"] }),
      ])
    },
  })

  const submit = form.handleSubmit((values) => {
    form.clearErrors()
    const parsed = matchCreateSchema.safeParse(values)
    if (!parsed.success) {
      applyZodIssues(parsed.error, form.setError)
      return
    }
    saveMutation.mutate(values)
  })

  const teamFilterItems = useMemo(
    () =>
      (teamFilterCandidatesQuery.data?.items ?? []).map((item) => ({
        id: item.id,
        title: item.name,
        subtitle: item.publicId,
      })),
    [teamFilterCandidatesQuery.data?.items]
  )

  const teamAItems = useMemo(
    () =>
      (teamACandidatesQuery.data?.items ?? []).map((item) => ({
        id: item.id,
        title: item.name,
        subtitle: item.publicId,
      })),
    [teamACandidatesQuery.data?.items]
  )

  const teamBItems = useMemo(
    () =>
      (teamBCandidatesQuery.data?.items ?? []).map((item) => ({
        id: item.id,
        title: item.name,
        subtitle: item.publicId,
      })),
    [teamBCandidatesQuery.data?.items]
  )

  const rosterTeams = [
    { key: activeMatch?.teamAId ?? "", label: activeMatch?.teamAName ?? activeMatch?.teamAId ?? "A 队", detail: teamADetailQuery.data },
    { key: activeMatch?.teamBId ?? "", label: activeMatch?.teamBName ?? activeMatch?.teamBId ?? "B 队", detail: teamBDetailQuery.data },
  ].filter((item) => item.key)

  return (
    <div className="space-y-4">
      <WorkspaceHero
        eyebrow="resource workbench"
        title="场次"
        description="顶层处理赛事归属、对阵、名单、赛果和状态推进。"
        meta={<WorkspaceTag tone="soft">{matchesQuery.data?.items.length ?? 0} 条结果</WorkspaceTag>}
        actions={
          <Button
            size="lg"
            onClick={() => {
              setCreating(true)
              setSelectedId(null)
              setTab("base")
              form.reset(createDefaults())
              setMatchTournamentId(tournamentFilter !== "all" ? tournamentFilter : "")
            }}
          >
            <Plus className="size-4" />
            新建场次
          </Button>
        }
      />

      <WorkspaceGrid
        left={
          <WorkspacePane className="xl:sticky xl:top-4 xl:self-start">
            <WorkspaceSection title="列表" hint="按赛事、状态和队伍筛选场次。">
              <WorkspaceSearch value={search} onChange={setSearch} placeholder="搜索场次名称、议题或地点" />
              <div className="mt-3 grid gap-2 md:grid-cols-2">
                <Select value={tournamentFilter} onValueChange={(value) => setTournamentFilter(value ?? "all")}>
                  <SelectTrigger className="h-10 rounded-2xl">
                    <SelectValue placeholder="所属赛事" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="all">全部赛事</SelectItem>
                    {(tournamentsQuery.data?.items ?? []).map((item) => (
                      <SelectItem key={item.id} value={item.id}>
                        {item.name}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>

                <Select value={statusFilter} onValueChange={(value) => setStatusFilter(value ?? "all")}>
                  <SelectTrigger className="h-10 rounded-2xl">
                    <SelectValue placeholder="场次状态" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="all">全部状态</SelectItem>
                    {matchStatuses.map((status) => (
                      <SelectItem key={status} value={status}>
                        {status}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
            </WorkspaceSection>

            <WorkspaceSection title="按队伍过滤" className="mt-4">
              <SearchPicker
                value={teamFilterId}
                searchValue={teamFilterSearch}
                onSearchChange={setTeamFilterSearch}
                onSelect={setTeamFilterId}
                items={teamFilterItems}
                placeholder="搜索队伍筛选场次"
                emptyText="没有匹配的队伍。"
              />
              {teamFilterId ? (
                <Button variant="ghost" className="mt-2" onClick={() => setTeamFilterId("")}>
                  清空队伍过滤
                </Button>
              ) : null}
            </WorkspaceSection>

            <div className="mt-4 space-y-2">
              {(matchesQuery.data?.items ?? []).length ? (
                matchesQuery.data?.items.map((match) => (
                  <WorkspaceListItem
                    key={match.id}
                    active={!creating && effectiveSelectedId === match.id}
                    title={match.name}
                    subtitle={`${match.teamAName ?? match.teamAId ?? "待定"} vs ${match.teamBName ?? match.teamBId ?? "待定"}`}
                    meta={formatDateTime(match.startTime)}
                    badge={<WorkspaceTag>{match.status}</WorkspaceTag>}
                    onClick={() => {
                      setCreating(false)
                      setSelectedId(match.id)
                    }}
                  />
                ))
              ) : (
                <div className="rounded-[24px] border border-dashed border-border/70 bg-background/50 p-6 text-center">
                  <p className="text-sm font-medium text-foreground">没有匹配的场次</p>
                  <p className="mt-2 text-xs leading-5 text-muted-foreground">调整筛选条件或新建场次。</p>
                </div>
              )}
            </div>
          </WorkspacePane>
        }
        right={
          <WorkspacePane>
            {activeMatch || creating ? (
              <div className="flex min-h-0 flex-1 flex-col gap-4">
                <div className="flex flex-col gap-2 border-b border-border/60 pb-4">
                  <div className="flex flex-wrap items-center justify-between gap-3">
                    <div>
                      <h2 className="text-sm font-medium text-foreground">
                        {creating ? "新建场次" : activeMatch?.name ?? "场次详情"}
                      </h2>
                      <p className="mt-1 text-xs leading-5 text-muted-foreground">
                        基础信息、名单和赛果都在当前面板内完成。
                      </p>
                    </div>
                    {activeMatch ? (
                      <div className="flex flex-wrap items-center gap-2">
                        <WorkspaceTag>{activeMatch.format}</WorkspaceTag>
                        <WorkspaceTag tone="soft">{activeMatch.status}</WorkspaceTag>
                      </div>
                    ) : null}
                  </div>
                </div>

                {!creating && activeMatch ? (
                  <WorkspaceTabs
                    value={activeTab}
                    onChange={setTab}
                    tabs={[
                      { value: "base", label: "基础信息" },
                      { value: "roster", label: "对阵与名单" },
                      { value: "result", label: "结果与状态" },
                      { value: "danger", label: "危险操作" },
                    ]}
                  />
                ) : null}

                {(creating || activeTab === "base") && (
                  <form className="flex flex-1 flex-col gap-4" onSubmit={submit}>
                    <div className="grid gap-4 lg:grid-cols-2">
                      {creating ? (
                        <FieldGroup label="所属赛事">
                          <Select value={activeMatchTournamentId} onValueChange={(value) => setMatchTournamentId(value ?? "")}>
                            <SelectTrigger className="h-10 rounded-2xl">
                              <SelectValue placeholder="选择赛事" />
                            </SelectTrigger>
                            <SelectContent>
                              {(tournamentsQuery.data?.items ?? []).map((item) => (
                                <SelectItem key={item.id} value={item.id}>
                                  {item.name}
                                </SelectItem>
                              ))}
                            </SelectContent>
                          </Select>
                        </FieldGroup>
                      ) : (
                        <FieldGroup label="所属赛事">
                          <Input value={activeMatch?.tournamentName ?? activeMatch?.tournamentId ?? ""} readOnly className="h-10 rounded-2xl" />
                        </FieldGroup>
                      )}

                      <FieldGroup label="赛制">
                        <Select
                          value={formatValue}
                          onValueChange={(value) => form.setValue("format", value as MatchCreateValues["format"], { shouldDirty: true })}
                        >
                          <SelectTrigger className="h-10 rounded-2xl">
                            <SelectValue placeholder="赛制" />
                          </SelectTrigger>
                          <SelectContent>
                            {matchFormats.map((format) => (
                              <SelectItem key={format} value={format}>
                                {format}
                              </SelectItem>
                            ))}
                          </SelectContent>
                        </Select>
                      </FieldGroup>

                      <FieldGroup label="场次名称">
                        <Input {...form.register("name")} placeholder="第 1 轮" className="h-10 rounded-2xl" />
                      </FieldGroup>
                      <FieldGroup label="地点">
                        <Input {...form.register("location")} placeholder="一号厅" className="h-10 rounded-2xl" />
                      </FieldGroup>
                      <FieldGroup label="开始时间">
                        <Input {...form.register("start_time")} type="datetime-local" className="h-10 rounded-2xl" />
                      </FieldGroup>
                      <FieldGroup label="结束时间">
                        <Input {...form.register("end_time")} type="datetime-local" className="h-10 rounded-2xl" />
                      </FieldGroup>
                    </div>

                    <FieldGroup label="辩题" hint="可留空">
                      <Textarea {...form.register("topic")} placeholder="请输入辩题" className="rounded-[22px]" />
                    </FieldGroup>

                    <div className="grid gap-4 lg:grid-cols-2">
                      <FieldGroup label="A 队" hint="搜索队伍并选择">
                        <SearchPicker
                          value={teamAIdValue ?? ""}
                          searchValue={teamSearchA}
                          onSearchChange={setTeamSearchA}
                          onSelect={(id) => form.setValue("team_a_id", id, { shouldDirty: true })}
                          items={teamAItems}
                          placeholder="搜索 A 队"
                          emptyText="没有匹配的队伍。"
                        />
                      </FieldGroup>
                      <FieldGroup label="B 队" hint="搜索队伍并选择">
                        <SearchPicker
                          value={teamBIdValue ?? ""}
                          searchValue={teamSearchB}
                          onSearchChange={setTeamSearchB}
                          onSelect={(id) => form.setValue("team_b_id", id, { shouldDirty: true })}
                          items={teamBItems}
                          placeholder="搜索 B 队"
                          emptyText="没有匹配的队伍。"
                        />
                      </FieldGroup>
                    </div>

                    <FieldGroup label="外部对手名称" hint="无内部对阵时可填写">
                      <Input {...form.register("opponent_team_name")} placeholder="外校联队" className="h-10 rounded-2xl" />
                    </FieldGroup>

                    <div className="mt-auto flex flex-wrap items-center justify-between gap-2 border-t border-border/60 pt-4">
                      {creating ? (
                        <Button
                          type="button"
                          variant="ghost"
                          onClick={() => {
                            setCreating(false)
                            if (matchesQuery.data?.items[0]?.id) {
                              setSelectedId(matchesQuery.data.items[0].id)
                            }
                          }}
                        >
                          取消
                        </Button>
                      ) : <div />}
                      <Button type="submit" disabled={saveMutation.isPending}>
                        {creating ? "创建场次" : "保存变更"}
                      </Button>
                    </div>
                  </form>
                )}

                {!creating && activeMatch && activeTab === "roster" && (
                  <div className="space-y-4">
                    {rosterTeams.length ? (
                      rosterTeams.map((team) => (
                        <WorkspaceSection key={team.key} title={team.label} hint="为每个辩位分配队员并单独保存。">
                          <div className="grid gap-3 md:grid-cols-2">
                            {positionsForFormat(activeMatch.format).map((position) => (
                              <FieldGroup key={position} label={`辩位 ${position}`}>
                                <Select
                                  value={rosterDrafts[team.key]?.[position] || "__empty__"}
                                  onValueChange={(value) =>
                                    setRosterDraftsByMatch((current) => {
                                      const nextValue = value === "__empty__" ? "" : value ?? ""
                                      return {
                                        ...current,
                                        [activeMatch.id]: {
                                          ...(current[activeMatch.id] ?? {}),
                                          [team.key]: {
                                            ...((current[activeMatch.id] ?? {})[team.key] ?? {}),
                                            [position]: nextValue,
                                          },
                                        },
                                      }
                                    })
                                  }
                                >
                                  <SelectTrigger className="h-10 rounded-2xl">
                                    <SelectValue placeholder="选择队员" />
                                  </SelectTrigger>
                                  <SelectContent>
                                    <SelectItem value="__empty__">暂不安排</SelectItem>
                                    {(team.detail?.members ?? []).map((member) => (
                                      <SelectItem key={member.id} value={member.userId}>
                                        {member.nickname} · {member.publicId}
                                      </SelectItem>
                                    ))}
                                  </SelectContent>
                                </Select>
                              </FieldGroup>
                            ))}
                          </div>
                          <Button
                            onClick={() =>
                              rosterMutation.mutate({
                                teamId: team.key,
                                assignments: positionsForFormat(activeMatch.format)
                                  .map((position) => ({
                                    user_id: rosterDrafts[team.key]?.[position] ?? "",
                                    position,
                                  }))
                                  .filter((item) => item.user_id),
                              })
                            }
                          >
                            保存 {team.label} 名单
                          </Button>
                        </WorkspaceSection>
                      ))
                    ) : (
                      <WorkspaceDetailEmpty title="先指定对阵队伍" hint="名单编辑依赖 A/B 队已设置。" />
                    )}
                  </div>
                )}

                {!creating && activeMatch && activeTab === "result" && (
                  <div className="space-y-4">
                    <WorkspaceSection title="状态推进" hint="直接推进当前场次状态。">
                      <div className="flex flex-wrap gap-2">
                        {matchStatuses.map((status) => (
                          <Button key={status} variant={status === activeMatch.status ? "default" : "outline"} onClick={() => statusMutation.mutate(status)}>
                            {status}
                          </Button>
                        ))}
                      </div>
                    </WorkspaceSection>

                    <WorkspaceSection title="录入赛果" hint="胜方必须属于当前 A/B 队。">
                      <div className="grid gap-4 lg:grid-cols-2">
                        <FieldGroup label="胜方">
                          <Select
                            value={resultDraft.winner_team_id || "__empty__"}
                            onValueChange={(value) =>
                              setResultDraftsByMatch((current) => ({
                                ...current,
                                [activeMatch.id]: {
                                  ...(current[activeMatch.id] ?? createResultDraft(activeMatch)),
                                  winner_team_id: value === "__empty__" ? "" : value ?? "",
                                },
                              }))
                            }
                          >
                            <SelectTrigger className="h-10 rounded-2xl">
                              <SelectValue placeholder="选择胜方" />
                            </SelectTrigger>
                            <SelectContent>
                              <SelectItem value="__empty__">暂不选择</SelectItem>
                              {activeMatch.teamAId ? (
                                <SelectItem value={activeMatch.teamAId}>
                                  {activeMatch.teamAName ?? activeMatch.teamAId}
                                </SelectItem>
                              ) : null}
                              {activeMatch.teamBId ? (
                                <SelectItem value={activeMatch.teamBId}>
                                  {activeMatch.teamBName ?? activeMatch.teamBId}
                                </SelectItem>
                              ) : null}
                            </SelectContent>
                          </Select>
                        </FieldGroup>
                        <FieldGroup label="最佳辩位" hint="可留空">
                          <Input
                            value={resultDraft.best_debater_position ?? ""}
                            onChange={(event) =>
                              setResultDraftsByMatch((current) => ({
                                ...current,
                                [activeMatch.id]: {
                                  ...(current[activeMatch.id] ?? createResultDraft(activeMatch)),
                                  best_debater_position: event.target.value,
                                },
                              }))
                            }
                            className="h-10 rounded-2xl"
                          />
                        </FieldGroup>
                        <FieldGroup label="A 队分数">
                          <Input
                            type="number"
                            min={0}
                            value={resultDraft.team_a_score}
                            onChange={(event) =>
                              setResultDraftsByMatch((current) => ({
                                ...current,
                                [activeMatch.id]: {
                                  ...(current[activeMatch.id] ?? createResultDraft(activeMatch)),
                                  team_a_score: Number(event.target.value || 0),
                                },
                              }))
                            }
                            className="h-10 rounded-2xl"
                          />
                        </FieldGroup>
                        <FieldGroup label="B 队分数">
                          <Input
                            type="number"
                            min={0}
                            value={resultDraft.team_b_score}
                            onChange={(event) =>
                              setResultDraftsByMatch((current) => ({
                                ...current,
                                [activeMatch.id]: {
                                  ...(current[activeMatch.id] ?? createResultDraft(activeMatch)),
                                  team_b_score: Number(event.target.value || 0),
                                },
                              }))
                            }
                            className="h-10 rounded-2xl"
                          />
                        </FieldGroup>
                      </div>

                      <FieldGroup label="备注" hint="可留空">
                        <Textarea
                          value={resultDraft.result_note ?? ""}
                          onChange={(event) =>
                            setResultDraftsByMatch((current) => ({
                              ...current,
                              [activeMatch.id]: {
                                ...(current[activeMatch.id] ?? createResultDraft(activeMatch)),
                                result_note: event.target.value,
                              },
                            }))
                          }
                          className="rounded-[22px]"
                        />
                      </FieldGroup>

                      <Button onClick={() => resultMutation.mutate(resultDraft)}>保存赛果</Button>
                    </WorkspaceSection>
                  </div>
                )}

                {!creating && activeMatch && activeTab === "danger" && (
                  <WorkspaceSection title="删除场次" hint="删除后会清理本场相关通知和阵容。">
                    <div className="rounded-[24px] border border-destructive/20 bg-destructive/5 p-5">
                      <p className="text-sm leading-6 text-foreground">
                        当前操作会删除 <span className="font-medium">{activeMatch.name}</span> 以及其全部名单记录。
                      </p>
                      <Button className="mt-4" variant="destructive" onClick={() => setDeleteOpen(true)}>
                        <Trash2 className="size-4" />
                        删除场次
                      </Button>
                    </div>
                  </WorkspaceSection>
                )}
              </div>
            ) : (
              <WorkspaceDetailEmpty
                title="选择一场场次"
                hint="在左侧选中对象，或者基于当前赛事新建一场。"
                action={
                  <Button
                    onClick={() => {
                      setCreating(true)
                      setSelectedId(null)
                      setTab("base")
                      form.reset(createDefaults())
                      setMatchTournamentId(tournamentFilter !== "all" ? tournamentFilter : "")
                    }}
                  >
                    <CalendarRange className="size-4" />
                    新建场次
                  </Button>
                }
              />
            )}
          </WorkspacePane>
        }
      />

      <AlertDialog open={deleteOpen} onOpenChange={setDeleteOpen}>
        <AlertDialogContent size="sm">
          <AlertDialogHeader>
            <AlertDialogMedia>
              <CalendarRange className="size-5 text-destructive" />
            </AlertDialogMedia>
            <AlertDialogTitle>删除场次</AlertDialogTitle>
            <AlertDialogDescription>该操作会删除场次本体，并清理本场相关通知和名单。</AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>取消</AlertDialogCancel>
            <AlertDialogAction variant="destructive" onClick={() => deleteMutation.mutate()}>
              确认删除
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  )
}
