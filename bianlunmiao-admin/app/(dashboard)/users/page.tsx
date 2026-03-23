"use client"

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query"
import { Plus, Trash2, UserRound } from "lucide-react"
import { useDeferredValue, useEffect, useState } from "react"
import { useForm, useWatch } from "react-hook-form"
import { toast } from "sonner"

import { useAuth } from "@/components/admin/auth-provider"
import {
  WorkspaceDetailEmpty,
  WorkspaceGrid,
  WorkspaceHero,
  WorkspaceListItem,
  WorkspacePane,
  WorkspaceSearch,
  WorkspaceSection,
  WorkspaceTag,
} from "@/components/admin/workspace"
import { AlertDialog, AlertDialogAction, AlertDialogCancel, AlertDialogContent, AlertDialogDescription, AlertDialogFooter, AlertDialogHeader, AlertDialogMedia, AlertDialogTitle } from "@/components/ui/alert-dialog"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { FieldGroup } from "@/components/admin/field-group"
import { Input } from "@/components/ui/input"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { formatDateTime } from "@/lib/format"
import {
  createUser,
  deleteUser,
  getTeamJoinRequests,
  getUserDetail,
  getUsers,
  updateUser,
} from "@/lib/api/admin"
import {
  userCreateSchema,
  userEditSchema,
  type UserCreateValues,
} from "@/lib/schemas/admin"

const createDefaults: UserCreateValues = {
  public_id: "",
  nickname: "",
  avatar_url: "",
  status: 0,
}

function userStatusLabel(status: number) {
  if (status === 2) return "封禁"
  if (status === 1) return "已删除"
  return "正常"
}

function userStatusTone(status: number) {
  if (status === 2) return "border-rose-600/20 bg-rose-600/10 text-rose-700"
  if (status === 1) return "border-slate-500/20 bg-slate-500/10 text-slate-700"
  return "border-emerald-600/20 bg-emerald-600/10 text-emerald-700"
}

export default function UsersPage() {
  const { request } = useAuth()
  const queryClient = useQueryClient()
  const [search, setSearch] = useState("")
  const deferredSearch = useDeferredValue(search)
  const [statusFilter, setStatusFilter] = useState("all")
  const [selectedId, setSelectedId] = useState<string | null>(null)
  const [creating, setCreating] = useState(false)
  const [deleteOpen, setDeleteOpen] = useState(false)

  const form = useForm<UserCreateValues>({
    defaultValues: createDefaults,
  })
  const statusValue = useWatch({ control: form.control, name: "status" })

  const usersQuery = useQuery({
    queryKey: ["admin-users", deferredSearch, statusFilter],
    queryFn: () => getUsers(request, { q: deferredSearch, status: statusFilter }),
  })

  const list = usersQuery.data?.items ?? []
  const effectiveSelectedId = creating ? null : selectedId ?? list[0]?.id ?? null
  const selectedUser = creating ? null : list.find((item) => item.id === effectiveSelectedId) ?? null

  const detailQuery = useQuery({
    queryKey: ["admin-user-detail", effectiveSelectedId],
    queryFn: () => getUserDetail(request, effectiveSelectedId!),
    enabled: Boolean(effectiveSelectedId) && !creating,
  })

  const joinRequestsQuery = useQuery({
    queryKey: ["admin-team-join-requests", "user", effectiveSelectedId],
    queryFn: () => getTeamJoinRequests(request, { applicant_user_id: effectiveSelectedId! }),
    enabled: Boolean(effectiveSelectedId) && !creating,
  })

  const activeUser = detailQuery.data ?? selectedUser
  const isCreate = creating

  useEffect(() => {
    if (creating) {
      form.reset(createDefaults)
      return
    }

    if (detailQuery.data) {
      form.reset({
        public_id: detailQuery.data.publicId,
        nickname: detailQuery.data.nickname,
        avatar_url: detailQuery.data.avatarUrl ?? "",
        status: detailQuery.data.status,
      })
    }
  }, [creating, detailQuery.data, form])

  const saveMutation = useMutation({
    mutationFn: async (values: UserCreateValues) => {
      if (isCreate) {
        const parsed = userCreateSchema.parse(values)
        return createUser(request, parsed)
      }

      const parsed = userEditSchema.parse({
        nickname: values.nickname,
        avatar_url: values.avatar_url,
        status: values.status,
      })
      return updateUser(request, effectiveSelectedId!, parsed)
    },
    onSuccess: async (data) => {
      toast.success(isCreate ? "用户已创建" : "用户已更新")
      setCreating(false)
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
    mutationFn: () => deleteUser(request, effectiveSelectedId!),
    onSuccess: async () => {
      toast.success("用户已删除")
      setDeleteOpen(false)
      setCreating(false)
      setSelectedId(null)
      form.reset(createDefaults)
      await queryClient.invalidateQueries({ queryKey: ["admin-users"] })
    },
    onError: (error) => {
      toast.error(error instanceof Error ? error.message : "删除失败")
    },
  })

  const submit = form.handleSubmit((values) => {
    form.clearErrors()

    const parsed = isCreate
      ? userCreateSchema.safeParse(values)
      : userEditSchema.safeParse({
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

    saveMutation.mutate(isCreate ? (parsed.data as UserCreateValues) : { ...values, ...parsed.data })
  })

  return (
    <div className="space-y-4">
      <WorkspaceHero
        eyebrow="resource workbench"
        title="用户"
        description="按昵称、PublicId 或状态定位用户，编辑在右侧常驻完成。"
        meta={<WorkspaceTag tone="soft">{list.length} 条结果</WorkspaceTag>}
        actions={
          <Button
            size="lg"
            onClick={() => {
              setCreating(true)
              setSelectedId(null)
              form.reset(createDefaults)
            }}
          >
            <Plus className="size-4" />
            新建用户
          </Button>
        }
      />

      <WorkspaceGrid
        left={
          <WorkspacePane className="xl:sticky xl:top-4 xl:self-start">
            <WorkspaceSection title="列表" hint="搜索、筛选和切换对象都在这里完成。">
              <WorkspaceSearch
                value={search}
                onChange={setSearch}
                placeholder="搜索昵称或 PublicId"
                trailing={
                  <Select value={statusFilter} onValueChange={(value) => setStatusFilter(value ?? "all")}>
                    <SelectTrigger className="h-10 w-[136px] rounded-2xl">
                      <SelectValue placeholder="状态" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="all">全部状态</SelectItem>
                      <SelectItem value="0">正常</SelectItem>
                      <SelectItem value="1">已删除</SelectItem>
                      <SelectItem value="2">封禁</SelectItem>
                    </SelectContent>
                  </Select>
                }
              />
            </WorkspaceSection>

            <div className="mt-4 space-y-2">
              {list.length ? (
                list.map((user) => (
                  <WorkspaceListItem
                    key={user.id}
                    active={!creating && effectiveSelectedId === user.id}
                    title={user.nickname}
                    subtitle={user.publicId}
                    meta={formatDateTime(user.updatedAt)}
                    badge={<Badge variant="outline" className={userStatusTone(user.status)}>{userStatusLabel(user.status)}</Badge>}
                    onClick={() => {
                      setCreating(false)
                      setSelectedId(user.id)
                    }}
                  />
                ))
              ) : (
                <div className="rounded-[24px] border border-dashed border-border/70 bg-background/50 p-6 text-center">
                  <p className="text-sm font-medium text-foreground">没有匹配的用户</p>
                  <p className="mt-2 text-xs leading-5 text-muted-foreground">调整关键词或状态筛选。</p>
                </div>
              )}
            </div>
          </WorkspacePane>
        }
        right={
          <WorkspacePane>
            {activeUser || isCreate ? (
              <form className="flex min-h-0 flex-1 flex-col gap-4" onSubmit={submit}>
                <div className="flex flex-col gap-2 border-b border-border/60 pb-4">
                  <div className="flex flex-wrap items-center justify-between gap-3">
                    <div>
                      <h2 className="text-sm font-medium text-foreground">
                        {isCreate ? "新建用户" : activeUser?.nickname ?? "用户详情"}
                      </h2>
                      <p className="mt-1 text-xs leading-5 text-muted-foreground">
                        显式保存，删除仅在右侧完成。
                      </p>
                    </div>
                    {activeUser ? (
                      <div className="flex flex-wrap items-center gap-2">
                        <WorkspaceTag>{activeUser.publicId}</WorkspaceTag>
                        <Badge variant="outline" className={userStatusTone(activeUser.status)}>
                          {userStatusLabel(activeUser.status)}
                        </Badge>
                      </div>
                    ) : null}
                  </div>
                </div>

                <div className="grid gap-4 lg:grid-cols-2">
                  {isCreate ? (
                    <FieldGroup label="PublicId" hint="创建时填写">
                      <Input
                        {...form.register("public_id")}
                        placeholder="U300001"
                        className="h-10 rounded-2xl"
                      />
                    </FieldGroup>
                  ) : null}
                  <FieldGroup label="昵称">
                    <Input
                      {...form.register("nickname")}
                      placeholder="用户昵称"
                      className="h-10 rounded-2xl"
                    />
                  </FieldGroup>
                  <FieldGroup label="头像 URL" hint="可留空">
                    <Input
                      {...form.register("avatar_url")}
                      placeholder="https://..."
                      className="h-10 rounded-2xl"
                    />
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
                        <SelectItem value="0">正常</SelectItem>
                        <SelectItem value="1">已删除</SelectItem>
                        <SelectItem value="2">封禁</SelectItem>
                      </SelectContent>
                    </Select>
                  </FieldGroup>
                </div>

                {activeUser ? (
                  <WorkspaceSection title="系统信息" hint="只读元数据。">
                    <div className="grid gap-3 md:grid-cols-2">
                      <div className="rounded-[20px] border border-border/60 bg-background/60 p-4">
                        <p className="text-xs uppercase tracking-[0.2em] text-muted-foreground">ID</p>
                        <p className="mt-2 break-all text-sm text-foreground">{activeUser.id}</p>
                      </div>
                      <div className="rounded-[20px] border border-border/60 bg-background/60 p-4">
                        <p className="text-xs uppercase tracking-[0.2em] text-muted-foreground">登录标识</p>
                        <p className="mt-2 break-all text-sm text-foreground">{activeUser.appleSub ?? "未绑定"}</p>
                      </div>
                      <div className="rounded-[20px] border border-border/60 bg-background/60 p-4">
                        <p className="text-xs uppercase tracking-[0.2em] text-muted-foreground">创建时间</p>
                        <p className="mt-2 text-sm text-foreground">{formatDateTime(activeUser.createdAt)}</p>
                      </div>
                      <div className="rounded-[20px] border border-border/60 bg-background/60 p-4">
                        <p className="text-xs uppercase tracking-[0.2em] text-muted-foreground">更新时间</p>
                        <p className="mt-2 text-sm text-foreground">{formatDateTime(activeUser.updatedAt)}</p>
                      </div>
                    </div>
                  </WorkspaceSection>
                ) : null}

                {activeUser ? (
                  <WorkspaceSection title="申请记录" hint="用户与队伍的申请关系在这里查看。">
                    {(joinRequestsQuery.data?.items ?? []).length ? (
                      <div className="space-y-2">
                        {joinRequestsQuery.data?.items.map((item) => (
                          <div key={item.id} className="rounded-[20px] border border-border/60 bg-background/60 p-4">
                            <div className="flex flex-wrap items-center justify-between gap-2">
                              <div>
                                <p className="text-sm font-medium text-foreground">{item.teamName}</p>
                                <p className="mt-1 text-xs text-muted-foreground">{item.teamPublicId}</p>
                              </div>
                              <WorkspaceTag>{item.status}</WorkspaceTag>
                            </div>
                            <p className="mt-3 text-sm leading-6 text-muted-foreground">{item.personalNote}</p>
                          </div>
                        ))}
                      </div>
                    ) : (
                      <div className="rounded-[20px] border border-dashed border-border/70 bg-background/55 p-4 text-sm text-muted-foreground">
                        当前用户没有申请记录。
                      </div>
                    )}
                  </WorkspaceSection>
                ) : null}

                <div className="mt-auto flex flex-wrap items-center justify-between gap-2 border-t border-border/60 pt-4">
                  <div className="flex flex-wrap items-center gap-2">
                    {!isCreate && activeUser ? (
                      <Button
                        type="button"
                        variant="destructive"
                        onClick={() => setDeleteOpen(true)}
                        disabled={deleteMutation.isPending}
                      >
                        <Trash2 className="size-4" />
                        删除
                      </Button>
                    ) : null}
                    {isCreate ? (
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
                    ) : null}
                  </div>
                  <Button type="submit" disabled={saveMutation.isPending}>
                    {isCreate ? "创建用户" : "保存变更"}
                  </Button>
                </div>
              </form>
            ) : (
              <WorkspaceDetailEmpty
                title="选择一个用户"
                hint="在左侧列表选择对象，或者直接新建。"
                action={
                  <Button
                    onClick={() => {
                      setCreating(true)
                      setSelectedId(null)
                      form.reset(createDefaults)
                    }}
                  >
                    <Plus className="size-4" />
                    新建用户
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
              <UserRound className="size-5 text-destructive" />
            </AlertDialogMedia>
            <AlertDialogTitle>删除用户</AlertDialogTitle>
            <AlertDialogDescription>
              删除后用户会被标记为已删除并清理关联凭证。
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>取消</AlertDialogCancel>
            <AlertDialogAction
              variant="destructive"
              onClick={() => deleteMutation.mutate()}
              disabled={deleteMutation.isPending}
            >
              确认删除
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  )
}
