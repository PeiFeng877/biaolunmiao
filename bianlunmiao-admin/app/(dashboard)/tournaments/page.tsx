"use client"

import {
  useMutation,
  useQuery,
  useQueryClient,
} from "@tanstack/react-query"
import type { ColumnDef } from "@tanstack/react-table"
import {
  AlertTriangle,
  CalendarDays,
  ChevronRight,
  Plus,
  Search,
  Trash2,
  Trophy,
} from "lucide-react"
import { useDeferredValue, useEffect, useState } from "react"
import { useForm, useWatch } from "react-hook-form"
import { toast } from "sonner"

import { useAuth } from "@/components/admin/auth-provider"
import { DataTable } from "@/components/admin/data-table"
import { FieldGroup } from "@/components/admin/field-group"
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
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select"
import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetHeader,
  SheetTitle,
} from "@/components/ui/sheet"
import { Textarea } from "@/components/ui/textarea"
import {
  createTournament,
  deleteTournament,
  getTournamentDetail,
  getTournaments,
  updateTournament,
} from "@/lib/api/admin"
import { formatDateTime, formatDateValue } from "@/lib/format"
import { applyZodIssues } from "@/lib/forms"
import {
  tournamentCreateSchema,
  tournamentEditSchema,
  type AdminTournament,
  type TournamentCreateValues,
  type TournamentEditValues,
} from "@/lib/schemas/admin"

type SheetMode = "create" | "edit" | null
type PendingPayload =
  | { mode: "create"; values: TournamentCreateValues }
  | { mode: "edit"; values: TournamentEditValues }

const defaultValues: TournamentCreateValues = {
  creator_id: "",
  name: "",
  intro: "",
  cover_url: "",
  status: 0,
  start_date: "",
  end_date: "",
}

function tournamentStatusLabel(status: number) {
  if (status === 2) {
    return "已结束"
  }
  if (status === 1) {
    return "进行中"
  }
  return "开放"
}

function tournamentStatusTone(status: number) {
  if (status === 2) {
    return "border-slate-500/20 bg-slate-500/10 text-slate-700"
  }
  if (status === 1) {
    return "border-amber-600/20 bg-amber-600/10 text-amber-700"
  }
  return "border-emerald-600/20 bg-emerald-600/10 text-emerald-700"
}

export default function TournamentsPage() {
  const { request } = useAuth()
  const queryClient = useQueryClient()
  const [search, setSearch] = useState("")
  const deferredSearch = useDeferredValue(search)
  const [statusFilter, setStatusFilter] = useState("all")
  const [sheetMode, setSheetMode] = useState<SheetMode>(null)
  const [selectedId, setSelectedId] = useState<string | null>(null)
  const [selectedMatchId, setSelectedMatchId] = useState<string | null>(null)
  const [confirmOpen, setConfirmOpen] = useState(false)
  const [deleteOpen, setDeleteOpen] = useState(false)
  const [pendingPayload, setPendingPayload] = useState<PendingPayload | null>(null)

  const form = useForm<TournamentCreateValues>({
    defaultValues,
  })
  const statusValue = useWatch({
    control: form.control,
    name: "status",
  })

  const tournamentsQuery = useQuery({
    queryKey: ["admin-tournaments", deferredSearch, statusFilter],
    queryFn: () => getTournaments(request, { q: deferredSearch, status: statusFilter }),
  })

  const detailQuery = useQuery({
    queryKey: ["admin-tournament-detail", selectedId],
    queryFn: () => getTournamentDetail(request, selectedId!),
    enabled: sheetMode === "edit" && Boolean(selectedId),
  })

  useEffect(() => {
    if (sheetMode === "create") {
      form.reset(defaultValues)
      return
    }

    if (sheetMode === "edit" && detailQuery.data) {
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
  }, [detailQuery.data, form, sheetMode])

  const resetSheet = () => {
    setSheetMode(null)
    setSelectedId(null)
    setSelectedMatchId(null)
    setConfirmOpen(false)
    setDeleteOpen(false)
    setPendingPayload(null)
    form.reset(defaultValues)
  }

  const saveMutation = useMutation({
    mutationFn: async (payload: PendingPayload) => {
      if (payload.mode === "create") {
        return createTournament(request, payload.values)
      }

      return updateTournament(request, selectedId!, payload.values)
    },
    onSuccess: async (data, payload) => {
      toast.success(payload.mode === "create" ? "赛事已创建" : "赛事已更新")
      setConfirmOpen(false)
      setPendingPayload(null)
      setSheetMode("edit")
      setSelectedId(data.id)
      setSelectedMatchId(data.matches?.[0]?.id ?? null)
      form.reset({
        creator_id: data.creatorId,
        name: data.name,
        intro: data.intro ?? "",
        cover_url: data.coverUrl ?? "",
        status: data.status,
        start_date: data.startDate ?? "",
        end_date: data.endDate ?? "",
      })
      await Promise.all([
        queryClient.invalidateQueries({ queryKey: ["admin-tournaments"] }),
        queryClient.invalidateQueries({ queryKey: ["admin-tournament-detail", data.id] }),
      ])
    },
    onError: (error) => {
      toast.error(error instanceof Error ? error.message : "提交失败")
    },
  })

  const deleteMutation = useMutation({
    mutationFn: () => deleteTournament(request, selectedId!),
    onSuccess: async () => {
      toast.success("赛事已删除")
      setDeleteOpen(false)
      resetSheet()
      await queryClient.invalidateQueries({ queryKey: ["admin-tournaments"] })
    },
    onError: (error) => {
      toast.error(error instanceof Error ? error.message : "删除失败")
    },
  })

  const handleOpenConfirm = form.handleSubmit((values) => {
    form.clearErrors()

    if (sheetMode === "create") {
      const parsed = tournamentCreateSchema.safeParse(values)
      if (!parsed.success) {
        applyZodIssues(parsed.error, form.setError)
        return
      }
      setPendingPayload({ mode: "create", values: parsed.data })
      setConfirmOpen(true)
      return
    }

    const parsed = tournamentEditSchema.safeParse({
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
    setPendingPayload({ mode: "edit", values: parsed.data })
    setConfirmOpen(true)
  })

  const columns: ColumnDef<AdminTournament>[] = [
    {
      header: "赛事",
      cell: ({ row }) => (
        <div className="space-y-1">
          <p className="font-medium text-foreground">{row.original.name}</p>
          <p className="text-xs text-muted-foreground">
            创建者：{row.original.creatorNickname ?? "未知"}
          </p>
        </div>
      ),
    },
    {
      header: "规模",
      cell: ({ row }) => (
        <span className="text-sm text-muted-foreground">
          {row.original.participantCount} 队 / {row.original.matchCount} 场
        </span>
      ),
    },
    {
      header: "状态",
      cell: ({ row }) => (
        <Badge
          variant="outline"
          className={tournamentStatusTone(row.original.status)}
        >
          {tournamentStatusLabel(row.original.status)}
        </Badge>
      ),
    },
    {
      header: "最近更新",
      cell: ({ row }) => (
        <span className="text-sm text-muted-foreground">
          {formatDateTime(row.original.updatedAt)}
        </span>
      ),
    },
  ]

  const isCreate = sheetMode === "create"
  const isEdit = sheetMode === "edit"
  const effectiveSelectedMatchId =
    detailQuery.data?.matches?.some((match) => match.id === selectedMatchId)
      ? selectedMatchId
      : detailQuery.data?.matches?.[0]?.id ?? null
  const selectedMatch =
    detailQuery.data?.matches?.find((match) => match.id === effectiveSelectedMatchId) ?? null

  return (
    <div className="space-y-4">
      <Card className="surface-panel border-white/70">
        <CardHeader className="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
          <div>
            <CardTitle className="font-display text-3xl text-foreground">赛事池</CardTitle>
            <p className="mt-2 text-sm leading-6 text-muted-foreground">
              统一管理赛事名称、简介、封面、状态与日期，并支持新增或删除整场赛事。
            </p>
          </div>
          <div className="flex flex-wrap items-center gap-2">
            <Badge variant="outline" className="rounded-full px-3 py-1">
              {tournamentsQuery.data?.items.length ?? 0} 条当前结果
            </Badge>
            <Button
              size="lg"
              type="button"
              onClick={() => {
                setSelectedId(null)
                setSelectedMatchId(null)
                setSheetMode("create")
                setConfirmOpen(false)
                setDeleteOpen(false)
                setPendingPayload(null)
              }}
            >
              <Plus className="size-4" />
              新建赛事
            </Button>
          </div>
        </CardHeader>
        <CardContent className="grid gap-3 md:grid-cols-[1fr_220px]">
          <div className="relative">
            <Search className="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
            <Input
              value={search}
              onChange={(event) => setSearch(event.target.value)}
              placeholder="搜索赛事名称"
              className="pl-10"
            />
          </div>
          <Select
            value={statusFilter}
            onValueChange={(value) => setStatusFilter(value ?? "all")}
          >
            <SelectTrigger className="w-full">
              <SelectValue placeholder="筛选状态" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all">全部状态</SelectItem>
              <SelectItem value="0">开放</SelectItem>
              <SelectItem value="1">进行中</SelectItem>
              <SelectItem value="2">已结束</SelectItem>
            </SelectContent>
          </Select>
        </CardContent>
      </Card>

      <DataTable
        columns={columns}
        data={tournamentsQuery.data?.items ?? []}
        emptyTitle="还没有命中任何赛事"
        emptyHint="可以尝试修改搜索词，或切换到全部状态查看。"
        onRowClick={(row) => {
          setSelectedId(row.id)
          setSelectedMatchId(null)
          setSheetMode("edit")
          setConfirmOpen(false)
          setDeleteOpen(false)
          setPendingPayload(null)
        }}
      />

      <Sheet open={sheetMode !== null} onOpenChange={(open) => !open && resetSheet()}>
        <SheetContent className="w-full max-w-2xl overflow-y-auto bg-background/98 p-0 sm:max-w-2xl">
          <SheetHeader className="border-b border-border/70 px-6 py-5">
            <SheetTitle className="font-display text-3xl">
              {isCreate ? "新建赛事" : "赛事详情"}
            </SheetTitle>
            <SheetDescription>
              {isCreate
                ? "输入创建者业务用户 ID，即可创建赛事主体。场次与参与队伍仍通过业务链路补齐。"
                : "编辑赛事主字段，参与队伍与场次当前保持只读展示。"}
            </SheetDescription>
          </SheetHeader>

          <div className="space-y-6 px-6 py-6">
            {isEdit && detailQuery.data ? (
              <div className="grid gap-4 md:grid-cols-3">
                <Card className="border-border/70 bg-background/70">
                  <CardHeader className="pb-3">
                    <CardTitle className="text-sm text-muted-foreground">创建者</CardTitle>
                  </CardHeader>
                  <CardContent className="font-medium text-foreground">
                    {detailQuery.data.creatorNickname ?? detailQuery.data.creatorId}
                  </CardContent>
                </Card>
                <Card className="border-border/70 bg-background/70">
                  <CardHeader className="pb-3">
                    <CardTitle className="text-sm text-muted-foreground">参与队伍</CardTitle>
                  </CardHeader>
                  <CardContent className="text-sm text-foreground">
                    {detailQuery.data.participantCount} 队
                  </CardContent>
                </Card>
                <Card className="border-border/70 bg-background/70">
                  <CardHeader className="pb-3">
                    <CardTitle className="text-sm text-muted-foreground">最近更新</CardTitle>
                  </CardHeader>
                  <CardContent className="text-sm text-foreground">
                    {formatDateTime(detailQuery.data.updatedAt)}
                  </CardContent>
                </Card>
              </div>
            ) : null}

            {isEdit && detailQuery.isLoading ? (
              <p className="text-sm text-muted-foreground">正在加载赛事详情…</p>
            ) : null}

            {sheetMode ? (
              <>
                <form className="space-y-5">
                  {isCreate ? (
                    <FieldGroup
                      label="创建者用户 ID"
                      hint="使用业务用户 UUID"
                      error={form.formState.errors.creator_id?.message}
                    >
                      <Input
                        placeholder="f25928ba-9cb5-46e4-95f8-0e213904c4ac"
                        {...form.register("creator_id")}
                      />
                    </FieldGroup>
                  ) : null}

                  <FieldGroup
                    label="赛事名称"
                    error={form.formState.errors.name?.message}
                  >
                    <Input {...form.register("name")} />
                  </FieldGroup>

                  <FieldGroup
                    label="赛事简介"
                    error={form.formState.errors.intro?.message}
                  >
                    <Textarea rows={5} {...form.register("intro")} />
                  </FieldGroup>

                  <FieldGroup
                    label="封面 URL"
                    hint="可留空"
                    error={form.formState.errors.cover_url?.message}
                  >
                    <Input
                      placeholder="https://..."
                      {...form.register("cover_url")}
                    />
                  </FieldGroup>

                  <div className="grid gap-4 md:grid-cols-3">
                    <FieldGroup label="状态">
                      <Select
                        value={String(statusValue ?? 0)}
                        onValueChange={(value) =>
                          form.setValue("status", Number(value), { shouldDirty: true })
                        }
                      >
                        <SelectTrigger className="w-full">
                          <SelectValue />
                        </SelectTrigger>
                        <SelectContent>
                          <SelectItem value="0">开放</SelectItem>
                          <SelectItem value="1">进行中</SelectItem>
                          <SelectItem value="2">已结束</SelectItem>
                        </SelectContent>
                      </Select>
                    </FieldGroup>

                    <FieldGroup label="开始日期">
                      <Input type="date" {...form.register("start_date")} />
                    </FieldGroup>

                    <FieldGroup label="结束日期">
                      <Input type="date" {...form.register("end_date")} />
                    </FieldGroup>
                  </div>
                </form>

                {isEdit ? (
                  <Card className="border-border/70 bg-background/72">
                    <CardHeader>
                      <CardTitle className="flex items-center gap-2 text-lg text-foreground">
                        <CalendarDays className="size-4 text-primary" />
                        场次详情
                      </CardTitle>
                    </CardHeader>
                    <CardContent className="space-y-4">
                      {detailQuery.data?.matches?.length ? (
                        <div className="grid gap-4 lg:grid-cols-[280px_minmax(0,1fr)]">
                          <div className="space-y-3">
                            {detailQuery.data.matches.map((match) => {
                              const isActive = match.id === effectiveSelectedMatchId
                              return (
                                <button
                                  key={match.id}
                                  type="button"
                                  onClick={() => setSelectedMatchId(match.id)}
                                  className={`w-full rounded-2xl border px-4 py-3 text-left transition ${
                                    isActive
                                      ? "border-primary/40 bg-primary/8 shadow-sm"
                                      : "border-border/70 bg-muted/35 hover:border-primary/20 hover:bg-muted/55"
                                  }`}
                                >
                                  <div className="flex items-start justify-between gap-4">
                                    <div>
                                      <p className="font-medium text-foreground">{match.name}</p>
                                      <p className="mt-1 text-sm text-muted-foreground">
                                        {formatDateTime(match.startTime)}
                                      </p>
                                    </div>
                                    <div className="flex items-center gap-2">
                                      <Badge variant="outline">{match.status}</Badge>
                                      <ChevronRight className="size-4 text-muted-foreground" />
                                    </div>
                                  </div>
                                </button>
                              )
                            })}
                          </div>

                          {selectedMatch ? (
                            <div className="rounded-3xl border border-border/70 bg-muted/20 p-5">
                              <div className="flex flex-wrap items-center justify-between gap-3">
                                <div>
                                  <p className="text-xs uppercase tracking-[0.18em] text-muted-foreground">
                                    Match Snapshot
                                  </p>
                                  <h3 className="mt-2 text-xl font-semibold text-foreground">
                                    {selectedMatch.name}
                                  </h3>
                                </div>
                                <Badge variant="outline">{selectedMatch.status}</Badge>
                              </div>

                              <div className="mt-5 grid gap-4 md:grid-cols-2">
                                <div className="rounded-2xl border border-border/60 bg-background/80 p-4">
                                  <p className="text-sm text-muted-foreground">开始时间</p>
                                  <p className="mt-2 font-medium text-foreground">
                                    {formatDateTime(selectedMatch.startTime)}
                                  </p>
                                </div>
                                <div className="rounded-2xl border border-border/60 bg-background/80 p-4">
                                  <p className="text-sm text-muted-foreground">结束时间</p>
                                  <p className="mt-2 font-medium text-foreground">
                                    {formatDateTime(selectedMatch.endTime)}
                                  </p>
                                </div>
                                <div className="rounded-2xl border border-border/60 bg-background/80 p-4">
                                  <p className="text-sm text-muted-foreground">场地</p>
                                  <p className="mt-2 font-medium text-foreground">
                                    {selectedMatch.location ?? "未设置"}
                                  </p>
                                </div>
                                <div className="rounded-2xl border border-border/60 bg-background/80 p-4">
                                  <p className="text-sm text-muted-foreground">赛制</p>
                                  <p className="mt-2 font-medium text-foreground">
                                    {selectedMatch.format}
                                  </p>
                                </div>
                              </div>

                              <div className="mt-4 grid gap-4 md:grid-cols-2">
                                <div className="rounded-2xl border border-border/60 bg-background/80 p-4">
                                  <p className="text-sm text-muted-foreground">A 队</p>
                                  <p className="mt-2 font-medium text-foreground">
                                    {selectedMatch.teamAId ?? "未分配"}
                                  </p>
                                </div>
                                <div className="rounded-2xl border border-border/60 bg-background/80 p-4">
                                  <p className="text-sm text-muted-foreground">B 队 / 对手名</p>
                                  <p className="mt-2 font-medium text-foreground">
                                    {selectedMatch.teamBId ?? selectedMatch.opponentTeamName ?? "未分配"}
                                  </p>
                                </div>
                              </div>

                              <div className="mt-4 grid gap-4 md:grid-cols-2">
                                <div className="rounded-2xl border border-border/60 bg-background/80 p-4">
                                  <p className="text-sm text-muted-foreground">比分</p>
                                  <p className="mt-2 font-medium text-foreground">
                                    {selectedMatch.teamAScore ?? "—"} : {selectedMatch.teamBScore ?? "—"}
                                  </p>
                                </div>
                                <div className="rounded-2xl border border-border/60 bg-background/80 p-4">
                                  <p className="text-sm text-muted-foreground">最佳辩手位次</p>
                                  <p className="mt-2 font-medium text-foreground">
                                    {selectedMatch.bestDebaterPosition ?? "未记录"}
                                  </p>
                                </div>
                              </div>

                              <div className="mt-4 rounded-2xl border border-border/60 bg-background/80 p-4">
                                <p className="text-sm text-muted-foreground">辩题</p>
                                <p className="mt-2 leading-6 text-foreground">
                                  {selectedMatch.topic ?? "未填写辩题"}
                                </p>
                              </div>

                              <div className="mt-4 rounded-2xl border border-border/60 bg-background/80 p-4">
                                <p className="text-sm text-muted-foreground">结果备注</p>
                                <p className="mt-2 leading-6 text-foreground">
                                  {selectedMatch.resultNote ?? "暂无备注"}
                                </p>
                              </div>

                              <div className="mt-4 rounded-2xl border border-border/60 bg-background/80 p-4">
                                <div className="flex items-center justify-between gap-3">
                                  <p className="text-sm text-muted-foreground">出场名单</p>
                                  <p className="text-xs text-muted-foreground">
                                    记录时间：{formatDateValue(selectedMatch.resultRecordedAt)}
                                  </p>
                                </div>
                                {selectedMatch.rosters.length ? (
                                  <div className="mt-3 space-y-2">
                                    {selectedMatch.rosters.map((roster) => (
                                      <div
                                        key={roster.id}
                                        className="flex items-center justify-between gap-3 rounded-xl border border-border/50 px-3 py-2"
                                      >
                                        <span className="text-sm font-medium text-foreground">
                                          {roster.position}
                                        </span>
                                        <span className="text-xs text-muted-foreground">
                                          user: {roster.userId}
                                        </span>
                                      </div>
                                    ))}
                                  </div>
                                ) : (
                                  <p className="mt-3 text-sm leading-6 text-muted-foreground">
                                    当前场次还没有录入 roster。
                                  </p>
                                )}
                              </div>
                            </div>
                          ) : (
                            <div>
                              <p className="text-sm leading-6 text-muted-foreground">
                                选择左侧场次后可查看完整只读详情。
                              </p>
                            </div>
                          )}
                        </div>
                      ) : (
                        <p className="text-sm leading-6 text-muted-foreground">
                          当前赛事还没有场次，后台先只管理赛事主字段。
                        </p>
                      )}
                    </CardContent>
                  </Card>
                ) : null}

                <div className="rounded-[24px] border border-amber-200/70 bg-amber-50/70 p-4">
                  <div className="flex items-center gap-2 text-amber-700">
                    <AlertTriangle className="size-4" />
                    <p className="text-xs uppercase tracking-[0.2em]">lifecycle warning</p>
                  </div>
                  <p className="mt-3 text-sm leading-6 text-amber-900/90">
                    {isCreate
                      ? "这里只创建赛事主体，不直接创建场次与参与关系。开始和结束日期会直接进入赛事生命周期判断。"
                      : "赛事状态改为“已结束”后，后台仍可编辑基础文案，但前台生命周期语义会发生变化。开始与结束日期也会同步计入审计日志。"}
                  </p>
                </div>

                <div className="flex items-center justify-between gap-3">
                  <div>
                    {isEdit ? (
                      <Button
                        type="button"
                        variant="destructive"
                        size="lg"
                        onClick={() => setDeleteOpen(true)}
                      >
                        <Trash2 className="size-4" />
                        删除赛事
                      </Button>
                    ) : null}
                  </div>
                  <Button
                    size="lg"
                    onClick={handleOpenConfirm}
                    type="button"
                    disabled={saveMutation.isPending || (isEdit && !form.formState.isDirty)}
                  >
                    <Trophy className="size-4" />
                    {isCreate ? "创建赛事" : "保存修改"}
                  </Button>
                </div>
              </>
            ) : null}
          </div>
        </SheetContent>
      </Sheet>

      <AlertDialog
        open={confirmOpen}
        onOpenChange={(open) => {
          setConfirmOpen(open)
          if (!open) {
            setPendingPayload(null)
          }
        }}
      >
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogMedia>
              <AlertTriangle className="size-4 text-amber-700" />
            </AlertDialogMedia>
            <AlertDialogTitle>
              {pendingPayload?.mode === "create" ? "确认创建赛事？" : "确认写回赛事变更？"}
            </AlertDialogTitle>
            <AlertDialogDescription>
              {pendingPayload?.mode === "create"
                ? "提交后会立即创建赛事主体，并生成一条赛事审计日志。"
                : "提交后会立即更新赛事主字段，并追加一条赛事审计日志。"}
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>取消</AlertDialogCancel>
            <AlertDialogAction
              disabled={saveMutation.isPending || !pendingPayload}
              onClick={() => {
                if (!pendingPayload) {
                  return
                }
                saveMutation.mutate(pendingPayload)
              }}
            >
              {saveMutation.isPending ? "提交中" : "确认提交"}
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>

      <AlertDialog open={deleteOpen} onOpenChange={setDeleteOpen}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogMedia>
              <Trash2 className="size-4 text-destructive" />
            </AlertDialogMedia>
            <AlertDialogTitle>确认删除当前赛事？</AlertDialogTitle>
            <AlertDialogDescription>
              删除后会同步清理该赛事下的场次关联消息，并写入审计日志。该操作主要用于清理错误创建或测试数据。
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>取消</AlertDialogCancel>
            <AlertDialogAction
              variant="destructive"
              disabled={deleteMutation.isPending || !selectedId}
              onClick={() => deleteMutation.mutate()}
            >
              {deleteMutation.isPending ? "删除中" : "确认删除"}
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  )
}
