# Universal Control Restarter

一個用來恢復 macOS Universal Control（通用控制）不穩連線的小工具。

它包含兩個部分：

- 一個 LaunchAgent watchdog，會監控 Universal Control / Continuity 的異常徵兆，並在連線看起來卡住時重啟相關的本機 daemon。
- 一個選單列按鈕，當游標開始延遲、卡頓，或無法跨裝置移動時，可以手動重啟 Universal Control 相關服務。

這個工具刻意只在本機運作。它不收集 telemetry、不送出網路請求，也不需要管理員權限。

## 系統需求

- 支援 Universal Control 的 macOS
- 可透過 `xcrun swiftc` 使用 Xcode command line tooling
- zsh

## 安裝

一般使用者可以下載 `Universal-Control-Restarter.zip`，解壓縮後，把 `Universal Control Restarter.app` 移到 `/Applications`，然後打開它。

第一次啟動時，app 會自動安裝或修復 watchdog LaunchAgent。安裝完成後，macOS 選單列會出現一個圓形重啟圖示。

因為這個 app 尚未 notarize，從網路下載的版本可能會出現 Gatekeeper 警告。第一次開啟時，請在 Finder 內對 app 按右鍵，選擇 `Open`。

如果要從原始碼安裝，clone repo 後執行：

```zsh
zsh scripts/install-universal-control-watchdog.zsh
zsh scripts/install-universal-control-menubar.zsh
```

watchdog 會安裝到：

```text
~/Library/LaunchAgents/com.local.universal-control-watchdog.plist
```

選單列 app 會安裝到：

```text
~/Applications/Universal Control Restarter.app
~/Library/LaunchAgents/com.local.universal-control-restarter-menubar.plist
```

log 會寫到：

```text
~/Library/Application Support/UniversalControlWatchdog/logs/
```

## 建立 Release App

```zsh
zsh scripts/build-release.zsh
```

這會產生：

```text
dist/Universal Control Restarter.app
dist/Universal-Control-Restarter.zip
```

app bundle 會把 watchdog 腳本包在 `Contents/Resources`，並使用 ad-hoc signing。這適合本機或小範圍分享，但還不是適合大規模公開散布的 notarized app。

## 使用方式

安裝後，macOS 選單列會出現一個圓形重啟圖示。

選單功能：

- `Restart Universal Control`：重啟 `UniversalControl`、`sharingd`、`rapportd`、`SidecarRelay`、`useractivityd`。
- `Run Watchdog Check`：立即執行一次 watchdog 檢查。
- `Open Watchdog Log`：打開 watchdog log。
- `Open Log Folder`：打開 log 資料夾。

也可以手動觸發 watchdog：

```zsh
/bin/zsh "$HOME/Library/Application Support/UniversalControlWatchdog/universal-control-watchdog.zsh"
```

或直接強制重啟：

```zsh
killall UniversalControl sharingd rapportd SidecarRelay useractivityd 2>/dev/null
```

macOS 會自動重新啟動這些服務。

## Watchdog 行為

watchdog 每 60 秒執行一次。當它看到以下情況時，會重啟 Continuity 相關服務：

- Universal Control / Continuity daemon 缺失
- 最近 log 內出現 `clink:0`、`rdlink:0` 或 `no data connection`
- Rapport endpoint 遺失，例如 `Reachable -> Unreachable` 或 `Lost AWDL device`

為了避免反覆重啟，它有 5 分鐘冷卻時間。

如果最近 log 顯示 Universal Control 連線健康，例如 `Connected`、`ACCEPTED` 或 `clink:[1-9]`，watchdog 會忽略較舊的失敗 log。

## 移除

```zsh
zsh scripts/uninstall-universal-control-menubar.zsh
zsh scripts/uninstall-universal-control-watchdog.zsh
```

移除腳本會刪除 LaunchAgent，並停止選單列程序。runtime log 仍會保留在：

```text
~/Library/Application Support/UniversalControlWatchdog/
```

如果不再需要 log，可以手動刪除這個資料夾。

## 注意事項

Universal Control 依賴 Bluetooth、AWDL、Wi-Fi P2P、Handoff，以及本機 Apple daemon。這個工具不會修復路由器干擾、Bluetooth 訊號太弱、iCloud 帳號不一致，或不支援的裝置。它只會自動化「重啟本機 Continuity 服務」這條經常能恢復卡住或降級連線的處理路徑。

## 授權

MIT
