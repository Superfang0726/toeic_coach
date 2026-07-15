繁體中文 | [English](README.en.md)

# TOEIC Coach

一款以 Google Gemini AI 驅動的 Flutter 桌面應用程式，透過填空題練習 TOEIC Part 5 單字。

---

## 功能特色

### AI 自動出題
- 使用 Google Gemini 即時生成 TOEIC Part 5 填空句子。
- 每題提供四個選項，選項從你的單字庫中自動挑選。
- 已熟練（綠色）的單字用於組成句子；尚在學習的單字（紅／黃）作為答案選項，確保每題都在練習你真正需要加強的地方。

### 間隔重複記憶追蹤
- 每個單字有三個熟練等級：**紅色**（不熟）→ **黃色**（學習中）→ **綠色**（已熟練）。
- 答對升級、答錯降級（黃色答錯直接降回紅色最低點）。
- 複習輪次機制避免同一單字短時間內重複出現。

### 詳細 AI 解析
- 作答後，Gemini 逐一說明每個選項正確或錯誤的原因。
- 解析以**繁體中文**呈現，適合台灣／華語學習者。
- 系統自動根據作答結果更新單字熟練度。

### 單字資料庫面板
- 右側面板顯示完整單字清單，包含目前熟練等級與狀態。
- 可新增單字、依等級篩選，並一覽整體學習進度。

### 持久化儲存
- 單字庫存至應用程式文件目錄中的 `vocabulary.xlsx`，可在應用程式外直接編輯。
- 對話紀錄跨工作階段保留，隨時可回顧過去的題目與解析。

### 自動更新
- 每次啟動時自動檢查 GitHub 是否有新版本，一鍵完成更新。

---

## 安裝方式

### Windows（建議 — 使用預建安裝程式）

1. 前往 [Releases 頁面](https://github.com/Superfang0726/toeic_coach/releases/latest)。
2. 下載 `toeic_coach-X.Y.Z-setup.exe`。
3. 執行安裝程式。若 Windows SmartScreen 顯示警告，點選**「其他資訊」→「仍要執行」**（此應用程式尚未進行程式碼簽署，屬正常現象）。
4. 從開始功能表或桌面捷徑啟動 **TOEIC Coach**。

### 從原始碼建置（Windows / macOS / Linux）

**前置需求：**
- [Flutter SDK](https://docs.flutter.dev/get-started/install)（Dart SDK ≥ 3.12）
- [Google Gemini API 金鑰](https://aistudio.google.com/app/apikey)（免費方案可用）

```bash
git clone https://github.com/Superfang0726/toeic_coach.git
cd toeic_coach
flutter pub get
flutter run -d windows   # 或 -d macos / -d linux
```

建置 Release 版本：

```bash
flutter build windows --release
# 輸出位置：build\windows\x64\runner\Release\
```

---

## 使用方式

### 1. 設定 API 金鑰
首次啟動後，點選**設定**（齒輪圖示），貼上你的 Google Gemini API 金鑰。也可在此選擇使用的 Gemini 模型（預設：`gemini-3.1-flash-lite`）。

### 2. 新增單字
在右側**單字**面板中新增你想練習的單字。新單字預設從**紅色**（不熟）開始。

### 3. 開始練習
左側**對話**面板會自動執行練習流程：
- 系統生成一道填空題。
- 從四個選項中選擇答案。
- 閱讀 AI 解析，了解各選項正確或錯誤的原因。
- 繼續下一題——應用程式會根據最需要加強的單字自動挑選下一題。

### 4. 追蹤進度
每次作答後單字等級即時更新。綠色單字退出主動練習輪換；紅色單字會更頻繁出現，直到熟練度提升為止。

### 5. 檢查更新
前往**設定 → 檢查更新**可手動檢查新版本，或讓應用程式在每次啟動時自動檢查。
