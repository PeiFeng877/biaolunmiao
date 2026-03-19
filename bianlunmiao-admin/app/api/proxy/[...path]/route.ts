import { NextRequest } from "next/server"

export const dynamic = "force-dynamic"

const REQUEST_STRIP_HEADERS = [
  "accept-encoding",
  "connection",
  "content-length",
  "host",
  "keep-alive",
  "proxy-authenticate",
  "proxy-authorization",
  "te",
  "trailer",
  "transfer-encoding",
  "upgrade",
]

const RESPONSE_STRIP_HEADERS = [
  "connection",
  "content-encoding",
  "content-length",
  "keep-alive",
  "proxy-authenticate",
  "proxy-authorization",
  "te",
  "trailer",
  "transfer-encoding",
  "upgrade",
]

function getInternalApiBaseUrl() {
  const baseUrl = process.env.INTERNAL_API_BASE_URL?.trim()

  if (!baseUrl) {
    throw new Error("INTERNAL_API_BASE_URL is not configured")
  }

  return baseUrl.replace(/\/$/, "")
}

function buildUpstreamUrl(request: NextRequest) {
  const path = request.nextUrl.pathname.replace(/^\/api\/proxy/, "")
  return `${getInternalApiBaseUrl()}${path}${request.nextUrl.search}`
}

async function proxy(request: NextRequest) {
  const headers = new Headers(request.headers)
  for (const header of REQUEST_STRIP_HEADERS) {
    headers.delete(header)
  }

  const init: RequestInit = {
    method: request.method,
    headers,
    redirect: "manual",
  }

  if (request.method !== "GET" && request.method !== "HEAD") {
    init.body = await request.arrayBuffer()
  }

  const upstream = await fetch(buildUpstreamUrl(request), init)
  const responseHeaders = new Headers(upstream.headers)

  for (const header of RESPONSE_STRIP_HEADERS) {
    responseHeaders.delete(header)
  }

  return new Response(upstream.body, {
    status: upstream.status,
    statusText: upstream.statusText,
    headers: responseHeaders,
  })
}

export {
  proxy as DELETE,
  proxy as GET,
  proxy as HEAD,
  proxy as OPTIONS,
  proxy as PATCH,
  proxy as POST,
  proxy as PUT,
}
