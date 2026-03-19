"use client"

import {
  flexRender,
  getCoreRowModel,
  useReactTable,
  type ColumnDef,
} from "@tanstack/react-table"

import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table"
import { cn } from "@/lib/utils"

type DataTableProps<TData> = {
  columns: ColumnDef<TData>[]
  data: TData[]
  emptyTitle: string
  emptyHint: string
  onRowClick?: (row: TData) => void
}

export function DataTable<TData>({
  columns,
  data,
  emptyTitle,
  emptyHint,
  onRowClick,
}: DataTableProps<TData>) {
  // eslint-disable-next-line react-hooks/incompatible-library
  const table = useReactTable({
    data,
    columns,
    getCoreRowModel: getCoreRowModel(),
  })

  return (
    <div className="overflow-hidden rounded-[calc(var(--radius)*1.2)] border border-border/70 bg-background/70">
      <Table>
        <TableHeader>
          {table.getHeaderGroups().map((headerGroup) => (
            <TableRow key={headerGroup.id} className="border-border/80">
              {headerGroup.headers.map((header) => (
                <TableHead key={header.id} className="bg-muted/40 text-xs uppercase tracking-[0.22em] text-muted-foreground">
                  {header.isPlaceholder
                    ? null
                    : flexRender(header.column.columnDef.header, header.getContext())}
                </TableHead>
              ))}
            </TableRow>
          ))}
        </TableHeader>
        <TableBody>
          {table.getRowModel().rows.length ? (
            table.getRowModel().rows.map((row) => (
              <TableRow
                key={row.id}
                className={cn(
                  "cursor-pointer border-border/70 transition-colors hover:bg-accent/35",
                  onRowClick ? "cursor-pointer" : "cursor-default"
                )}
                onClick={() => onRowClick?.(row.original)}
              >
                {row.getVisibleCells().map((cell) => (
                  <TableCell key={cell.id}>
                    {flexRender(cell.column.columnDef.cell, cell.getContext())}
                  </TableCell>
                ))}
              </TableRow>
            ))
          ) : (
            <TableRow>
              <TableCell colSpan={columns.length} className="py-14 text-center">
                <div className="mx-auto max-w-sm space-y-2">
                  <p className="font-display text-2xl text-foreground">{emptyTitle}</p>
                  <p className="text-sm leading-6 text-muted-foreground">{emptyHint}</p>
                </div>
              </TableCell>
            </TableRow>
          )}
        </TableBody>
      </Table>
    </div>
  )
}
