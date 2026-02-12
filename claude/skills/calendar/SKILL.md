---
name: calendar
description: >
  Google Calendarから予定を取得して日報に追加する。
  Use when: 「カレンダー取得」「今日の予定」「明日の予定」「日報にMTG追加」など。
allowed-tools: Read, Write, Edit, mcp__plugin_playwright_playwright__browser_navigate, mcp__plugin_playwright_playwright__browser_snapshot, mcp__plugin_playwright_playwright__browser_click, mcp__plugin_playwright_playwright__browser_close
---

# Google Calendar 予定取得 Skill

Playwrightでカレンダーにアクセスし、予定を取得して日報形式で出力する。

## 使い方

- `/calendar` - 今日の予定を取得
- `/calendar 明日` - 明日の予定を取得
- `/calendar 2025-02-15` - 指定日の予定を取得

## 手順

1. カレンダーURLにアクセス
   - ベースURL: `https://calendar.google.com/calendar/u/0/r`
   - 日付指定: `/day/YYYY/M/D` を付加

2. browser_snapshot でページを取得

3. 予定を抽出してフォーマット:
   ```
   - HH:MM-HH:MM MTG名
   - HH:MM-HH:MM MTG名
   ```

4. 必要に応じて日報の raw ファイルに追記

## 注意事項

- Googleにログイン済みの状態が必要
- ログインしていない場合はユーザーに通知する
- 取得後はブラウザを閉じる
