-T[2026_0921_171626][
	不許加載任何skill 和 記憶。給我介紹一下這個項目
][
````md
我已經瀏覽了項目結構和關鍵文檔(未加載任何 skill)。以下是介紹：

# NexusAudit 項目介紹

## 這是什麼

**NexusAudit** 是一個「代碼安全審計平台」：用戶上傳源碼包，平台把審計任務派發給執行節點，節點調用通用 AI code agent(Claude Code、OpenCode 等，通過 ACP 協議)完成自動化審計，過程事件與最終報告回傳平台，前端展示進度、agent 軌跡、漏洞信息和可下載的 DOCX 報告。帶多租戶、許可證(license)校驗和離線交付部署能力。

## 工作區佈局

當前目錄是一個開發工作區，核心項目在 `nexus-audit/`,其餘是週邊：

- `nexus-audit/` — 主項目(前後端 + SDK + 部署)
- `nexus-audit-dev-hjr-2~5/` — 多個開發分支副本
- `model-gateway/`、`LocalDeploy/`、`Deploy/`、`customer-prod-test/` — 網關、本地/客戶環境部署與測試
- `_Doc/`、`_Note/` — 文檔與筆記
- 根目錄還有交接文檔(`HANDOVER-2026-07-30-ACP.md`、`NexusAudit-OpenCode-Token-Statistics-Handoff-2026-08-27.md`)、`CHANGELOG.md` 和各種啟停腳本

## 主項目 `nexus-audit/` 四大塊

**1. `backend/` — Python FastAPI 管理面(控制面)**
- `server/`(api / services / models / core):任務創建、權限校驗、API key 解析、任務派發、事件消費、TaskView 投影；還有 DOCX 導出、節點命令、license、skills 等服務
- `engine/`(contracts / hub / storage):任務引擎與存儲契約
- `nexus/` + `modules/audit/`:審計任務 handler、狀態機
- `alembic/`:數據庫遷移

**2. `frontend/` — React 18 + TypeScript + Vite**
- 功能模塊(features):`tasks`(任務)、`nodes`(節點)、`sources`(源碼)、`keys`(模型密鑰)、`skills`、`tenants`/`users`/`members`(多租戶與成員)、`usage`(用量)、`audit-logs`、`settings`、`auth`
- 用 CodeMirror 展示源碼/Markdown,recharts 做圖表，OpenAPI 自動生成 API client

**3. `python-sdk/` — `nexusnode` 節點運行時(協議層)**
- 定位:「讓一個外部 Python 進程像平台節點一樣接任務、上報過程、上傳文件、返回結果」
- 包含 `nexusnode.acp`(ACP client、daemon、agent 事件流映射、報告 MCP server),把審計執行委託給通用 code agent
- 通信方式正從 Redis 隊列遷移到 **gRPC 直連**(`proto/nexus/node/v1/node_service.proto`)

**4. `deploy/` — 發布與交付**
- 構建離線歸檔(基礎鏡像、項目鏡像、SDK、deploy 包)，客戶側運維統一收口到單入口腳本 `nexus-audit.sh`,支持全新安裝與原地升級

## 核心業務流(來自 `docs/sdk-business-flow.md`)

```
用戶/前端 → backend 創建任務(pending)
→ 派發到節點隊列/gRPC(按 node_type + pool,如 audit:acp-general)
→ SDK 節點領取任務,準備 workspace,啟動 ACP agent 子進程
→ agent 用 skills/prompts 執行審計,寫報告並經守護進程 MCP 提交
→ SDK 上報事件/文件/usage → backend 投影 TaskView
→ 前端展示實時過程與結果,可下載 DOCX 報告
```

## 近期演進(CHANGELOG,2026 年 7–8 月)

- **7 月**:gRPC Hub-Node 雙向通信替代 Redis;節點鑑權、事件批次持久化與冪等、節點選擇策略與並發調整、任務取消/session 恢復/異常重派、節點主動提交報告、Token 統計
- **8 月上旬**:DOCX 報告導出、許可證體系、Alembic 遷移、TLS 配置、部署收口
- **8 月中旬**:新版任務詳情頁(agent 軌跡、漏洞信息、源碼文件樹與搜索、RAR 支持)、Node 獨立 Compose 部署
- **8 月下旬**:穩定性修復(ACP 報告收口、升級腳本、GPT 連接、Prompt 超時)、OpenCode 升級到 1.18.23、時間統一東八區顯示

值得一提的設計決策：平台**不綁定單一商業 agent CLI**——節點是 ACP Client,通過配置接入不同的通用 code agent,審計行為由 skills 和提示詞約束,SDK 只負責任務准入、workspace 管理、事件透傳和結果校驗上傳。

如果你想深入某一部分(比如 ACP 審計節點內部、gRPC 協議細節、或某個前端模塊),我可以繼續展開。
````
]

-T[2026_0921_171819][
	不看skill 。只看Tsinswreng裏面的記憶。說一下 開發這個項目的注意事項
][
````md
我已讀完 `.Tsinswreng/AiMemory/` 裏的全部核心記憶(Main、Environment、Discoveries、ArchitectureDeepDive、BusinessFlow、PermissionModel、GrpcSdk、CustomerTaskStuckRecovery、DeploymentMultiNode、StartupFixes、AcpOfflineStartup、FrontendTimeZone),沒有加載任何 skill。以下按記憶整理的開發注意事項(依記憶約定用簡體中文輸出、先給結論):

# NexusAudit 開發注意事項(源自 .Tsinswreng 記憶)

## 一、執行環境鐵律(踩過最多坑的地方)

- **一切項目命令在 WSL 內跑**:Python、Node.js、Docker、服務啟動和驗證一律 WSL;Windows PowerShell 只做文件和 Git 管理。沙箱內 `wsl.exe` 顯示“無發行版”是假象,不能當真實狀態。
- **給用戶在服務器/交互 shell 執行的命令塊,禁止包含 `exit`、`set -e` 等會殺掉用戶會話的語句**(2026-09-07 事故:`exit 1` 殺掉了用戶整個 shell);找不到目標就打印提示跳過。
- **WSL drvfs(`/mnt/c`)系列坑**:
  - `uvicorn --reload` 不穩定(watchfiles 崩),後端用 `StartBackendStable.sh` 無熱重載 + nohup 啟動
  - Windows npm 與 WSL npm 共用 `node_modules` 會覆蓋平台相關的 rollup/esbuild 依賴;前端構建必須在 WSL 做
  - `nexus-audit.sh upgrade` 的 `rm -rf`/`mv` 在 `/mnt/c` 上有“幽靈非空目錄”問題,會中斷在半遷移狀態(客戶原生 Linux 不踩)
  - WSL 掛載盤上 `.pytest_cache` 權限可能導致 watchfiles 退出
- Ubuntu 24.04 PEP 668 需 `PIP_BREAK_SYSTEM_PACKAGES=1`;WSL apt 的 Node 18 太舊,需 NodeSource Node 22。
- 一次性 `wsl.exe` 啟動的後台進程會隨會話退出,常駐必須 `nohup setsid`。

## 二、多 worktree 紀律(極易出事故)

- 外層 `C:/_/Code/NexusAudit` 是記憶倉庫(master);內層 `nexus-audit` 是主線(dev-hjr),`nexus-audit-dev-hjr-2~5` 各對應同名分支。**並行任務只在對應 worktree 做,不混用未提交修改**;每個 worktree 的提交、髒文件必須現場 git 查,不能從記憶推斷。
- **端口衝突**:默認前端 58004、後端 8000,多 worktree 同時啟動會互相佔用。用 `FRONTEND_PORT`/`BACKEND_PORT` 覆蓋;啟動成功不代表訪問的是目標 worktree;不要為釋放端口去停別的 worktree 進程。`RestartBackend.sh` 是端口接管語義,會殺掉同端口的其們 worktree 後端。
- **本地啟 ACP Node 必須顯式 `NEXUS_GRPC_TARGET` + 唯一 `NODE_ID`,啟動前 `ps` 清點遺留 daemon**。2026-09-07 事故:dev-hjr-3 的遺留 daemon(同 NODE_ID=Id1、無 GRPC_TARGET 默認連 localhost)搶走了 dev-hjr-2 的任務,跑到舊代碼上,且兩個 daemon 心跳交替覆寫同一會話,導致“繼續”按鈕失效。
- 當前本地 Node 入口是外層 `../AcpNode.sh <worktree> start --id <ID>`,不要再用舊的 `local/start-acp-node.sh`。

## 三、調試套路

- **任務卡住按順序查四個純文件**(都在 `.nexusnode/local/` 下,不用進 Docker/連庫):
  1. `logs/acp-node.log` — Node 領到任務了嗎
  2. `logs/backend.log` — 後端看到事件了嗎
  3. 工作區 `opencode.json` — 模型 URL/Key 配對了嗎
  4. 工作區 `transcript.ndjson` — OpenCode 有動靜嗎
- **判斷任務死活以 node 側 transcript 增量 + node 日誌 auto-continue/exception 爲準**;opencode.log 的 stream/loop 行不代表有 ACP 輸出。
- 修改 API Key 的 Base URL 或模型配置後**必須重啓 Node** 才生效(Node 啓動時讀配置生成 opencode.json)。

## 四、架構層面必須知道的設計

- **Event Sourcing**:任務狀態不是直接 UPDATE,而是事件回放投影出 TaskView。事件寫入冪等(`ON CONFLICT DO NOTHING`);改投影邏輯必須 bump Redis 緩存版本號(如 v4→v5),否則舊緩存繼續生效。任務狀態不可逆,只有 pending/running 可修改。
- **協議消息不合格走 DLQ 不丟棄**;格式錯誤有去重日誌。
- **API Key 在數據庫是明文存儲**(`key_encrypted` 字段名有誤導),加密只發生在派發時刻(AES-256-GCM)。`NEXUS_SECRET_KEY`/`NEXUS_SKILL_SECRET_KEY` 不應隨意輪換,否則歷史加密數據解不開。
- **Skill 執行無沙箱隔離**——模型讓跑什麼命令就直接 subprocess 跑,只有 CWD 限制、超時、輸出脫敏/截斷;SaaS 多租戶下是遠程代碼執行風險(已記錄待加固項)。
- 權限兩層互不包含:SYS_ADMIN 是純平臺管理員,**看不到審計業務**(設計如此);Skill 有“啓用+版本切換”雙開關,只啓用不切版本,建任務時找不到。
- 前端任務時間統一東八區(無時區時間按後端語義補 `Z` 再轉 `Asia/Shanghai`),非任務頁面保留瀏覽器本地時區,別擴大行爲。
- FastAPI ≥0.139 的 `_IncludedRouter` 會繞過權限覆蓋檢查的路由收集(已修復,升級 FastAPI 時要留意);`.env` 加載用基於 `__file__` 的絕對路徑。

## 五、ACP/OpenCode 專項(近期問題集中區)

- **OpenCode 版本必須精確 pin(當前 1.18.23)並端到端驗證**:Docker Hub 的 `openeuler/opencode` 標籤和 npm 的 `opencode-ai` 是兩套版本;歷史上“版本不低於下限”的策略造成開發/生產漂移,token 統計全壞。禁止用可變 `latest`。Windows 傳入 CRLF 曾使離線版本校驗誤判。
- **opencode.json 不聲明模型窗口 + `OPENCODE_DISABLE_MODELS_FETCH=true` → OpenCode 永不主動壓縮**,只能報錯後被動壓;輸出預留是硬編碼 32768,必須用 `OPENCODE_EXPERIMENTAL_OUTPUT_TOKEN_MAX=8192` 覆蓋釋放上下文。
- **離線啓動四禁**:禁默認插件、禁自動更新、禁 LSP 下載、禁模型拉取,並複用 Docker seed;本地 wrapper 已與生產 wrapper 對齊,別再分叉。
- 模型名全鏈路逐字透傳、不做歸一化——建任務時橫槓/下劃線筆誤會直接 `provider_model_invalid`;DeepSeek Base URL 必須帶 `/v1` 後綴。
- **核心設計約束(用戶拍板)**:報告生成失敗即使自動重試耗盡,也必須轉可恢復的異常中斷等待人工繼續,**絕不能把任務打成終態失敗**;同理“防假零發現守衛”(首輪無真實產出時拒收空報告)的語義不能破——任務 completed 不代表審計真的做了,驗收必須查 transcript 有源碼讀取/工具調用。
- 已固化的恢復機制別輕易動:超時自動繼續(有動靜、無上限、立即重試——用戶明確決定不加次數上限)、錯誤三檔分類(永久轉人工/瞬時網絡自動續/其餘人工)、零產出閘(`MAX_STALLED=2`)、思考循環看門狗、報告重試。
- **被審源碼包是不可信輸入**:包內自帶的 `AGENTS.md`/`CLAUDE.md`/skills 是提示詞注入攻擊面;本地開發還要注意 workspace root 別嵌在倉庫樹內(OpenCode 會向上爬加載外層 `.agents/skills`,污染審計行爲)。
- ACP 事件含 NUL 字符曾使任務永久 running(Hub 側已兜底清洗);**修復前不要刪中毒 Outbox 文件**。上傳層接受 RAR/7z 但解包只支持 ZIP/TAR,加密歸檔會“成功出報告但實際沒審”。

## 六、部署與生產紅線

- 客戶唯一運維入口是 `deploy/release/nexus-audit.sh`;操作文檔不得硬編碼機器絕對路徑。
- **升級必須保留 `.env` 和數據卷,先備份數據庫再遷移;禁止把清空卷當升級或排障手段**。
- **同一 Docker 主機不得並行跑多套固定名 NexusAudit 棧再執行 `upgrade`**:`preserve_existing_volumes` 會從運行中的固定名容器讀卷名寫回 `.env`,把卷指向別的棧(2026-08-25 事故,密碼錯配、backend 重啓循環)。升級前確認沒有其他 `nexusaudit-db` 等固定名容器在跑。
- 驗證數據庫密碼要從另一容器走網絡連(scram-sha-256);容器內連 localhost 走 trust 免密,永遠“成功”,無參考價值。
- 部署憑據策略:固定模板值、確定性複製 `.env.example`,**不隨機生成**;已有容器/卷而 `.env` 缺失時直接停止。MinIO root 密碼無法腳本化輪換,“按 .env 對齊密碼”方案已評估不可行。
- 運維語義:`stop` 只停容器;`down` 刪容器保卷;`down --volumes` 才刪數據。
- 多 ACP Node 必須獨立 Compose project、容器名、workspace 卷和 Node ID;默認 `acp-node-1,acp-node-2`,併發默認 8(`NEXUSNODE_ACP_MAX_CONCURRENCY`)。
- backend 重建後容器 IP 變化,frontend nginx 緩存舊 IP 會 502,需重啓 frontend(已自動化 + resolver 動態解析)。
- **構建腳本從工作樹打包(不走 git archive)**——發布包可能含未提交改動;測試過後必須提交,保證包可追溯到 commit(0907 包的交付紀律教訓)。

## 七、工作紀律

- 記憶使用原則:源碼、部署腳本、測試結果和用戶確認**優先於記憶**;Git、容器、服務等動態狀態必須現場查;穩定規則與帶日期的當前事實分開;未在目標 worktree 重跑的測試不得寫成“當前已通過”。
- 未經許可不執行 git 寫操作;修改嚴格限定在目標 worktree,不碰其他 worktree。
- 測試一律在 WSL 執行;輸出用簡體中文、先給直接結論。

一條提煉:這個項目的事故模式高度集中在“**多套環境互相串門**”(端口、NODE_ID、固定名容器、worktree 進程、版本漂移)和“**把中斷僞裝成終態**”(永久 running、空報告 completed)兩類上——開發時對這兩類保持警覺,能避開記憶裏絕大多數已付過學費的坑。
````
]