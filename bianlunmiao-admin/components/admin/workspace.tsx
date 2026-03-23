"use client"

import type { ComponentProps, ReactNode } from "react"
import { Search } from "lucide-react"

import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { cn } from "@/lib/utils"

type WorkspaceSurfaceProps = {
  className?: string
  children: ReactNode
}

type WorkspaceHeroProps = {
  eyebrow?: string
  title: string
  description?: string
  actions?: ReactNode
  meta?: ReactNode
  className?: string
}

type WorkspaceGridProps = {
  left: ReactNode
  right: ReactNode
  className?: string
}

type WorkspaceListItemProps = {
  active?: boolean
  title: string
  subtitle?: string
  meta?: ReactNode
  badge?: ReactNode
  onClick?: () => void
  className?: string
}

type WorkspaceSearchProps = {
  value: string
  onChange: (value: string) => void
  placeholder?: string
  className?: string
  trailing?: ReactNode
}

export function WorkspaceSurface({ className, children }: WorkspaceSurfaceProps) {
  return (
    <section
      className={cn(
        "rounded-[28px] bg-card/80 p-4 ring-1 ring-black/5 backdrop-blur-md md:p-5",
        className
      )}
    >
      {children}
    </section>
  )
}

export function WorkspaceHero({
  eyebrow,
  title,
  description,
  actions,
  meta,
  className,
}: WorkspaceHeroProps) {
  return (
    <header
      className={cn(
        "flex flex-col gap-4 border-b border-border/60 pb-4 lg:flex-row lg:items-end lg:justify-between",
        className
      )}
    >
      <div className="space-y-2">
        {eyebrow ? (
          <p className="text-[11px] uppercase tracking-[0.34em] text-muted-foreground">
            {eyebrow}
          </p>
        ) : null}
        <div className="space-y-1">
          <h1 className="font-display text-3xl leading-tight text-foreground md:text-4xl">
            {title}
          </h1>
          {description ? (
            <p className="max-w-3xl text-sm leading-6 text-muted-foreground">
              {description}
            </p>
          ) : null}
        </div>
      </div>

      <div className="flex flex-wrap items-center gap-2">
        {meta ? <div className="flex flex-wrap items-center gap-2">{meta}</div> : null}
        {actions ? <div className="flex flex-wrap items-center gap-2">{actions}</div> : null}
      </div>
    </header>
  )
}

export function WorkspaceGrid({ left, right, className }: WorkspaceGridProps) {
  return (
    <div className={cn("grid gap-4 xl:grid-cols-[360px_minmax(0,1fr)]", className)}>
      {left}
      {right}
    </div>
  )
}

export function WorkspacePane({ className, children }: WorkspaceSurfaceProps) {
  return (
    <WorkspaceSurface className={cn("flex min-h-0 flex-col", className)}>
      {children}
    </WorkspaceSurface>
  )
}

export function WorkspaceSection({
  title,
  hint,
  action,
  children,
  className,
}: {
  title: string
  hint?: string
  action?: ReactNode
  children: ReactNode
  className?: string
}) {
  return (
    <section className={cn("space-y-3", className)}>
      <div className="flex items-start justify-between gap-3">
        <div className="space-y-1">
          <h2 className="text-sm font-medium text-foreground">{title}</h2>
          {hint ? <p className="text-xs leading-5 text-muted-foreground">{hint}</p> : null}
        </div>
        {action ? <div className="shrink-0">{action}</div> : null}
      </div>
      {children}
    </section>
  )
}

export function WorkspaceStat({
  label,
  value,
  hint,
}: {
  label: string
  value: ReactNode
  hint?: string
}) {
  return (
    <div className="rounded-[24px] border border-border/60 bg-background/60 p-4">
      <p className="text-[11px] uppercase tracking-[0.2em] text-muted-foreground">{label}</p>
      <p className="mt-2 font-display text-3xl text-foreground">{value}</p>
      {hint ? <p className="mt-2 text-sm leading-6 text-muted-foreground">{hint}</p> : null}
    </div>
  )
}

export function WorkspaceSearch({
  value,
  onChange,
  placeholder = "搜索",
  className,
  trailing,
}: WorkspaceSearchProps) {
  return (
    <div className={cn("grid gap-2 md:grid-cols-[minmax(0,1fr)_auto]", className)}>
      <div className="relative">
        <Search className="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
        <Input
          value={value}
          onChange={(event) => onChange(event.target.value)}
          placeholder={placeholder}
          className="h-10 rounded-2xl pl-9"
        />
      </div>
      {trailing ? <div className="flex items-center gap-2">{trailing}</div> : null}
    </div>
  )
}

export function WorkspaceList({
  children,
  emptyTitle,
  emptyHint,
}: {
  children: ReactNode
  emptyTitle: string
  emptyHint: string
}) {
  return (
    <div className="space-y-2">
      {children}
      {!children ? (
        <div className="rounded-[24px] border border-dashed border-border/70 bg-background/55 p-6 text-center">
          <p className="font-medium text-foreground">{emptyTitle}</p>
          <p className="mt-2 text-sm leading-6 text-muted-foreground">{emptyHint}</p>
        </div>
      ) : null}
    </div>
  )
}

export function WorkspaceListItem({
  active,
  title,
  subtitle,
  meta,
  badge,
  onClick,
  className,
}: WorkspaceListItemProps) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={cn(
        "flex w-full items-start justify-between gap-3 rounded-[22px] border px-4 py-3 text-left transition-all",
        active
          ? "border-primary/25 bg-primary/8 shadow-[0_14px_30px_-24px_rgba(15,23,42,0.35)]"
          : "border-border/70 bg-background/50 hover:border-border hover:bg-background/80",
        className
      )}
    >
      <div className="min-w-0 space-y-1">
        <p className="truncate text-sm font-medium text-foreground">{title}</p>
        {subtitle ? (
          <p className="truncate text-xs leading-5 text-muted-foreground">{subtitle}</p>
        ) : null}
      </div>
      <div className="flex shrink-0 flex-col items-end gap-1 text-right">
        {badge ? badge : null}
        {meta ? <div className="text-xs text-muted-foreground">{meta}</div> : null}
      </div>
    </button>
  )
}

export function WorkspaceDetailEmpty({
  title,
  hint,
  action,
}: {
  title: string
  hint: string
  action?: ReactNode
}) {
  return (
    <div className="flex min-h-[320px] flex-1 items-center justify-center">
      <div className="max-w-md space-y-3 text-center">
        <p className="font-display text-2xl text-foreground">{title}</p>
        <p className="text-sm leading-6 text-muted-foreground">{hint}</p>
        {action ? <div className="pt-2">{action}</div> : null}
      </div>
    </div>
  )
}

export function WorkspaceTabs({
  value,
  onChange,
  tabs,
  className,
}: {
  value: string
  onChange: (value: string) => void
  tabs: Array<{ value: string; label: string; meta?: ReactNode }>
  className?: string
}) {
  return (
    <div className={cn("inline-flex flex-wrap items-center gap-1 rounded-2xl bg-muted p-1", className)}>
      {tabs.map((tab) => {
        const active = tab.value === value
        return (
          <button
            key={tab.value}
            type="button"
            onClick={() => onChange(tab.value)}
            className={cn(
              "inline-flex h-8 items-center gap-2 rounded-[14px] px-3 text-sm font-medium transition-all",
              active
                ? "bg-background text-foreground shadow-sm"
                : "text-muted-foreground hover:text-foreground"
            )}
          >
            <span>{tab.label}</span>
            {tab.meta ? <span className="text-xs text-muted-foreground">{tab.meta}</span> : null}
          </button>
        )
      })}
    </div>
  )
}

export function WorkspaceTag({ children, tone = "default" }: { children: ReactNode; tone?: "default" | "soft" }) {
  return (
    <Badge
      variant="outline"
      className={cn(
        "rounded-full px-3 py-1 text-[11px] font-medium",
        tone === "soft" ? "border-border/60 bg-background/70 text-muted-foreground" : ""
      )}
    >
      {children}
    </Badge>
  )
}

export function WorkspaceActionButton(props: ComponentProps<typeof Button>) {
  return <Button {...props} />
}
