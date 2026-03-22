#!/usr/bin/env node

const baseUrl = (
  process.env.BLM_TEST_REMOTE_BASE_URL?.trim() ||
  process.env.BLM_PROD_API_BASE_URL?.trim() ||
  "https://fc-default-domain.cn-hangzhou.fcapp.run"
).replace(/\/$/, "")

function shellQuote(value) {
  return `'${String(value).replace(/'/g, `'\"'\"'`)}'`
}

function fail(message, details) {
  console.error(`[prepare-prod-data-fixture] FAIL ${message}`)
  if (details) {
    console.error(typeof details === "string" ? details : JSON.stringify(details, null, 2))
  }
  process.exit(1)
}

async function main() {
  const fixtureTeamPublicId = process.env.BLM_UI_TEST_PROD_JOIN_TEAM_PUBLIC_ID?.trim() || ""
  const fixtureTeamName = process.env.BLM_UI_TEST_PROD_JOIN_TEAM_NAME?.trim() || ""

  if (!fixtureTeamPublicId || !fixtureTeamName) {
    fail(
      "missing prod-data fixture env vars; set BLM_UI_TEST_PROD_JOIN_TEAM_PUBLIC_ID and BLM_UI_TEST_PROD_JOIN_TEAM_NAME explicitly",
      { baseUrl }
    )
  }

  process.stdout.write(
    [
      `export BLM_UI_TEST_PROD_JOIN_TEAM_PUBLIC_ID=${shellQuote(fixtureTeamPublicId)}`,
      `export BLM_UI_TEST_PROD_JOIN_TEAM_NAME=${shellQuote(fixtureTeamName)}`,
    ].join("\n") + "\n"
  )
}

main().catch((error) => {
  fail("unexpected error", error instanceof Error ? error.stack : String(error))
})
