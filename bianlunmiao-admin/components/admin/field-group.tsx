import type { ReactNode } from "react"

import { cn } from "@/lib/utils"

type FieldGroupProps = {
  label: string
  hint?: string
  error?: string
  className?: string
  children: ReactNode
}

export function FieldGroup({
  label,
  hint,
  error,
  className,
  children,
}: FieldGroupProps) {
  return (
    <label className={cn("flex flex-col gap-2 text-sm", className)}>
      <span className="flex items-center justify-between gap-3 text-sm font-medium text-foreground">
        <span>{label}</span>
        {hint ? (
          <span className="text-xs font-normal text-muted-foreground">{hint}</span>
        ) : null}
      </span>
      {children}
      {error ? <span className="text-xs text-destructive">{error}</span> : null}
    </label>
  )
}
