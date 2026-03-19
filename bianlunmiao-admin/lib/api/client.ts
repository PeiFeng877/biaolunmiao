export class ApiError extends Error {
  code: string
  status: number
  details?: unknown

  constructor(code: string, message: string, status: number, details?: unknown) {
    super(message)
    this.name = "ApiError"
    this.code = code
    this.status = status
    this.details = details
  }
}

export function getApiBaseUrl() {
  return (process.env.NEXT_PUBLIC_API_BASE_URL ?? "/api/proxy").replace(/\/$/, "")
}

export function getAppEnv() {
  return process.env.NEXT_PUBLIC_APP_ENV ?? "local"
}

export async function parseApiError(response: Response) {
  try {
    const payload = await response.json()
    return new ApiError(
      payload.code ?? "REQUEST_FAILED",
      payload.message ?? "请求失败",
      response.status,
      payload.details
    )
  } catch {
    return new ApiError("REQUEST_FAILED", "请求失败", response.status)
  }
}
