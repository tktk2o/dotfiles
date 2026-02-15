---
name: calendar
description: >
  Google Calendarから予定を取得して日報に追加する。
  Use when: 「カレンダー取得」「今日の予定」「明日の予定」「日報にMTG追加」など。
allowed-tools: Read, Write, Edit, mcp__claude-in-chrome__tabs_context_mcp, mcp__claude-in-chrome__tabs_create_mcp, mcp__claude-in-chrome__navigate, mcp__claude-in-chrome__read_page, mcp__claude-in-chrome__computer
---

# Google Calendar 予定取得 Skill

Claude in Chromeでカレンダーにアクセスし、予定を取得して日報形式で出力する。

## 使い方

- `/calendar` - 今日の予定を取得
- `/calendar 明日` - 明日の予定を取得
- `/calendar 2025-02-15` - 指定日の予定を取得

## 手順

1. `tabs_context_mcp` で現在のタブ状況を確認

2. `tabs_create_mcp` で新しいタブを作成

3. `navigate` でカレンダーURLにアクセス
   - ベースURL: `https://calendar.google.com/calendar/u/0/r`
   - 日付指定: `/day/YYYY/M/D` を付加

4. `read_page` でページ内容を取得

5. 予定を抽出してフォーマット:
   ```
   - HH:MM-HH:MM MTG名
   - HH:MM-HH:MM MTG名
   ```

6. 必要に応じて日報の raw ファイルに追記

## 注意事項

- Googleにログイン済みのChromeが必要
- ログインしていない場合はユーザーに通知する
- タブはそのまま残る（ユーザーが確認可能）
