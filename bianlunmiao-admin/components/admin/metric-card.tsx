import type { ReactNode } from "react"

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"

type MetricCardProps = {
  title: string
  value: string
  note: string
  icon: ReactNode
}

export function MetricCard({ title, value, note, icon }: MetricCardProps) {
  return (
    <Card className="surface-panel border-white/70">
      <CardHeader className="flex flex-row items-start justify-between gap-3 pb-4">
        <div className="space-y-1">
          <CardTitle className="text-sm font-medium text-muted-foreground">{title}</CardTitle>
          <p className="font-display text-4xl leading-none tracking-tight text-foreground">
            {value}
          </p>
        </div>
        <div className="rounded-2xl border border-border/80 bg-background/70 p-3 text-primary">
          {icon}
        </div>
      </CardHeader>
      <CardContent>
        <p className="text-sm leading-6 text-muted-foreground">{note}</p>
      </CardContent>
    </Card>
  )
}
