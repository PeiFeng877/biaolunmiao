import type { AdminSession } from "@/lib/schemas/admin"

const STORAGE_KEY = "bianlunmiao-admin-session"

export function readStoredSession(): AdminSession | null {
  if (typeof window === "undefined") {
    return null
  }

  const raw = window.sessionStorage.getItem(STORAGE_KEY)
  if (!raw) {
    return null
  }

  try {
    return JSON.parse(raw) as AdminSession
  } catch {
    window.sessionStorage.removeItem(STORAGE_KEY)
    return null
  }
}

export function writeStoredSession(session: AdminSession | null) {
  if (typeof window === "undefined") {
    return
  }

  if (!session) {
    window.sessionStorage.removeItem(STORAGE_KEY)
    return
  }

  window.sessionStorage.setItem(STORAGE_KEY, JSON.stringify(session))
}
