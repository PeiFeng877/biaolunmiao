"use client"

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query"
import { Plus, Shield, Trash2, UserPlus, UsersRound } from "lucide-react"
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
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Textarea } from "@/components/ui/textarea"
import {
  addTeamMember,
  approveTeamJoinRequest,
  createTeam,
  deleteTeam,
  getTeamDetail,
  getTeams,
  getUsers,
  rejectTeamJoinRequest,
  removeTeamMember,
  toggleTeamMemberAdmin,
  transferTeamOwner,
  updateTeam,
} from "@/lib/api/admin"
import { formatDateTime } from "@/lib/format"
import {
  teamCreateSchema,
  teamEditSchema,
  type TeamCreateValues,
} from "@/lib/schemas/admin"

const createDefaults: TeamCreateValues = {
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

function roleLabel(role: number) {
  if (role === 2) return "队长"
  if (role === 1) return "管理员"
  return "成员"
}

function roleTone(role: number) {
  if (role === 2) return "border-primary/20 bg-primary/10 text-primary"
  if (role === 1) return "border-sky-600/20 bg-sky-600/10 text-sky-700"
  return "border-border/70 bg-background/70 text-muted-foreground"
}

function requestTone(status: string) {
  if (status === "approved") return "border-emerald-600/20 bg-emerald-600/10 text-emerald-700"
  if (status === "rejected") return "border-slate-500/20 bg-slate-500/10 text-slate-700"
  return "border-amber-600/20 bg-amber-600/10 text-amber-700"
}

export default function TeamsPage() {
  const { request } = useAuth()
  const queryClient = useQueryClient()
  const [search, setSearch] = useState("")
  const deferredSearch = useDeferredValue(search)
  const [statusFilter, setStatusFilter] = useState("all")
  const [selectedId, setSelectedId] = useState<string | null>(null)
  const [creating, setCreating] = useState(false)
  const [tab, setTab] = useState("base")
  const [ownerSearch, setOwnerSearch] = useState("")
  const [memberSearch, setMemberSearch] = useState("")
  const [deleteOpen, setDeleteOpen] = useState(false)

  const deferredOwnerSearch = useDeferredValue(ownerSearch)
  const deferredMemberSearch = useDeferredValue(memberSearch)

  const form = useForm<TeamCreateValues>({ defaultValues: createDefaults })
  const statusValue = useWatch({ control: form.control, name: "status" })
  const ownerIdValue = useWatch({ control: form.control, name: "owner_id" })

  const teamsQuery = useQuery({
    queryKey: ["admin-teams", deferredSearch, statusFilter],
    queryFn: () => getTeams(request, { q: deferredSearch, status: statusFilter }),
  })

  const list = teamsQuery.data?.items ?? []
  const firstTeamId = list[0]?.id ?? null
  const effectiveSelectedId = creating ? null : selectedId ?? firstTeamId

  const detailQuery = useQuery({
    queryKey: ["admin-team-detail", effectiveSelectedId],
    queryFn: () => getTeamDetail(request, effectiveSelectedId!),
    enabled: Boolean(effectiveSelectedId) && !creating,
  })

  const ownerCandidatesQuery = useQuery({
    queryKey: ["admin-users", "team-owner", deferredOwnerSearch],
    queryFn: () => getUsers(request, { q: deferredOwnerSearch, status: "0" }),
  })

  const memberCandidatesQuery = useQuery({
    queryKey: ["admin-users", "team-member", deferredMemberSearch],
    queryFn: () => getUsers(request, { q: deferredMemberSearch, status: "0" }),
    enabled: !creating && Boolean(effectiveSelectedId),
  })

  const selectedTeam = creating ? null : list.find((item) => item.id === effectiveSelectedId) ?? null
  const activeTeam = detailQuery.data ?? selectedTeam
  const activeTab = creating ? "base" : tab

  useEffect(() => {
    if (creating) {
      form.reset(createDefaults)
      return
    }

    if (detailQuery.data) {
      form.reset({
        owner_id: detailQuery.data.ownerId,
        name: detailQuery.data.name,
        intro: detailQuery.data.intro ?? "",
        avatar_url: detailQuery.data.avatarUrl ?? "",
        status: detailQuery.data.status,
      })
    }
  }, [creating, detailQuery.data, form])

  const saveMutation = useMutation({
    mutationFn: async (values: TeamCreateValues) => {
      if (creating) {
        return createTeam(request, teamCreateSchema.parse(values))
      }

      return updateTeam(
        request,
        effectiveSelectedId!,
        teamEditSchema.parse({
          name: values.name,
          intro: values.intro,
          avatar_url: values.avatar_url,
          status: values.status,
        })
      )
    },
    onSuccess: async (data) => {
      toast.success(creating ? "队伍已创建" : "队伍已更新")
      setCreating(false)
      setSelectedId(data.id)
      await Promise.all([
        queryClient.invalidateQueries({ queryKey: ["admin-teams"] }),
        queryClient.invalidateQueries({ queryKey: ["admin-team-detail", data.id] }),
      ])
    },
    onError: (error) => {
      toast.error(error instanceof Error ? error.message : "提交失败")
    },
  })

  const addMemberMutation = useMutation({
    mutationFn: (userId: string) => addTeamMember(request, effectiveSelectedId!, { user_id: userId, role: 0 }),
    onSuccess: async (data) => {
      toast.success("成员已加入队伍")
      setMemberSearch("")
      await Promise.all([
        queryClient.invalidateQueries({ queryKey: ["admin-team-detail", data.id] }),
        queryClient.invalidateQueries({ queryKey: ["admin-teams"] }),
      ])
    },
    onError: (error) => {
      toast.error(error instanceof Error ? error.message : "添加成员失败")
    },
  })

  const setAdminMutation = useMutation({
    mutationFn: ({ memberId, isAdmin }: { memberId: string; isAdmin: boolean }) =>
      toggleTeamMemberAdmin(request, effectiveSelectedId!, memberId, isAdmin),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: ["admin-team-detail", effectiveSelectedId] })
    },
  })

  const transferOwnerMutation = useMutation({
    mutationFn: (memberId: string) => transferTeamOwner(request, effectiveSelectedId!, memberId),
    onSuccess: async () => {
      toast.success("队长已转移")
      await Promise.all([
        queryClient.invalidateQueries({ queryKey: ["admin-team-detail", effectiveSelectedId] }),
        queryClient.invalidateQueries({ queryKey: ["admin-teams"] }),
      ])
    },
  })

  const removeMemberMutation = useMutation({
    mutationFn: (memberId: string) => removeTeamMember(request, effectiveSelectedId!, memberId),
    onSuccess: async () => {
      toast.success("成员已移除")
      await Promise.all([
        queryClient.invalidateQueries({ queryKey: ["admin-team-detail", effectiveSelectedId] }),
        queryClient.invalidateQueries({ queryKey: ["admin-teams"] }),
      ])
    },
  })

  const approveMutation = useMutation({
    mutationFn: (id: string) => approveTeamJoinRequest(request, id),
    onSuccess: async () => {
      toast.success("申请已通过")
      await queryClient.invalidateQueries({ queryKey: ["admin-team-detail", effectiveSelectedId] })
    },
  })

  const rejectMutation = useMutation({
    mutationFn: (id: string) => rejectTeamJoinRequest(request, id),
    onSuccess: async () => {
      toast.success("申请已拒绝")
      await queryClient.invalidateQueries({ queryKey: ["admin-team-detail", effectiveSelectedId] })
    },
  })

  const deleteMutation = useMutation({
    mutationFn: () => deleteTeam(request, effectiveSelectedId!),
    onSuccess: async () => {
      toast.success("队伍已删除")
      setDeleteOpen(false)
      setSelectedId(null)
      setCreating(false)
      await queryClient.invalidateQueries({ queryKey: ["admin-teams"] })
    },
    onError: (error) => {
      toast.error(error instanceof Error ? error.message : "删除失败")
    },
  })

  const ownerItems = useMemo(
    () =>
      (ownerCandidatesQuery.data?.items ?? []).map((item) => ({
        id: item.id,
        title: item.nickname,
        subtitle: item.publicId,
      })),
    [ownerCandidatesQuery.data?.items]
  )

  const memberItems = useMemo(() => {
    const members = new Set((activeTeam?.members ?? []).map((member) => member.userId))
    return (memberCandidatesQuery.data?.items ?? [])
      .filter((item) => !members.has(item.id))
      .map((item) => ({
        id: item.id,
        title: item.nickname,
        subtitle: item.publicId,
      }))
  }, [activeTeam?.members, memberCandidatesQuery.data?.items])

  const submit = form.handleSubmit((values) => {
    form.clearErrors()
    const parsed = creating
      ? teamCreateSchema.safeParse(values)
      : teamEditSchema.safeParse({
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
    saveMutation.mutate(values)
  })

  return (
    <div className="space-y-4">
      <WorkspaceHero
        eyebrow="resource workbench"
        title="队伍"
        description="创建、搜队、管成员、批申请，都收进同一块工作区。"
        meta={<WorkspaceTag tone="soft">{list.length} 条结果</WorkspaceTag>}
        actions={
          <Button
            size="lg"
            onClick={() => {
              setCreating(true)
              setSelectedId(null)
              setTab("base")
              setOwnerSearch("")
              setMemberSearch("")
              form.reset(createDefaults)
            }}
          >
            <Plus className="size-4" />
            新建队伍
          </Button>
        }
      />

      <WorkspaceGrid
        left={
          <WorkspacePane className="xl:sticky xl:top-4 xl:self-start">
            <WorkspaceSection title="列表" hint="队伍搜索和状态筛选。">
              <WorkspaceSearch
                value={search}
                onChange={setSearch}
                placeholder="搜索队伍名或 PublicId"
                trailing={
                  <Select value={statusFilter} onValueChange={(value) => setStatusFilter(value ?? "all")}>
                    <SelectTrigger className="h-10 w-[136px] rounded-2xl">
                      <SelectValue placeholder="状态" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="all">全部状态</SelectItem>
                      <SelectItem value="0">可见</SelectItem>
                      <SelectItem value="1">隐藏</SelectItem>
                    </SelectContent>
                  </Select>
                }
              />
            </WorkspaceSection>

            <div className="mt-4 space-y-2">
              {list.length ? (
                list.map((team) => (
                  <WorkspaceListItem
                    key={team.id}
                    active={!creating && effectiveSelectedId === team.id}
                    title={team.name}
                    subtitle={team.publicId}
                    meta={`${team.memberCount} 人`}
                    badge={<Badge variant="outline" className={teamStatusTone(team.status)}>{teamStatusLabel(team.status)}</Badge>}
                    onClick={() => {
                      setCreating(false)
                      setSelectedId(team.id)
                    }}
                  />
                ))
              ) : (
                <div className="rounded-[24px] border border-dashed border-border/70 bg-background/50 p-6 text-center">
                  <p className="text-sm font-medium text-foreground">没有匹配的队伍</p>
                  <p className="mt-2 text-xs leading-5 text-muted-foreground">调整关键词后再试。</p>
                </div>
              )}
            </div>
          </WorkspacePane>
        }
        right={
          <WorkspacePane>
            {activeTeam || creating ? (
              <div className="flex min-h-0 flex-1 flex-col gap-4">
                <div className="flex flex-col gap-2 border-b border-border/60 pb-4">
                  <div className="flex flex-wrap items-center justify-between gap-3">
                    <div>
                      <h2 className="text-sm font-medium text-foreground">
                        {creating ? "新建队伍" : activeTeam?.name ?? "队伍详情"}
                      </h2>
                      <p className="mt-1 text-xs leading-5 text-muted-foreground">
                        基础资料、成员和申请都在右侧处理。
                      </p>
                    </div>
                    {activeTeam ? (
                      <div className="flex flex-wrap items-center gap-2">
                        <WorkspaceTag>{activeTeam.publicId}</WorkspaceTag>
                        <Badge variant="outline" className={teamStatusTone(activeTeam.status)}>
                          {teamStatusLabel(activeTeam.status)}
                        </Badge>
                      </div>
                    ) : null}
                  </div>
                </div>

                {!creating && activeTeam ? (
                  <WorkspaceTabs
                    value={activeTab}
                    onChange={setTab}
                    tabs={[
                      { value: "base", label: "基础信息" },
                      { value: "members", label: "成员", meta: `${activeTeam.members?.length ?? 0}` },
                      { value: "requests", label: "申请", meta: `${activeTeam.joinRequests?.filter((item) => item.status === "pending").length ?? 0}` },
                      { value: "danger", label: "危险操作" },
                    ]}
                  />
                ) : null}

                {(creating || activeTab === "base") && (
                  <form className="flex flex-1 flex-col gap-4" onSubmit={submit}>
                    <div className="grid gap-4 lg:grid-cols-2">
                      <FieldGroup label="队伍名称">
                        <Input {...form.register("name")} placeholder="Alpha 队" className="h-10 rounded-2xl" />
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
                            <SelectItem value="0">可见</SelectItem>
                            <SelectItem value="1">隐藏</SelectItem>
                          </SelectContent>
                        </Select>
                      </FieldGroup>
                    </div>

                    <FieldGroup label="简介" hint="可留空">
                      <Textarea {...form.register("intro")} placeholder="队伍简介" className="rounded-[22px]" />
                    </FieldGroup>

                    <FieldGroup label="头像 URL" hint="可留空">
                      <Input {...form.register("avatar_url")} placeholder="https://..." className="h-10 rounded-2xl" />
                    </FieldGroup>

                    {creating ? (
                      <FieldGroup label="队长用户" hint="按昵称或 PublicId 搜索">
                        <SearchPicker
                          value={ownerIdValue}
                          searchValue={ownerSearch}
                          onSearchChange={setOwnerSearch}
                          onSelect={(id) => form.setValue("owner_id", id, { shouldDirty: true })}
                          items={ownerItems}
                          placeholder="搜索队长候选"
                          emptyText="没有找到可用用户。"
                        />
                      </FieldGroup>
                    ) : activeTeam ? (
                      <WorkspaceSection title="系统信息" hint="队长转移在成员页执行。">
                        <div className="grid gap-3 md:grid-cols-2">
                          <div className="rounded-[20px] border border-border/60 bg-background/60 p-4">
                            <p className="text-xs uppercase tracking-[0.2em] text-muted-foreground">队长</p>
                            <p className="mt-2 text-sm text-foreground">{activeTeam.ownerNickname ?? "未知用户"}</p>
                            <p className="mt-1 break-all text-xs text-muted-foreground">{activeTeam.ownerId}</p>
                          </div>
                          <div className="rounded-[20px] border border-border/60 bg-background/60 p-4">
                            <p className="text-xs uppercase tracking-[0.2em] text-muted-foreground">更新时间</p>
                            <p className="mt-2 text-sm text-foreground">{formatDateTime(activeTeam.updatedAt)}</p>
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
                        {creating ? "创建队伍" : "保存变更"}
                      </Button>
                    </div>
                  </form>
                )}

                {!creating && activeTeam && activeTab === "members" && (
                  <div className="space-y-4">
                    <WorkspaceSection title="添加成员" hint="搜索后直接加入，不再手填 UUID。">
                      <SearchPicker
                        value=""
                        searchValue={memberSearch}
                        onSearchChange={setMemberSearch}
                        onSelect={(id) => addMemberMutation.mutate(id)}
                        items={memberItems}
                        placeholder="搜索用户加入队伍"
                        emptyText="没有可添加的候选。"
                      />
                    </WorkspaceSection>

                    <WorkspaceSection title="当前成员" hint="管理员切换、转移队长和移除都在这里完成。">
                      <div className="space-y-2">
                        {(activeTeam.members ?? []).map((member) => (
                          <div key={member.id} className="rounded-[22px] border border-border/60 bg-background/55 p-4">
                            <div className="flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between">
                              <div>
                                <p className="text-sm font-medium text-foreground">{member.nickname}</p>
                                <p className="mt-1 text-xs text-muted-foreground">{member.publicId}</p>
                              </div>
                              <div className="flex flex-wrap items-center gap-2">
                                <Badge variant="outline" className={roleTone(member.role)}>
                                  {roleLabel(member.role)}
                                </Badge>
                                {member.role !== 2 ? (
                                  <Button
                                    type="button"
                                    size="sm"
                                    variant="outline"
                                    onClick={() => setAdminMutation.mutate({ memberId: member.id, isAdmin: member.role !== 1 })}
                                  >
                                    <Shield className="size-3.5" />
                                    {member.role === 1 ? "取消管理员" : "设为管理员"}
                                  </Button>
                                ) : null}
                                {member.role !== 2 ? (
                                  <Button
                                    type="button"
                                    size="sm"
                                    variant="outline"
                                    onClick={() => transferOwnerMutation.mutate(member.id)}
                                  >
                                    转为队长
                                  </Button>
                                ) : null}
                                {member.role !== 2 ? (
                                  <Button
                                    type="button"
                                    size="sm"
                                    variant="destructive"
                                    onClick={() => removeMemberMutation.mutate(member.id)}
                                  >
                                    移除
                                  </Button>
                                ) : null}
                              </div>
                            </div>
                          </div>
                        ))}
                      </div>
                    </WorkspaceSection>
                  </div>
                )}

                {!creating && activeTeam && activeTab === "requests" && (
                  <WorkspaceSection title="入队申请" hint="待处理申请直接在当前上下文完成。">
                    <div className="space-y-2">
                      {(activeTeam.joinRequests ?? []).length ? (
                        activeTeam.joinRequests?.map((item) => (
                          <div key={item.id} className="rounded-[22px] border border-border/60 bg-background/55 p-4">
                            <div className="flex flex-col gap-3 lg:flex-row lg:items-start lg:justify-between">
                              <div className="space-y-1">
                                <p className="text-sm font-medium text-foreground">{item.applicantNickname}</p>
                                <p className="text-xs text-muted-foreground">{item.applicantPublicId}</p>
                                <p className="pt-2 text-sm leading-6 text-muted-foreground">{item.personalNote}</p>
                              </div>
                              <div className="flex flex-wrap items-center gap-2">
                                <Badge variant="outline" className={requestTone(item.status)}>
                                  {item.status}
                                </Badge>
                                {item.status === "pending" ? (
                                  <>
                                    <Button size="sm" variant="outline" onClick={() => approveMutation.mutate(item.id)}>
                                      通过
                                    </Button>
                                    <Button size="sm" variant="destructive" onClick={() => rejectMutation.mutate(item.id)}>
                                      拒绝
                                    </Button>
                                  </>
                                ) : null}
                              </div>
                            </div>
                          </div>
                        ))
                      ) : (
                        <WorkspaceDetailEmpty title="没有申请记录" hint="新的入队申请会出现在这里。" />
                      )}
                    </div>
                  </WorkspaceSection>
                )}

                {!creating && activeTeam && activeTab === "danger" && (
                  <WorkspaceSection title="删除队伍" hint="删除后会清理队伍本体，并同步撤下相关对阵关系。">
                    <div className="rounded-[24px] border border-destructive/20 bg-destructive/5 p-5">
                      <p className="text-sm leading-6 text-foreground">
                        当前操作会删除 <span className="font-medium">{activeTeam.name}</span>，并把关联场次中的该队标记清空。
                      </p>
                      <Button className="mt-4" variant="destructive" onClick={() => setDeleteOpen(true)}>
                        <Trash2 className="size-4" />
                        删除队伍
                      </Button>
                    </div>
                  </WorkspaceSection>
                )}
              </div>
            ) : (
              <WorkspaceDetailEmpty
                title="选择一支队伍"
                hint="在左侧选中对象，或者新建一支队伍。"
                action={
                  <Button
                    onClick={() => {
                      setCreating(true)
                      setSelectedId(null)
                      setTab("base")
                      form.reset(createDefaults)
                    }}
                  >
                    <UserPlus className="size-4" />
                    新建队伍
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
              <UsersRound className="size-5 text-destructive" />
            </AlertDialogMedia>
            <AlertDialogTitle>删除队伍</AlertDialogTitle>
            <AlertDialogDescription>该操作会移除队伍本体，并清空相关场次中的队伍引用。</AlertDialogDescription>
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
