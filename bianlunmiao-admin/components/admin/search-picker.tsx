"use client"

import type { ReactNode } from "react"
import { Check, Search } from "lucide-react"

import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { cn } from "@/lib/utils"

export type SearchPickerItem = {
  id: string
  title: string
  subtitle?: string | null
  meta?: ReactNode
}

type SearchPickerProps = {
  value: string
  searchValue: string
  onSearchChange: (value: string) => void
  onSelect: (id: string) => void
  items: SearchPickerItem[]
  placeholder: string
  emptyText: string
  className?: string
}

export function SearchPicker({
  value,
  searchValue,
  onSearchChange,
  onSelect,
  items,
  placeholder,
  emptyText,
  className,
}: SearchPickerProps) {
  return (
    <div className={cn("space-y-3", className)}>
      <div className="relative">
        <Search className="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
        <Input
          value={searchValue}
          onChange={(event) => onSearchChange(event.target.value)}
          placeholder={placeholder}
          className="h-10 rounded-2xl pl-9"
        />
      </div>

      <div className="grid max-h-56 gap-2 overflow-auto rounded-[22px] border border-border/60 bg-background/45 p-2">
        {items.length ? (
          items.map((item) => {
            const active = item.id === value
            return (
              <Button
                key={item.id}
                type="button"
                variant="ghost"
                className={cn(
                  "h-auto justify-between rounded-[18px] px-3 py-3 text-left",
                  active
                    ? "bg-primary/10 text-foreground hover:bg-primary/10"
                    : "bg-background/60 hover:bg-background"
                )}
                onClick={() => onSelect(item.id)}
              >
                <div className="min-w-0">
                  <p className="truncate text-sm font-medium">{item.title}</p>
                  {item.subtitle ? (
                    <p className="truncate text-xs text-muted-foreground">{item.subtitle}</p>
                  ) : null}
                </div>
                <div className="flex items-center gap-2">
                  {item.meta ? <div className="text-xs text-muted-foreground">{item.meta}</div> : null}
                  {active ? <Check className="size-4 text-primary" /> : null}
                </div>
              </Button>
            )
          })
        ) : (
          <div className="rounded-[18px] border border-dashed border-border/70 bg-background/60 px-4 py-5 text-sm text-muted-foreground">
            {emptyText}
          </div>
        )}
      </div>
    </div>
  )
}
