"use client"

import {
  useMutation,
  useQuery,
  useQueryClient,
} from "@tanstack/react-query"
import type { ColumnDef } from "@tanstack/react-table"
import {
  AlertTriangle,
  Plus,
  Search,
  Swords,
  Trash2,
  UsersRound,
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
  createTeam,
  deleteTeam,
  getTeamDetail,
  getTeams,
  updateTeam,
} from "@/lib/api/admin"
import { formatDateTime } from "@/lib/format"
import { applyZodIssues } from "@/lib/forms"
import {
  teamCreateSchema,
  teamEditSchema,
  type AdminTeam,
  type TeamCreateValues,
  type TeamEditValues,
} from "@/lib/schemas/admin"

type SheetMode = "create" | "edit" | null
type PendingPayload =
  | { mode: "create"; values: TeamCreateValues }
  | { mode: "edit"; values: TeamEditValues }

const defaultValues: TeamCreateValues = {
  owner_id: "",
  name: "",
  intro: "",
  avatar_url: "",
  status: 0,
}

function teamStatusLabel(status: number) {
  return status === 0 ? "可见" : "隐藏"
}

function teamStatusTone(status: number) {
  return status === 0
    ? "border-emerald-600/20 bg-emerald-600/10 text-emerald-700"
    : "border-amber-600/20 bg-amber-600/10 text-amber-700"
}

export default function TeamsPage() {
  const { request } = useAuth()
  const queryClient = useQueryClient()
  const [search, setSearch] = useState("")
  const deferredSearch = useDeferredValue(search)
  const [statusFilter, setStatusFilter] = useState("all")
  const [sheetMode, setSheetMode] = useState<SheetMode>(null)
  const [selectedId, setSelectedId] = useState<string | null>(null)
  const [confirmOpen, setConfirmOpen] = useState(false)
  const [deleteOpen, setDeleteOpen] = useState(false)
  const [pendingPayload, setPendingPayload] = useState<PendingPayload | null>(null)

  const form = useForm<TeamCreateValues>({
    defaultValues,
  })
  const statusValue = useWatch({
    control: form.control,
    name: "status",
  })

  const teamsQuery = useQuery({
    queryKey: ["admin-teams", deferredSearch, statusFilter],
    queryFn: () => getTeams(request, { q: deferredSearch, status: statusFilter }),
  })

  const detailQuery = useQuery({
    queryKey: ["admin-team-detail", selectedId],
    queryFn: () => getTeamDetail(request, selectedId!),
    enabled: sheetMode === "edit" && Boolean(selectedId),
  })

  useEffect(() => {
    if (sheetMode === "create") {
      form.reset(defaultValues)
      return
    }

    if (sheetMode === "edit" && detailQuery.data) {
      form.reset({
        owner_id: detailQuery.data.ownerId,
        name: detailQuery.data.name,
        intro: detailQuery.data.intro ?? "",
        avatar_url: detailQuery.data.avatarUrl ?? "",
        status: detailQuery.data.status,
      })
    }
  }, [detailQuery.data, form, sheetMode])

  const resetSheet = () => {
    setSheetMode(null)
    setSelectedId(null)
    setConfirmOpen(false)
    setDeleteOpen(false)
    setPendingPayload(null)
    form.reset(defaultValues)
  }

  const saveMutation = useMutation({
    mutationFn: async (payload: PendingPayload) => {
      if (payload.mode === "create") {
        return createTeam(request, payload.values)
      }

      return updateTeam(request, selectedId!, payload.values)
    },
    onSuccess: async (data, payload) => {
      toast.success(payload.mode === "create" ? "队伍已创建" : "队伍已更新")
      setConfirmOpen(false)
      setPendingPayload(null)
      setSheetMode("edit")
      setSelectedId(data.id)
      form.reset({
        owner_id: data.ownerId,
        name: data.name,
        intro: data.intro ?? "",
        avatar_url: data.avatarUrl ?? "",
        status: data.status,
      })
      await Promise.all([
        queryClient.invalidateQueries({ queryKey: ["admin-teams"] }),
        queryClient.invalidateQueries({ queryKey: ["admin-team-detail", data.id] }),
      ])
    },
    onError: (error) => {
      toast.error(error instanceof Error ? error.message : "提交失败")
    },
  })

  const deleteMutation = useMutation({
    mutationFn: () => deleteTeam(request, selectedId!),
    onSuccess: async () => {
      toast.success("队伍已删除")
      setDeleteOpen(false)
      resetSheet()
      await queryClient.invalidateQueries({ queryKey: ["admin-teams"] })
    },
    onError: (error) => {
      toast.error(error instanceof Error ? error.message : "删除失败")
    },
  })

  const handleOpenConfirm = form.handleSubmit((values) => {
    form.clearErrors()

    if (sheetMode === "create") {
      const parsed = teamCreateSchema.safeParse(values)
      if (!parsed.success) {
        applyZodIssues(parsed.error, form.setError)
        return
      }
      setPendingPayload({ mode: "create", values: parsed.data })
      setConfirmOpen(true)
      return
    }

    const parsed = teamEditSchema.safeParse({
      name: values.name,
      intro: values.intro,
      avatar_url: values.avatar_url,
      status: values.status,
    })
    if (!parsed.success) {
      for (const issue of parsed.error.issues) {
        const field = issue.path[0]
        if (typeof field === "string") {
          form.setError(field as keyof TeamCreateValues, {
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

  const columns: ColumnDef<AdminTeam>[] = [
    {
      header: "队伍",
      cell: ({ row }) => (
        <div className="space-y-1">
          <p className="font-medium text-foreground">{row.original.name}</p>
          <p className="text-xs uppercase tracking-[0.18em] text-muted-foreground">
            {row.original.publicId}
          </p>
        </div>
      ),
    },
    {
      header: "成员",
      cell: ({ row }) => (
        <span className="text-sm text-muted-foreground">{row.original.memberCount} 人</span>
      ),
    },
    {
      header: "状态",
      cell: ({ row }) => (
        <Badge
          variant="outline"
          className={teamStatusTone(row.original.status)}
        >
          {teamStatusLabel(row.original.status)}
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

  return (
    <div className="space-y-4">
      <Card className="surface-panel border-white/70">
        <CardHeader className="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
          <div>
            <CardTitle className="font-display text-3xl text-foreground">队伍池</CardTitle>
            <p className="mt-2 text-sm leading-6 text-muted-foreground">
              支持按队伍名或 `publicId` 搜索，并维护队伍主字段、创建新队伍或删除测试数据。
            </p>
          </div>
          <div className="flex flex-wrap items-center gap-2">
            <Badge variant="outline" className="rounded-full px-3 py-1">
              {teamsQuery.data?.items.length ?? 0} 条当前结果
            </Badge>
            <Button
              size="lg"
              type="button"
              onClick={() => {
                setSelectedId(null)
                setSheetMode("create")
                setConfirmOpen(false)
                setDeleteOpen(false)
                setPendingPayload(null)
              }}
            >
              <Plus className="size-4" />
              新建队伍
            </Button>
          </div>
        </CardHeader>
        <CardContent className="grid gap-3 md:grid-cols-[1fr_220px]">
          <div className="relative">
            <Search className="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
            <Input
              value={search}
              onChange={(event) => setSearch(event.target.value)}
              placeholder="搜索队伍名称或 publicId"
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
              <SelectItem value="0">可见</SelectItem>
              <SelectItem value="1">隐藏</SelectItem>
            </SelectContent>
          </Select>
        </CardContent>
      </Card>

      <DataTable
        columns={columns}
        data={teamsQuery.data?.items ?? []}
        emptyTitle="还没有命中任何队伍"
        emptyHint="可以换个关键词，或者切回全部状态查看。"
        onRowClick={(row) => {
          setSelectedId(row.id)
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
              {isCreate ? "新建队伍" : "队伍详情"}
            </SheetTitle>
            <SheetDescription>
              {isCreate
                ? "输入队长业务用户 ID 后即可创建队伍。成员关系后续仍通过业务链路维护。"
                : "编辑队伍主字段，成员关系保持只读显示。"}
            </SheetDescription>
          </SheetHeader>

          <div className="space-y-6 px-6 py-6">
            {isEdit && detailQuery.data ? (
              <div className="grid gap-4 md:grid-cols-3">
                <Card className="border-border/70 bg-background/70">
                  <CardHeader className="pb-3">
                    <CardTitle className="text-sm text-muted-foreground">队长</CardTitle>
                  </CardHeader>
                  <CardContent className="font-medium text-foreground">
                    {detailQuery.data.ownerNickname ?? detailQuery.data.ownerId}
                  </CardContent>
                </Card>
                <Card className="border-border/70 bg-background/70">
                  <CardHeader className="pb-3">
                    <CardTitle className="text-sm text-muted-foreground">成员数</CardTitle>
                  </CardHeader>
                  <CardContent className="text-sm text-foreground">
                    {detailQuery.data.memberCount} 人
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
              <p className="text-sm text-muted-foreground">正在加载队伍详情…</p>
            ) : null}

            {sheetMode ? (
              <>
                <form className="space-y-5">
                  {isCreate ? (
                    <FieldGroup
                      label="队长用户 ID"
                      hint="使用业务用户 UUID"
                      error={form.formState.errors.owner_id?.message}
                    >
                      <Input
                        placeholder="6e0fc3b3-ae64-4f07-8ff3-8aca5ccce902"
                        {...form.register("owner_id")}
                      />
                    </FieldGroup>
                  ) : null}

                  <FieldGroup
                    label="队伍名称"
                    error={form.formState.errors.name?.message}
                  >
                    <Input {...form.register("name")} />
                  </FieldGroup>

                  <FieldGroup
                    label="队伍简介"
                    error={form.formState.errors.intro?.message}
                  >
                    <Textarea rows={5} {...form.register("intro")} />
                  </FieldGroup>

                  <FieldGroup
                    label="头像 URL"
                    hint="可留空"
                    error={form.formState.errors.avatar_url?.message}
                  >
                    <Input
                      placeholder="https://..."
                      {...form.register("avatar_url")}
                    />
                  </FieldGroup>

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
                        <SelectItem value="0">可见</SelectItem>
                        <SelectItem value="1">隐藏</SelectItem>
                      </SelectContent>
                    </Select>
                  </FieldGroup>
                </form>

                {isEdit && detailQuery.data?.members?.length ? (
                  <Card className="border-border/70 bg-background/72">
                    <CardHeader>
                      <CardTitle className="flex items-center gap-2 text-lg text-foreground">
                        <UsersRound className="size-4 text-primary" />
                        成员只读快照
                      </CardTitle>
                    </CardHeader>
                    <CardContent className="space-y-3">
                      {detailQuery.data.members.map((member) => (
                        <div
                          key={member.id}
                          className="flex items-center justify-between rounded-2xl border border-border/70 bg-muted/35 px-4 py-3"
                        >
                          <div>
                            <p className="font-medium text-foreground">{member.nickname}</p>
                            <p className="text-xs uppercase tracking-[0.18em] text-muted-foreground">
                              {member.publicId}
                            </p>
                          </div>
                          <Badge variant="outline">
                            {member.role === 2 ? "队长" : member.role === 1 ? "管理员" : "成员"}
                          </Badge>
                        </div>
                      ))}
                    </CardContent>
                  </Card>
                ) : null}

                <div className="rounded-[24px] border border-amber-200/70 bg-amber-50/70 p-4">
                  <div className="flex items-center gap-2 text-amber-700">
                    <AlertTriangle className="size-4" />
                    <p className="text-xs uppercase tracking-[0.2em]">visibility notice</p>
                  </div>
                  <p className="mt-3 text-sm leading-6 text-amber-900/90">
                    {isCreate
                      ? "这里只创建队伍本体，不直接改成员关系。成员加入仍建议走业务申请与审批链路。"
                      : "队伍状态切换为“隐藏”后，后台仍可见，但前台展示与发现流量可能受到影响。"}
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
                        删除队伍
                      </Button>
                    ) : null}
                  </div>
                  <Button
                    size="lg"
                    onClick={handleOpenConfirm}
                    type="button"
                    disabled={saveMutation.isPending || (isEdit && !form.formState.isDirty)}
                  >
                    <Swords className="size-4" />
                    {isCreate ? "创建队伍" : "保存修改"}
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
              {pendingPayload?.mode === "create" ? "确认创建队伍？" : "确认写回队伍变更？"}
            </AlertDialogTitle>
            <AlertDialogDescription>
              {pendingPayload?.mode === "create"
                ? "提交后会立即创建队伍并生成一条队伍审计日志。"
                : "提交后会立即更新后端快照，并生成一条队伍审计日志。"}
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
            <AlertDialogTitle>确认删除当前队伍？</AlertDialogTitle>
            <AlertDialogDescription>
              删除后会清理队伍与场次的直接关联，并写入审计日志。该操作主要用于清理测试数据。
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
