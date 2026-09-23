#!/bin/sh
set -e

D1_DIR="/app/dist/server/.wrangler/state/v3/d1/miniflare-D1DatabaseObject"
INIT_D1="/app/init-data/wrangler-state/v3/d1/miniflare-D1DatabaseObject"

# Auto-init D1 database if volume is empty (first boot)
if [ -d "$INIT_D1" ] && { [ ! -f "$D1_DIR/faaf2b0445ab934c3aac48ddf0cdfade8f9bac050be98993748742cdd2cb05fb.sqlite" ] || [ ! -s "$D1_DIR/faaf2b0445ab934c3aac48ddf0cdfade8f9bac050be98993748742cdd2cb05fb.sqlite" ]; }; then
  echo "[entrypoint] Initializing D1 database from bundled data..."
  mkdir -p "$D1_DIR"
  for f in "$INIT_D1"/*.sqlite*; do
    case "$(basename "$f")" in *.broken*) continue ;; esac
    cp "$f" "$D1_DIR/"
  done
  echo "[entrypoint] D1 initialized ($(du -sh "$D1_DIR" | cut -f1))"
fi

# Auto-init R2 cache
R2_DIR="/app/dist/server/.wrangler/state/v3/r2/miniflare-R2BucketObject"
INIT_R2="/app/init-data/wrangler-state/v3/r2/miniflare-R2BucketObject"
if [ -d "$INIT_R2" ] && [ ! -f "$R2_DIR/metadata.sqlite" ]; then
  echo "[entrypoint] Initializing R2 cache..."
  mkdir -p "$R2_DIR"
  cp -r "$INIT_R2"/* "$R2_DIR/"
fi

# Auto-init Cache
CACHE_DIR="/app/dist/server/.wrangler/state/v3/cache/miniflare-CacheObject"
INIT_CACHE="/app/init-data/wrangler-state/v3/cache/miniflare-CacheObject"
if [ -d "$INIT_CACHE" ] && [ ! -f "$CACHE_DIR/metadata.sqlite" ]; then
  echo "[entrypoint] Initializing cache..."
  mkdir -p "$CACHE_DIR"
  cp -r "$INIT_CACHE"/* "$CACHE_DIR/"
fi

# Auto-init game data
DATA_DIR="/app/data"
INIT_DATA="/app/init-data/app-data"
if [ -d "$INIT_DATA" ] && [ ! -f "$DATA_DIR/crafting/.initialized" ]; then
  echo "[entrypoint] Initializing game data..."
  cp -r "$INIT_DATA"/* "$DATA_DIR/" 2>/dev/null || true
  touch "$DATA_DIR/.initialized"
fi

# Generate .dev.vars for wrangler (Worker secrets not in process.env)
DEV_VARS="/app/dist/server/.dev.vars"
if [ -n "$ADMIN_AUTH_SECRET" ] || [ -n "$ADMIN_PASSWORD_HASH" ]; then
  echo "[entrypoint] Generating .dev.vars for Worker secrets..."
  : > "$DEV_VARS"
  for var in ADMIN_AUTH_SECRET ADMIN_PASSWORD_HASH ANALYTICS_PSEUDONYM_KEY ANALYTICS_IP_ENCRYPTION_KEY SITE_URL NEXT_PUBLIC_SITE_URL X_LOCAL_EXPLORER WRANGLER_WRITE_LOGS ADMIN_API_KEY KEEP_LOCAL_MAP_ASSETS; do
    eval "val=\$$var"
    if [ -n "$val" ]; then
      echo "${var}=${val}" >> "$DEV_VARS"
    fi
  done
  echo "[entrypoint] .dev.vars created ($(wc -l < "$DEV_VARS") vars)"
fi

# Strip legacy_env from wrangler.json (wrangler 4.x rejects it, vinext still emits it)
# Also fix assets.directory to absolute path (wrangler dev resolves it from WORKDIR /app,
# not from wrangler.json location /app/dist/server/ — so "../client" becomes "/client" → 404)
WRANGLER_JSON="/app/dist/server/wrangler.json"
if [ -f "$WRANGLER_JSON" ]; then
  cat > /tmp/fix-wrangler.js << 'FIXEOF'
const fs = require("fs");
const f = "/app/dist/server/wrangler.json";
const j = JSON.parse(fs.readFileSync(f, "utf8"));
if ("legacy_env" in j) {
  delete j.legacy_env;
  console.log("[entrypoint] Removed legacy_env from wrangler.json");
}
if (j.assets && j.assets.directory && j.assets.directory !== "/app/dist/client") {
  j.assets.directory = "/app/dist/client";
  console.log("[entrypoint] Fixed assets.directory to /app/dist/client (was " + JSON.stringify(j.assets.directory) + ")");
}
fs.writeFileSync(f, JSON.stringify(j, null, 2));
FIXEOF
  node /tmp/fix-wrangler.js
  rm -f /tmp/fix-wrangler.js
fi

# cgroup 内存采样器（2026-09-23，**只加在 kina-dev**）：为了把"空闲也会 OOM"从猜变成可测。
# 为什么绕这一圈：Dokploy 只读通道拿不到逐容器 RSS（application.readAppMonitoring 对 compose 服务返回 null），
# 也没有任何 docker logs 类过程（docker.getLogs / readLogs / logs 全 "No procedure found"），
# getEvents 的 since/until/filters 又被忽略（只有约 5 分钟窗口）。但容器内看得见 /sys/fs/cgroup/* 与
# /proc/<pid>/status，而 docker.readContainerFile 能把文件读回来 ⇒ 用一条常驻采样换到
# "谁在吃内存 + 跨过阈值的时刻 + 应用什么时候开始不回话"。
# 约束：独立进程、任何异常只写进行内不影响应用、文件只留最后 3000 行（约 25 小时，避免自己把 cgroup 撑大）。
# 必须是 .cjs：/app/package.json 里是 "type": "module"，写成 .js 会被当 ESM ⇒ require 直接 ReferenceError
# （上一版就是这么死的；旁边那个 /tmp/fix-wrangler.js 能跑是因为 /tmp 下没有 package.json）。
cat > /app/mem-probe.cjs << 'MEMEOF'
const fs = require("fs");
const http = require("http");
// 落在持久卷 /app/data 上：容器重启会丢掉内存里的 rows，若只写 /app 层就永远看不到"死亡前峰值"。
const OUT = "/app/data/.mem-probe.tsv";
const KEEP = 3000;
const BOOT = "boot\t" + new Date().toISOString();
// memory.stat 的 anon 与 file 必须分开记：只涨 anon 才是进程真的吃内存，
// 只涨 file 是页缓存（读资产/日志也算），kernel 能回收，两者处置完全不同。
// （09-23 教训：我先用 cur 的斜率推断"workerd 每渲染漏 8MiB"，用 12 次显式请求做因果实验直接否掉了 ——
//  启动期的爬升不是稳态泄漏速率。）
const stat = () => {
  try {
    const t = fs.readFileSync("/sys/fs/cgroup/memory.stat", "utf8");
    const g = (k) => { const m = t.match(new RegExp("^" + k + " ([0-9]+)$", "m")); return m ? m[1] : "-"; };
    return "anon=" + g("anon") + "\tfile=" + g("file") + "\tslab=" + g("slab");
  } catch { return "anon=-\tfile=-\tslab=-"; }
};
const num = (p) => { try { const v = fs.readFileSync(p, "utf8").trim(); return v === "max" ? "max" : (Number.isFinite(Number(v)) ? Number(v) : "?" + v.slice(0, 8)); } catch { return "-"; } };
const topProcs = () => {
  const out = [];
  let ids = [];
  try { ids = fs.readdirSync("/proc").filter((x) => /^[0-9]+$/.test(x)); } catch { return ""; }
  for (const pid of ids) {
    try {
      const st = fs.readFileSync("/proc/" + pid + "/status", "utf8");
      const rss = st.match(/^VmRSS:\s+([0-9]+) kB$/m);
      const nm = st.match(/^Name:\s+(\S+)$/m);
      if (rss && nm) out.push({ n: nm[1], kb: Number(rss[1]) });
    } catch {}
  }
  out.sort((a, b) => b.kb - a.kb);
  const merged = {};
  for (const p of out) merged[p.n] = (merged[p.n] || 0) + p.kb;
  return Object.entries(merged).sort((a, b) => b[1] - a[1]).slice(0, 4).map(([k, v]) => k + "=" + v).join(" ");
};
const probeApp = () => new Promise((res) => {
  let done = false;
  const fin = (v) => { if (!done) { done = true; res(v); } };
  const r = http.get({ host: "127.0.0.1", port: 3001, path: "/en/", timeout: 9000 }, (x) => { x.resume(); fin(String(x.statusCode)); });
  r.on("error", (e) => fin("E" + (e.code || e.name || "?")));
  r.on("timeout", () => { r.destroy(); fin("TIMEOUT"); });
});
let rows = [];
try { rows = fs.readFileSync(OUT, "utf8").trim().split("\n").filter(Boolean).slice(-KEEP); } catch { rows = []; }
rows.push(BOOT);
// 自我探测要限频：实测每次首页 SSR 有约 7MiB 不被回收，而容器里已经有 healthcheck(30s) +
// 看门狗(20s) 两个探测在灌流量。本采样器再每 30s 探一次就成了第三个来源 ⇒ 只在每第 4 拍（2 分钟）
// 探一次，仍足以抓到"什么时候不回话"，但把我这份贡献从 2 次/分降到 0.5 次/分。
let tickCount = 0;
async function tick() {
  let app = "-";
  tickCount += 1;
  if (tickCount % 4 === 1) {
    try { app = await probeApp(); } catch { app = "Eprobe"; }
  } else {
    app = "(skip)";
  }
  let own = 0;
  try { own = Math.round(process.memoryUsage().rss / 1024); } catch {}
  const row = [
    new Date().toISOString(),
    "cur=" + num("/sys/fs/cgroup/memory.current"),
    "max=" + num("/sys/fs/cgroup/memory.max"),
    "peak=" + num("/sys/fs/cgroup/memory.peak"),
    "swap=" + num("/sys/fs/cgroup/memory.swap.current"),
    stat(),
    "app=" + app,
    "probeRSS_KB=" + own,
    "topKB:" + topProcs(),
  ].join("\t");
  rows.push(row);
  if (rows.length > KEEP) rows.splice(0, rows.length - KEEP);
  try { fs.writeFileSync(OUT + ".tmp", rows.join("\n") + "\n"); fs.renameSync(OUT + ".tmp", OUT); } catch (e) {
    try { fs.writeFileSync("/tmp/mem-probe.err", new Date().toISOString() + " " + String((e && e.message) || e)); } catch {}
  }
}
tick();
setInterval(tick, 30000);
MEMEOF
# stderr 必须落盘：上一版把它接到 /dev/null，采样器一启动就退出而我看不到任何原因（自己把自己弄瞎）。
node /app/mem-probe.cjs >> /app/data/.mem-probe.out 2>&1 &

# 自愈看门狗（2026-09-22 从 kina-test 已验证的那版原样搬来，test 仓库 f638d3b）。
# 背景：workerd 把自身 cgroup 撑满被内核杀掉后，PID 1 的 wrangler 既不退出也不重启子进程
# ⇒ 容器停在 "running 但零服务" 的僵尸态（09-22 实测：连续超时、日志全静默、不自愈；
# kina-dev 自己就在 09-22 19:21 起以 OOMKilled=true / FailingStreak 一路涨 卡在僵尸态）。
# 处理：冷启动宽限后连续探测失败到阈值就结束 PID 1，交给 compose 的 restart: unless-stopped 复活。
# 宽限 300s 与本 compose 的 healthcheck start_period 一致（冷启动要跑 assertContentRegistryValid + workerd 初始化）。
(
  WD_PROBE='fetch("http://localhost:3001/en/", { signal: AbortSignal.timeout(10000) }).then((r) => process.exit(r.ok ? 0 : 1)).catch(() => process.exit(1))'
  g=0
  while [ "$g" -lt 15 ]; do sleep 20; g=$((g + 1)); done
  fails=0
  while :; do
    if node -e "$WD_PROBE" 2>/dev/null; then
      fails=0
    else
      fails=$((fails + 1))
      echo "[watchdog] /en/ 探测失败 ${fails}/5"
      if [ "$fails" -ge 5 ]; then
        echo "[watchdog] 连续 5 次失败 ⇒ 结束 PID 1，由 Docker 重启容器（僵尸态不可自愈）"
        kill -TERM 1 2>/dev/null
        sleep 10
        kill -KILL 1 2>/dev/null
        exit 0
      fi
    fi
    sleep 20
  done
) &

echo "[entrypoint] Starting application..."
exec "$@"
