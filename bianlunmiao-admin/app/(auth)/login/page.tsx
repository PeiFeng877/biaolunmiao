"use client"

import { ShieldCheck, Sparkles, TowerControl, Waves } from "lucide-react"
import { useRouter } from "next/navigation"
import { useEffect, useState } from "react"
import { useForm } from "react-hook-form"
import { toast } from "sonner"

import { useAuth } from "@/components/admin/auth-provider"
import { FieldGroup } from "@/components/admin/field-group"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { getAppEnv } from "@/lib/api/client"
import { applyZodIssues } from "@/lib/forms"
import { loginSchema, type LoginValues } from "@/lib/schemas/admin"

const notes = [
  "管理员与 App 用户会话完全隔离",
  "所有后台写操作自动写入审计日志",
  "local / prod 通过部署级环境隔离，不在页面内切换",
]

export default function LoginPage() {
  const { ready, session, login } = useAuth()
  const router = useRouter()
  const env = getAppEnv()
  const [submitting, setSubmitting] = useState(false)

  const form = useForm<LoginValues>({
    defaultValues: {
      email: "",
      password: "",
    },
  })

  useEffect(() => {
    if (ready && session) {
      router.replace("/dashboard")
    }
  }, [ready, router, session])

  async function handleSubmit(values: LoginValues) {
    form.clearErrors()
    const parsed = loginSchema.safeParse(values)

    if (!parsed.success) {
      applyZodIssues(parsed.error, form.setError)
      return
    }

    setSubmitting(true)

    try {
      await login(parsed.data)
      toast.success("管理员登录成功")
      router.replace("/dashboard")
    } catch (error) {
      const message = error instanceof Error ? error.message : "登录失败"
      toast.error(message)
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <div className="flex min-h-screen items-center justify-center px-4 py-6 md:px-8">
      <div className="grid w-full max-w-6xl overflow-hidden rounded-[36px] border border-white/70 bg-card/80 shadow-[0_40px_100px_-40px_color-mix(in_oklch,var(--foreground)_20%,transparent)] lg:grid-cols-[1.1fr_0.9fr]">
        <section className="relative overflow-hidden p-8 md:p-12">
          <div className="absolute inset-0 bg-[linear-gradient(135deg,color-mix(in_oklch,var(--accent)_20%,transparent),transparent_55%)]" />
          <div className="absolute right-[-8%] top-[-8%] size-56 rounded-full bg-[color-mix(in_oklch,var(--chart-1)_18%,transparent)] blur-3xl" />
          <div className="absolute bottom-[-10%] left-[-4%] size-72 rounded-full bg-[color-mix(in_oklch,var(--accent)_22%,transparent)] blur-3xl" />

          <div className="relative flex h-full flex-col justify-between gap-10">
            <div className="space-y-5">
              <Badge variant="outline" className="rounded-full bg-background/80 px-4 py-1 text-xs uppercase tracking-[0.24em]">
                {env} / control room
              </Badge>
              <div className="space-y-4">
                <p className="text-sm uppercase tracking-[0.34em] text-muted-foreground">
                  辩论喵数据治理后台
                </p>
                <h1 className="font-display text-5xl leading-[0.95] text-foreground md:text-7xl">
                  Editorial
                  <br />
                  Command Deck
                </h1>
                <p className="max-w-xl text-base leading-8 text-muted-foreground md:text-lg">
                  把用户、队伍、赛事数据放进一个可审计、可回溯、可环境隔离的控制台。
                </p>
              </div>
            </div>

            <div className="grid gap-4 md:grid-cols-3">
              <Card className="surface-panel border-white/80">
                <CardHeader className="pb-3">
                  <CardTitle className="flex items-center gap-2 text-sm font-medium text-muted-foreground">
                    <ShieldCheck className="size-4 text-primary" />
                    安全隔离
                  </CardTitle>
                </CardHeader>
                <CardContent className="text-sm leading-6 text-foreground">
                  独立管理员身份，不复用 App 业务账号。
                </CardContent>
              </Card>
              <Card className="surface-panel border-white/80">
                <CardHeader className="pb-3">
                  <CardTitle className="flex items-center gap-2 text-sm font-medium text-muted-foreground">
                    <TowerControl className="size-4 text-primary" />
                    操作收口
                  </CardTitle>
                </CardHeader>
                <CardContent className="text-sm leading-6 text-foreground">
                  统一从 `/admin` 命名空间读取与更新资源。
                </CardContent>
              </Card>
              <Card className="surface-panel border-white/80">
                <CardHeader className="pb-3">
                  <CardTitle className="flex items-center gap-2 text-sm font-medium text-muted-foreground">
                    <Waves className="size-4 text-primary" />
                    环境可见
                  </CardTitle>
                </CardHeader>
                <CardContent className="text-sm leading-6 text-foreground">
                  本地与正式部署分开，不允许页面内乱切。
                </CardContent>
              </Card>
            </div>
          </div>
        </section>

        <section className="surface-panel flex items-center border-l border-white/70 p-6 md:p-10">
          <div className="mx-auto w-full max-w-md">
            <Card className="border-white/80 bg-background/78">
              <CardHeader className="space-y-4">
                <Badge variant="outline" className="w-fit rounded-full px-3 py-1 text-xs uppercase tracking-[0.22em]">
                  secure entry
                </Badge>
                <div className="space-y-2">
                  <CardTitle className="font-display text-4xl text-foreground">登录后台</CardTitle>
                  <p className="text-sm leading-6 text-muted-foreground">
                    仅限内部管理员。登录成功后可管理用户、队伍与赛事数据。
                  </p>
                </div>
              </CardHeader>
              <CardContent className="space-y-6">
                <form
                  className="space-y-5"
                  onSubmit={form.handleSubmit(handleSubmit)}
                >
                  <FieldGroup
                    label="管理员邮箱"
                    error={form.formState.errors.email?.message}
                  >
                    <Input
                      autoComplete="email"
                      placeholder="admin@bianlunmiao.top"
                      {...form.register("email")}
                    />
                  </FieldGroup>

                  <FieldGroup
                    label="登录密码"
                    error={form.formState.errors.password?.message}
                  >
                    <Input
                      type="password"
                      autoComplete="current-password"
                      placeholder="请输入后台密码"
                      {...form.register("password")}
                    />
                  </FieldGroup>

                  <Button
                    type="submit"
                    size="lg"
                    className="w-full"
                    disabled={submitting}
                  >
                    <Sparkles className="size-4" />
                    {submitting ? "正在验证" : "进入控制台"}
                  </Button>
                </form>

                <div className="rounded-[24px] border border-border/70 bg-muted/45 p-4">
                  <p className="text-xs uppercase tracking-[0.2em] text-muted-foreground">session notes</p>
                  <div className="mt-3 space-y-2">
                    {notes.map((note) => (
                      <p key={note} className="text-sm leading-6 text-foreground">
                        {note}
                      </p>
                    ))}
                  </div>
                </div>
              </CardContent>
            </Card>
          </div>
        </section>
      </div>
    </div>
  )
}
