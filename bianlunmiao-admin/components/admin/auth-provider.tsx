"use client"

import { createContext, useContext, useEffect, useRef, useState, type ReactNode } from "react"

import { loginAdmin, logoutAdmin, refreshAdmin, type RequestFn } from "@/lib/api/admin"
import { ApiError, getApiBaseUrl, parseApiError } from "@/lib/api/client"
import { readStoredSession, writeStoredSession } from "@/lib/auth/session"
import type { AdminSession, LoginValues } from "@/lib/schemas/admin"

type AuthContextValue = {
  ready: boolean
  session: AdminSession | null
  login: (values: LoginValues) => Promise<AdminSession>
  logout: () => Promise<void>
  request: RequestFn
}

const AuthContext = createContext<AuthContextValue | null>(null)

export function AuthProvider({ children }: { children: ReactNode }) {
  const [session, setSession] = useState<AdminSession | null>(null)
  const [ready, setReady] = useState(false)
  const sessionRef = useRef<AdminSession | null>(null)
  const refreshPromiseRef = useRef<Promise<AdminSession | null> | null>(null)

  useEffect(() => {
    const storedSession = readStoredSession()
    sessionRef.current = storedSession
    setSession(storedSession)
    setReady(true)
  }, [])

  useEffect(() => {
    sessionRef.current = session
    if (ready) {
      writeStoredSession(session)
    }
  }, [ready, session])

  async function rawRequest<T>(
    path: string,
    init: RequestInit & { auth?: boolean; retryOnAuth?: boolean } = {}
  ) {
    const auth = init.auth ?? true
    const retryOnAuth = init.retryOnAuth ?? true
    const headers = new Headers(init.headers)

    if (init.body && !headers.has("Content-Type")) {
      headers.set("Content-Type", "application/json")
    }

    if (auth) {
      const accessToken = sessionRef.current?.accessToken
      if (!accessToken) {
        throw new ApiError("ADMIN_UNAUTHORIZED", "后台登录已失效，请重新登录。", 401)
      }
      headers.set("Authorization", `Bearer ${accessToken}`)
    }

    const response = await fetch(`${getApiBaseUrl()}${path}`, {
      ...init,
      headers,
    })

    if (response.status === 401 && auth && retryOnAuth) {
      const refreshed = await ensureRefreshed()
      if (refreshed) {
        return rawRequest<T>(path, { ...init, retryOnAuth: false })
      }
      throw new ApiError("ADMIN_UNAUTHORIZED", "后台登录已失效，请重新登录。", 401)
    }

    if (!response.ok) {
      throw await parseApiError(response)
    }

    return (await response.json()) as T
  }

  async function ensureRefreshed() {
    if (!sessionRef.current?.refreshToken) {
      setSession(null)
      return null
    }

    if (!refreshPromiseRef.current) {
      refreshPromiseRef.current = refreshAdmin(rawRequest, sessionRef.current.refreshToken)
        .then((nextSession) => {
          setSession(nextSession)
          return nextSession
        })
        .catch(() => {
          setSession(null)
          return null
        })
        .finally(() => {
          refreshPromiseRef.current = null
        })
    }

    return refreshPromiseRef.current
  }

  async function login(values: LoginValues) {
    const nextSession = await loginAdmin(rawRequest, values)
    setSession(nextSession)
    return nextSession
  }

  async function logout() {
    const refreshToken = sessionRef.current?.refreshToken
    try {
      if (refreshToken) {
        await logoutAdmin(rawRequest, refreshToken)
      }
    } finally {
      setSession(null)
    }
  }

  return (
    <AuthContext.Provider
      value={{
        ready,
        session,
        login,
        logout,
        request: rawRequest,
      }}
    >
      {children}
    </AuthContext.Provider>
  )
}

export function useAuth() {
  const context = useContext(AuthContext)

  if (!context) {
    throw new Error("useAuth must be used within AuthProvider")
  }

  return context
}
