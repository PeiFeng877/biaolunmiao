#!/usr/bin/env node

console.error(
  [
    "[prepare-stg-data-fixture] 旧云端 stg 已退役，本脚本不再可用。",
    "请改用本地联调，或使用 scripts/prepare_prod_data_fixture.mjs 针对 FC 默认域名/正式后端准备测试数据。",
  ].join("\n")
)
process.exit(1)
