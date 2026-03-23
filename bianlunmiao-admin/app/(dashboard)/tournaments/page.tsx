"use client"

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query"
import { CalendarRange, Plus, Trash2, Trophy } from "lucide-react"
import Link from "next/link"
import { useDeferredValue, useEffect, useMemo, useState } from "react"
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
import { Badge } from "@/components/ui/badge"
import { Button, buttonVariants } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Textarea } from "@/components/ui/textarea"
import { cn } from "@/lib/utils"
import {
  addTournamentParticipant,
  createTournament,
  deleteTournament,
  getTeams,
  getTournaments,
  getTournamentDetail,
  getUsers,
  removeTournamentParticipant,
  updateTournament,
} from "@/lib/api/admin"
import { formatDateTime } from "@/lib/format"
import {
  tournamentCreateSchema,
  tournamentEditSchema,
  type TournamentCreateValues,
} from "@/lib/schemas/admin"

const createDefaults: TournamentCreateValues = {
  creator_id: "",
  name: "",
  intro: "",
  cover_url: "",
  status: 0,
  start_date: "",
  end_date: "",
}

function tournamentStatusLabel(status: number) {
  if (status === 2) return "已结束"
  if (status === 1) return "进行中"
  return "开放"
}

function tournamentStatusTone(status: number) {
  if (status === 2) return "border-slate-500/20 bg-slate-500/10 text-slate-700"
  if (status === 1) return "border-amber-600/20 bg-amber-600/10 text-amber-700"
  return "border-emerald-600/20 bg-emerald-600/10 text-emerald-700"
}

export default function TournamentsPage() {
  const { request } = useAuth()
  const queryClient = useQueryClient()
  const [search, setSearch] = useState("")
  const deferredSearch = useDeferredValue(search)
  const [statusFilter, setStatusFilter] = useState("all")
  const [selectedId, setSelectedId] = useState<string | null>(null)
  const [creating, setCreating] = useState(false)
  const [tab, setTab] = useState("base")
  const [creatorSearch, setCreatorSearch] = useState("")
  const [participantSearch, setParticipantSearch] = useState("")
  const [deleteOpen, setDeleteOpen] = useState(false)

  const deferredCreatorSearch = useDeferredValue(creatorSearch)
  const deferredParticipantSearch = useDeferredValue(participantSearch)

  const form = useForm<TournamentCreateValues>({ defaultValues: createDefaults })
  const statusValue = useWatch({ control: form.control, name: "status" })
  const creatorIdValue = useWatch({ control: form.control, name: "creator_id" })

  const tournamentsQuery = useQuery({
    queryKey: ["admin-tournaments", deferredSearch, statusFilter],
    queryFn: () => getTournaments(request, { q: deferredSearch, status: statusFilter }),
  })

  const list = tournamentsQuery.data?.items ?? []
  const firstTournamentId = list[0]?.id ?? null
  const effectiveSelectedId = creating ? null : selectedId ?? firstTournamentId

  const detailQuery = useQuery({
    queryKey: ["admin-tournament-detail", effectiveSelectedId],
    queryFn: () => getTournamentDetail(request, effectiveSelectedId!),
    enabled: Boolean(effectiveSelectedId) && !creating,
  })

  const creatorCandidatesQuery = useQuery({
    queryKey: ["admin-users", "tournament-creator", deferredCreatorSearch],
    queryFn: () => getUsers(request, { q: deferredCreatorSearch, status: "0" }),
  })

  const participantCandidatesQuery = useQuery({
    queryKey: ["admin-teams", "tournament-participant", deferredParticipantSearch],
    queryFn: () => getTeams(request, { q: deferredParticipantSearch, status: "0" }),
    enabled: !creating && Boolean(effectiveSelectedId),
  })

  const selectedTournament = creating ? null : list.find((item) => item.id === effectiveSelectedId) ?? null
  const activeTournament = detailQuery.data ?? selectedTournament
  const activeTab = creating ? "base" : tab

  useEffect(() => {
    if (creating) {
      form.reset(createDefaults)
      return
    }

    if (detailQuery.data) {
      form.reset({
        creator_id: detailQuery.data.creatorId,
        name: detailQuery.data.name,
        intro: detailQuery.data.intro ?? "",
        cover_url: detailQuery.data.coverUrl ?? "",
        status: detailQuery.data.status,
        start_date: detailQuery.data.startDate ?? "",
        end_date: detailQuery.data.endDate ?? "",
      })
    }
  }, [creating, detailQuery.data, form])

  const saveMutation = useMutation({
    mutationFn: async (values: TournamentCreateValues) => {
      if (creating) {
        return createTournament(request, tournamentCreateSchema.parse(values))
      }

      return updateTournament(
        request,
        effectiveSelectedId!,
        tournamentEditSchema.parse({
          name: values.name,
          intro: values.intro,
          cover_url: values.cover_url,
          status: values.status,
          start_date: values.start_date,
          end_date: values.end_date,
        })
      )
    },
    onSuccess: async (data) => {
      toast.success(creating ? "赛事已创建" : "赛事已更新")
      setCreating(false)
      setSelectedId(data.id)
      await Promise.all([
        queryClient.invalidateQueries({ queryKey: ["admin-tournaments"] }),
        queryClient.invalidateQueries({ queryKey: ["admin-tournament-detail", data.id] }),
      ])
    },
    onError: (error) => {
      toast.error(error instanceof Error ? error.message : "提交失败")
    },
  })

  const addParticipantMutation = useMutation({
    mutationFn: (teamId: string) => addTournamentParticipant(request, effectiveSelectedId!, { team_id: teamId }),
    onSuccess: async () => {
      toast.success("参赛队伍已加入赛事")
      setParticipantSearch("")
      await Promise.all([
        queryClient.invalidateQueries({ queryKey: ["admin-tournament-detail", effectiveSelectedId] }),
        queryClient.invalidateQueries({ queryKey: ["admin-tournaments"] }),
      ])
    },
    onError: (error) => {
      toast.error(error instanceof Error ? error.message : "添加参赛队伍失败")
    },
  })

  const removeParticipantMutation = useMutation({
    mutationFn: (participantId: string) => removeTournamentParticipant(request, effectiveSelectedId!, participantId),
    onSuccess: async () => {
      toast.success("参赛队伍已移除")
      await Promise.all([
        queryClient.invalidateQueries({ queryKey: ["admin-tournament-detail", effectiveSelectedId] }),
        queryClient.invalidateQueries({ queryKey: ["admin-tournaments"] }),
        queryClient.invalidateQueries({ queryKey: ["admin-match-list"] }),
      ])
    },
    onError: (error) => {
      toast.error(error instanceof Error ? error.message : "移除参赛队伍失败")
    },
  })

  const deleteMutation = useMutation({
    mutationFn: () => deleteTournament(request, effectiveSelectedId!),
    onSuccess: async () => {
      toast.success("赛事已删除")
      setDeleteOpen(false)
      setSelectedId(null)
      setCreating(false)
      await queryClient.invalidateQueries({ queryKey: ["admin-tournaments"] })
    },
    onError: (error) => {
      toast.error(error instanceof Error ? error.message : "删除失败")
    },
  })

  const creatorItems = useMemo(
    () =>
      (creatorCandidatesQuery.data?.items ?? []).map((item) => ({
        id: item.id,
        title: item.nickname,
        subtitle: item.publicId,
      })),
    [creatorCandidatesQuery.data?.items]
  )

  const participantItems = useMemo(() => {
    const existing = new Set((activeTournament?.participants ?? []).map((item) => item.teamId))
    return (participantCandidatesQuery.data?.items ?? [])
      .filter((item) => !existing.has(item.id))
      .map((item) => ({
        id: item.id,
        title: item.name,
        subtitle: item.publicId,
        meta: `${item.memberCount} 人`,
      }))
  }, [activeTournament?.participants, participantCandidatesQuery.data?.items])

  const submit = form.handleSubmit((values) => {
    form.clearErrors()
    const parsed = creating
      ? tournamentCreateSchema.safeParse(values)
      : tournamentEditSchema.safeParse({
          name: values.name,
          intro: values.intro,
          cover_url: values.cover_url,
          status: values.status,
          start_date: values.start_date,
          end_date: values.end_date,
        })

    if (!parsed.success) {
      for (const issue of parsed.error.issues) {
        const field = issue.path[0]
        if (typeof field === "string") {
          form.setError(field as keyof TournamentCreateValues, {
            type: "manual",
            message: issue.message,
          })
        }
      }
      return
    }

    saveMutation.mutate(values)
  })

  return (
    <div className="space-y-4">
      <WorkspaceHero
        eyebrow="resource workbench"
        title="赛事"
        description="赛事资料、参赛队伍和场次入口都在同一上下文里。"
        meta={<WorkspaceTag tone="soft">{list.length} 条结果</WorkspaceTag>}
        actions={
          <Button
            size="lg"
            onClick={() => {
              setCreating(true)
              setSelectedId(null)
              setTab("base")
              form.reset(createDefaults)
            }}
          >
            <Plus className="size-4" />
            新建赛事
          </Button>
        }
      />

      <WorkspaceGrid
        left={
          <WorkspacePane className="xl:sticky xl:top-4 xl:self-start">
            <WorkspaceSection title="列表" hint="按赛事名和状态快速定位。">
              <WorkspaceSearch
                value={search}
                onChange={setSearch}
                placeholder="搜索赛事名称"
                trailing={
                  <Select value={statusFilter} onValueChange={(value) => setStatusFilter(value ?? "all")}>
                    <SelectTrigger className="h-10 w-[136px] rounded-2xl">
                      <SelectValue placeholder="状态" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="all">全部状态</SelectItem>
                      <SelectItem value="0">开放</SelectItem>
                      <SelectItem value="1">进行中</SelectItem>
                      <SelectItem value="2">已结束</SelectItem>
                    </SelectContent>
                  </Select>
                }
              />
            </WorkspaceSection>

            <div className="mt-4 space-y-2">
              {list.length ? (
                list.map((tournament) => (
                  <WorkspaceListItem
                    key={tournament.id}
                    active={!creating && effectiveSelectedId === tournament.id}
                    title={tournament.name}
                    subtitle={tournament.creatorNickname ?? tournament.creatorId}
                    meta={`${tournament.participantCount} 队 / ${tournament.matchCount} 场`}
                    badge={
                      <Badge variant="outline" className={tournamentStatusTone(tournament.status)}>
                        {tournamentStatusLabel(tournament.status)}
                      </Badge>
                    }
                    onClick={() => {
                      setCreating(false)
                      setSelectedId(tournament.id)
                    }}
                  />
                ))
              ) : (
                <div className="rounded-[24px] border border-dashed border-border/70 bg-background/50 p-6 text-center">
                  <p className="text-sm font-medium text-foreground">没有匹配的赛事</p>
                  <p className="mt-2 text-xs leading-5 text-muted-foreground">调整关键词或状态筛选。</p>
                </div>
              )}
            </div>
          </WorkspacePane>
        }
        right={
          <WorkspacePane>
            {activeTournament || creating ? (
              <div className="flex min-h-0 flex-1 flex-col gap-4">
                <div className="flex flex-col gap-2 border-b border-border/60 pb-4">
                  <div className="flex flex-wrap items-center justify-between gap-3">
                    <div>
                      <h2 className="text-sm font-medium text-foreground">
                        {creating ? "新建赛事" : activeTournament?.name ?? "赛事详情"}
                      </h2>
                      <p className="mt-1 text-xs leading-5 text-muted-foreground">
                        资料、参赛队伍和场次入口都在右侧。
                      </p>
                    </div>
                    {activeTournament ? (
                      <div className="flex flex-wrap items-center gap-2">
                        <WorkspaceTag>{activeTournament.matchCount} 场</WorkspaceTag>
                        <WorkspaceTag tone="soft">{activeTournament.participantCount} 队</WorkspaceTag>
                      </div>
                    ) : null}
                  </div>
                </div>

                {!creating && activeTournament ? (
                  <WorkspaceTabs
                    value={activeTab}
                    onChange={setTab}
                    tabs={[
                      { value: "base", label: "基础信息" },
                      { value: "participants", label: "参赛队伍", meta: `${activeTournament.participants?.length ?? 0}` },
                      { value: "matches", label: "场次", meta: `${activeTournament.matches?.length ?? 0}` },
                      { value: "danger", label: "危险操作" },
                    ]}
                  />
                ) : null}

                {(creating || activeTab === "base") && (
                  <form className="flex flex-1 flex-col gap-4" onSubmit={submit}>
                    <div className="grid gap-4 lg:grid-cols-2">
                      <FieldGroup label="赛事名称">
                        <Input {...form.register("name")} placeholder="春季赛" className="h-10 rounded-2xl" />
                      </FieldGroup>
                      <FieldGroup label="状态">
                        <Select
                          value={String(statusValue)}
                          onValueChange={(value) => form.setValue("status", Number(value), { shouldDirty: true })}
                        >
                          <SelectTrigger className="h-10 rounded-2xl">
                            <SelectValue placeholder="状态" />
                          </SelectTrigger>
                          <SelectContent>
                            <SelectItem value="0">开放</SelectItem>
                            <SelectItem value="1">进行中</SelectItem>
                            <SelectItem value="2">已结束</SelectItem>
                          </SelectContent>
                        </Select>
                      </FieldGroup>
                      <FieldGroup label="开始日期">
                        <Input {...form.register("start_date")} type="date" className="h-10 rounded-2xl" />
                      </FieldGroup>
                      <FieldGroup label="结束日期">
                        <Input {...form.register("end_date")} type="date" className="h-10 rounded-2xl" />
                      </FieldGroup>
                    </div>

                    <FieldGroup label="简介" hint="可留空">
                      <Textarea {...form.register("intro")} placeholder="赛事简介" className="rounded-[22px]" />
                    </FieldGroup>

                    <FieldGroup label="封面 URL" hint="可留空">
                      <Input {...form.register("cover_url")} placeholder="https://..." className="h-10 rounded-2xl" />
                    </FieldGroup>

                    {creating ? (
                      <FieldGroup label="创建者用户" hint="按昵称或 PublicId 搜索">
                        <SearchPicker
                          value={creatorIdValue}
                          searchValue={creatorSearch}
                          onSearchChange={setCreatorSearch}
                          onSelect={(id) => form.setValue("creator_id", id, { shouldDirty: true })}
                          items={creatorItems}
                          placeholder="搜索赛事创建者"
                          emptyText="没有找到可用用户。"
                        />
                      </FieldGroup>
                    ) : activeTournament ? (
                      <WorkspaceSection title="系统信息" hint="场次工作台支持从这里直接进入。">
                        <div className="grid gap-3 md:grid-cols-2">
                          <div className="rounded-[20px] border border-border/60 bg-background/60 p-4">
                            <p className="text-xs uppercase tracking-[0.2em] text-muted-foreground">创建者</p>
                            <p className="mt-2 text-sm text-foreground">{activeTournament.creatorNickname ?? "未知用户"}</p>
                            <p className="mt-1 break-all text-xs text-muted-foreground">{activeTournament.creatorId}</p>
                          </div>
                          <div className="rounded-[20px] border border-border/60 bg-background/60 p-4">
                            <p className="text-xs uppercase tracking-[0.2em] text-muted-foreground">更新时间</p>
                            <p className="mt-2 text-sm text-foreground">{formatDateTime(activeTournament.updatedAt)}</p>
                          </div>
                        </div>
                      </WorkspaceSection>
                    ) : null}

                    <div className="mt-auto flex flex-wrap items-center justify-between gap-2 border-t border-border/60 pt-4">
                      {creating ? (
                        <Button
                          type="button"
                          variant="ghost"
                          onClick={() => {
                            setCreating(false)
                            if (list[0]?.id) {
                              setSelectedId(list[0].id)
                            }
                          }}
                        >
                          取消
                        </Button>
                      ) : <div />}
                      <Button type="submit" disabled={saveMutation.isPending}>
                        {creating ? "创建赛事" : "保存变更"}
                      </Button>
                    </div>
                  </form>
                )}

                {!creating && activeTournament && activeTab === "participants" && (
                  <div className="space-y-4">
                    <WorkspaceSection title="添加参赛队伍" hint="搜索队伍后直接加入赛事。">
                      <SearchPicker
                        value=""
                        searchValue={participantSearch}
                        onSearchChange={setParticipantSearch}
                        onSelect={(id) => addParticipantMutation.mutate(id)}
                        items={participantItems}
                        placeholder="搜索队伍加入赛事"
                        emptyText="没有可添加的队伍。"
                      />
                    </WorkspaceSection>

                    <WorkspaceSection title="当前参赛队伍" hint="移除参赛队伍时会同步清理相关场次中的引用。">
                      <div className="space-y-2">
                        {(activeTournament.participants ?? []).map((participant) => (
                          <div key={participant.id} className="rounded-[22px] border border-border/60 bg-background/55 p-4">
                            <div className="flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between">
                              <div>
                                <p className="text-sm font-medium text-foreground">{participant.teamName ?? participant.teamId}</p>
                                <p className="mt-1 text-xs text-muted-foreground">{participant.teamPublicId ?? participant.teamId}</p>
                              </div>
                              <div className="flex flex-wrap items-center gap-2">
                                <WorkspaceTag tone="soft">Seed {participant.seed}</WorkspaceTag>
                                <WorkspaceTag>{participant.status}</WorkspaceTag>
                                <Button
                                  size="sm"
                                  variant="destructive"
                                  onClick={() => removeParticipantMutation.mutate(participant.id)}
                                >
                                  移除
                                </Button>
                              </div>
                            </div>
                          </div>
                        ))}
                      </div>
                    </WorkspaceSection>
                  </div>
                )}

                {!creating && activeTournament && activeTab === "matches" && (
                  <WorkspaceSection
                    title="场次"
                    hint="直接跳到场次工作台继续编辑，保持赛事上下文。"
                    action={
                      <Link
                        href={`/matches?tournamentId=${activeTournament.id}&create=1`}
                        className={cn(buttonVariants({ variant: "outline" }))}
                      >
                        <Plus className="size-4" />
                        新建场次
                      </Link>
                    }
                  >
                    <div className="space-y-2">
                      {(activeTournament.matches ?? []).length ? (
                        activeTournament.matches?.map((match) => (
                          <Link
                            key={match.id}
                            href={`/matches?tournamentId=${activeTournament.id}&selected=${match.id}`}
                            className="block rounded-[22px] border border-border/60 bg-background/55 p-4 transition-colors hover:bg-background/80"
                          >
                            <div className="flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between">
                              <div>
                                <p className="text-sm font-medium text-foreground">{match.name}</p>
                                <p className="mt-1 text-xs text-muted-foreground">
                                  {(match.teamAName ?? match.teamAId ?? "待定")} vs {(match.teamBName ?? match.teamBId ?? "待定")}
                                </p>
                              </div>
                              <div className="flex flex-wrap items-center gap-2">
                                <WorkspaceTag tone="soft">{match.format}</WorkspaceTag>
                                <WorkspaceTag>{match.status}</WorkspaceTag>
                              </div>
                            </div>
                          </Link>
                        ))
                      ) : (
                        <WorkspaceDetailEmpty
                          title="还没有场次"
                          hint="从这里直接跳到场次工作台新建。"
                          action={
                            <Link
                              href={`/matches?tournamentId=${activeTournament.id}&create=1`}
                              className={cn(buttonVariants())}
                            >
                              <CalendarRange className="size-4" />
                              新建场次
                            </Link>
                          }
                        />
                      )}
                    </div>
                  </WorkspaceSection>
                )}

                {!creating && activeTournament && activeTab === "danger" && (
                  <WorkspaceSection title="删除赛事" hint="删除后会连带清理赛事下的场次和关联消息。">
                    <div className="rounded-[24px] border border-destructive/20 bg-destructive/5 p-5">
                      <p className="text-sm leading-6 text-foreground">
                        当前操作会删除 <span className="font-medium">{activeTournament.name}</span> 及其全部场次。
                      </p>
                      <Button className="mt-4" variant="destructive" onClick={() => setDeleteOpen(true)}>
                        <Trash2 className="size-4" />
                        删除赛事
                      </Button>
                    </div>
                  </WorkspaceSection>
                )}
              </div>
            ) : (
              <WorkspaceDetailEmpty
                title="选择一场赛事"
                hint="在左侧选中对象，或者直接新建。"
                action={
                  <Button
                    onClick={() => {
                      setCreating(true)
                      setSelectedId(null)
                      setTab("base")
                      form.reset(createDefaults)
                    }}
                  >
                    <Trophy className="size-4" />
                    新建赛事
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
              <Trophy className="size-5 text-destructive" />
            </AlertDialogMedia>
            <AlertDialogTitle>删除赛事</AlertDialogTitle>
            <AlertDialogDescription>该操作会删除赛事本体，并清理赛事下全部场次。</AlertDialogDescription>
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
