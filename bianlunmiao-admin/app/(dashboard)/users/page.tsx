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
  Trash2,
  UserPlus,
  UserRoundCog,
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
import {
  createUser,
  deleteUser,
  getUserDetail,
  getUsers,
  updateUser,
} from "@/lib/api/admin"
import { formatDateTime } from "@/lib/format"
import { applyZodIssues } from "@/lib/forms"
import {
  userCreateSchema,
  userEditSchema,
  type AdminUser,
  type UserCreateValues,
  type UserEditValues,
} from "@/lib/schemas/admin"

type SheetMode = "create" | "edit" | null
type PendingPayload =
  | { mode: "create"; values: UserCreateValues }
  | { mode: "edit"; values: UserEditValues }

const defaultValues: UserCreateValues = {
  public_id: "",
  nickname: "",
  avatar_url: "",
  status: 0,
}

function userStatusLabel(status: number) {
  if (status === 2) {
    return "封禁"
  }
  if (status === 1) {
    return "已删除"
  }
  return "正常"
}

function userStatusTone(status: number) {
  if (status === 2) {
    return "border-rose-600/20 bg-rose-600/10 text-rose-700"
  }
  if (status === 1) {
    return "border-slate-500/20 bg-slate-500/10 text-slate-700"
  }
  return "border-emerald-600/20 bg-emerald-600/10 text-emerald-700"
}

export default function UsersPage() {
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

  const form = useForm<UserCreateValues>({
    defaultValues,
  })
  const statusValue = useWatch({
    control: form.control,
    name: "status",
  })

  const usersQuery = useQuery({
    queryKey: ["admin-users", deferredSearch, statusFilter],
    queryFn: () => getUsers(request, { q: deferredSearch, status: statusFilter }),
  })

  const detailQuery = useQuery({
    queryKey: ["admin-user-detail", selectedId],
    queryFn: () => getUserDetail(request, selectedId!),
    enabled: sheetMode === "edit" && Boolean(selectedId),
  })

  useEffect(() => {
    if (sheetMode === "create") {
      form.reset(defaultValues)
      return
    }

    if (sheetMode === "edit" && detailQuery.data) {
      form.reset({
        public_id: detailQuery.data.publicId,
        nickname: detailQuery.data.nickname,
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
        return createUser(request, payload.values)
      }

      return updateUser(request, selectedId!, payload.values)
    },
    onSuccess: async (data, payload) => {
      toast.success(payload.mode === "create" ? "用户已创建" : "用户已更新")
      setConfirmOpen(false)
      setPendingPayload(null)
      setSheetMode("edit")
      setSelectedId(data.id)
      form.reset({
        public_id: data.publicId,
        nickname: data.nickname,
        avatar_url: data.avatarUrl ?? "",
        status: data.status,
      })
      await Promise.all([
        queryClient.invalidateQueries({ queryKey: ["admin-users"] }),
        queryClient.invalidateQueries({ queryKey: ["admin-user-detail", data.id] }),
      ])
    },
    onError: (error) => {
      toast.error(error instanceof Error ? error.message : "提交失败")
    },
  })

  const deleteMutation = useMutation({
    mutationFn: () => deleteUser(request, selectedId!),
    onSuccess: async () => {
      toast.success("用户已删除")
      setDeleteOpen(false)
      resetSheet()
      await queryClient.invalidateQueries({ queryKey: ["admin-users"] })
    },
    onError: (error) => {
      toast.error(error instanceof Error ? error.message : "删除失败")
    },
  })

  const handleOpenConfirm = form.handleSubmit((values) => {
    form.clearErrors()

    if (sheetMode === "create") {
      const parsed = userCreateSchema.safeParse(values)
      if (!parsed.success) {
        applyZodIssues(parsed.error, form.setError)
        return
      }
      setPendingPayload({ mode: "create", values: parsed.data })
      setConfirmOpen(true)
      return
    }

    const parsed = userEditSchema.safeParse({
      nickname: values.nickname,
      avatar_url: values.avatar_url,
      status: values.status,
    })
    if (!parsed.success) {
      for (const issue of parsed.error.issues) {
        const field = issue.path[0]
        if (typeof field === "string") {
          form.setError(field as keyof UserCreateValues, {
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

  const columns: ColumnDef<AdminUser>[] = [
    {
      header: "用户",
      cell: ({ row }) => (
        <div className="space-y-1">
          <p className="font-medium text-foreground">{row.original.nickname}</p>
          <p className="text-xs uppercase tracking-[0.18em] text-muted-foreground">
            {row.original.publicId}
          </p>
        </div>
      ),
    },
    {
      header: "状态",
      cell: ({ row }) => (
        <Badge
          variant="outline"
          className={userStatusTone(row.original.status)}
        >
          {userStatusLabel(row.original.status)}
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
            <CardTitle className="font-display text-3xl text-foreground">用户池</CardTitle>
            <p className="mt-2 text-sm leading-6 text-muted-foreground">
              支持按昵称或 `publicId` 搜索，并直接新增、维护或删除用户主字段。
            </p>
          </div>
          <div className="flex flex-wrap items-center gap-2">
            <Badge variant="outline" className="rounded-full px-3 py-1">
              {usersQuery.data?.items.length ?? 0} 条当前结果
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
              新建用户
            </Button>
          </div>
        </CardHeader>
        <CardContent className="grid gap-3 md:grid-cols-[1fr_220px]">
          <div className="relative">
            <Search className="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
            <Input
              value={search}
              onChange={(event) => setSearch(event.target.value)}
              placeholder="搜索昵称或 publicId"
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
              <SelectItem value="0">正常</SelectItem>
              <SelectItem value="1">已删除</SelectItem>
              <SelectItem value="2">封禁</SelectItem>
            </SelectContent>
          </Select>
        </CardContent>
      </Card>

      <DataTable
        columns={columns}
        data={usersQuery.data?.items ?? []}
        emptyTitle="还没有命中任何用户"
        emptyHint="可以尝试放宽搜索词或切换状态筛选。"
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
              {isCreate ? "新建用户" : "用户详情"}
            </SheetTitle>
            <SheetDescription>
              {isCreate
                ? "创建一个新的业务用户。publicId 可留空，后端会自动生成。"
                : "查看当前快照，并确认要写回的字段变更。"}
            </SheetDescription>
          </SheetHeader>

          <div className="space-y-6 px-6 py-6">
            {isEdit && detailQuery.data ? (
              <div className="grid gap-4 md:grid-cols-3">
                <Card className="border-border/70 bg-background/70">
                  <CardHeader className="pb-3">
                    <CardTitle className="text-sm text-muted-foreground">publicId</CardTitle>
                  </CardHeader>
                  <CardContent className="font-medium text-foreground">
                    {detailQuery.data.publicId}
                  </CardContent>
                </Card>
                <Card className="border-border/70 bg-background/70">
                  <CardHeader className="pb-3">
                    <CardTitle className="text-sm text-muted-foreground">Apple Sub</CardTitle>
                  </CardHeader>
                  <CardContent className="truncate text-sm text-foreground">
                    {detailQuery.data.appleSub ?? "未绑定"}
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
              <p className="text-sm text-muted-foreground">正在加载用户详情…</p>
            ) : null}

            {sheetMode ? (
              <>
                <form className="space-y-5">
                  {isCreate ? (
                    <FieldGroup
                      label="publicId"
                      hint="可留空"
                      error={form.formState.errors.public_id?.message}
                    >
                      <Input placeholder="U123456" {...form.register("public_id")} />
                    </FieldGroup>
                  ) : null}

                  <FieldGroup
                    label="昵称"
                    error={form.formState.errors.nickname?.message}
                  >
                    <Input {...form.register("nickname")} />
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
                        <SelectItem value="0">正常</SelectItem>
                        <SelectItem value="1">已删除</SelectItem>
                        <SelectItem value="2">封禁</SelectItem>
                      </SelectContent>
                    </Select>
                  </FieldGroup>
                </form>

                <div className="rounded-[24px] border border-amber-200/70 bg-amber-50/70 p-4">
                  <div className="flex items-center gap-2 text-amber-700">
                    <AlertTriangle className="size-4" />
                    <p className="text-xs uppercase tracking-[0.2em]">audit reminder</p>
                  </div>
                  <p className="mt-3 text-sm leading-6 text-amber-900/90">
                    {isCreate
                      ? "创建和删除同样会写入后台审计日志。正式环境下新增测试账号前，先确认命名和用途。"
                      : "更新会直接写入后台审计日志，确认后才会提交。对正式用户做状态变更前，先核对当前环境是否正确。"}
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
                        删除用户
                      </Button>
                    ) : null}
                  </div>
                  <Button
                    size="lg"
                    onClick={handleOpenConfirm}
                    type="button"
                    disabled={saveMutation.isPending || (isEdit && !form.formState.isDirty)}
                  >
                    {isCreate ? <UserPlus className="size-4" /> : <UserRoundCog className="size-4" />}
                    {isCreate ? "创建用户" : "保存修改"}
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
              {pendingPayload?.mode === "create" ? "确认创建用户？" : "确认写回用户变更？"}
            </AlertDialogTitle>
            <AlertDialogDescription>
              {pendingPayload?.mode === "create"
                ? "提交后会立即创建业务用户并生成审计日志。"
                : "提交后会立即写入后端并生成审计日志。请确认当前环境和目标用户无误。"}
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
            <AlertDialogTitle>确认删除当前用户？</AlertDialogTitle>
            <AlertDialogDescription>
              删除后会按业务用户删除语义写回，并生成审计日志。该操作应只用于明确的清理场景。
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
