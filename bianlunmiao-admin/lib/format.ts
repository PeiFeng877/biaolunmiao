import { format } from "date-fns"

export function formatDateTime(value?: string | null) {
  if (!value) {
    return "—"
  }

  return format(new Date(value), "yyyy-MM-dd HH:mm")
}

export function formatDateValue(value?: string | null) {
  if (!value) {
    return "—"
  }

  return format(new Date(value), "yyyy-MM-dd")
}
