# トラブルシューティングガイド

このドキュメントでは、日報管理ツールの使用中に発生する可能性のある問題と、その解決方法について説明します。

## 目次

- [jqがインストールされていない場合](#jqがインストールされていない場合)
- [launchdが起動しない場合](#launchdが起動しない場合)
- [通知が表示されない場合](#通知が表示されない場合)
- [日報ファイルが破損した場合](#日報ファイルが破損した場合)
- [日付の計算が正しくない場合](#日付の計算が正しくない場合)
- [ログファイルの確認方法](#ログファイルの確認方法)

---

## jqがインストールされていない場合

### 症状

```
エラー: jqが必要です。インストールしてください: brew install jq
```

### 原因

このツールはJSON処理にjqを使用しています。jqがインストールされていない場合、スクリプトが正常に動作しません。

### 解決方法

#### Homebrewを使用している場合

```bash
brew install jq
```

#### Homebrewがインストールされていない場合

1. Homebrewをインストール:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

2. jqをインストール:

```bash
brew install jq
```

#### 別の方法でインストールする場合

- 公式サイトからダウンロード: https://jqlang.github.io/jq/download/
- MacPortsを使用: `sudo port install jq`

### 確認方法

```bash
jq --version
# 出力例: jq-1.6
```

---

## launchdが起動しない場合

### 症状

- リマインダー通知が指定した時間に表示されない
- `launchctl list` コマンドでサービスが表示されない

### 原因と解決方法

#### 1. plistファイルが正しくロードされていない

**確認方法:**

```bash
launchctl list | grep workmanagement
```

出力がない場合、plistがロードされていません。

**解決方法:**

```bash
# plistファイルをロード
launchctl load ~/Library/LaunchAgents/com.workmanagement.morning.plist
launchctl load ~/Library/LaunchAgents/com.workmanagement.evening.plist

# 確認
launchctl list | grep workmanagement
```

#### 2. plistファイルのパスが間違っている

**確認方法:**

```bash
# plistファイルの内容を確認
cat ~/Library/LaunchAgents/com.workmanagement.morning.plist
```

ProgramArgumentsセクションのパスが正しいことを確認してください。

**解決方法:**

```bash
# config.shを編集してWORK_DIRを正しいパスに設定
vim config.sh

# plistファイルを再生成
./generate_plist.sh

# 既存のplistをアンロード
launchctl unload ~/Library/LaunchAgents/com.workmanagement.morning.plist 2>/dev/null || true
launchctl unload ~/Library/LaunchAgents/com.workmanagement.evening.plist 2>/dev/null || true

# 新しいplistをコピーして再ロード
cp com.workmanagement.morning.plist ~/Library/LaunchAgents/
cp com.workmanagement.evening.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.workmanagement.morning.plist
launchctl load ~/Library/LaunchAgents/com.workmanagement.evening.plist
```

#### 3. plistファイルに構文エラーがある

**確認方法:**

```bash
plutil -lint ~/Library/LaunchAgents/com.workmanagement.morning.plist
```

**解決方法:**

エラーがある場合は、`./generate_plist.sh`を再実行してplistファイルを再生成してください。

#### 4. 権限の問題

**確認方法:**

```bash
ls -la ~/Library/LaunchAgents/com.workmanagement.*.plist
```

**解決方法:**

```bash
# 権限を修正
chmod 644 ~/Library/LaunchAgents/com.workmanagement.morning.plist
chmod 644 ~/Library/LaunchAgents/com.workmanagement.evening.plist
```

---

## 通知が表示されない場合

### 症状

- launchdは起動しているが、通知が表示されない
- スクリプトを手動で実行すると通知が表示される

### 原因と解決方法

#### 1. macOSの通知設定が無効になっている

**解決方法:**

1. システム環境設定（システム設定）を開く
2. 「通知」または「通知と集中モード」を選択
3. 「スクリプトエディタ」または「ターミナル」を検索
4. 通知を許可する設定になっていることを確認

#### 2. おやすみモード/集中モードが有効になっている

**解決方法:**

- メニューバーの通知センターアイコンを確認
- おやすみモード/集中モードを無効にする

#### 3. ログファイルを確認してエラーを調査

**確認方法:**

```bash
# 朝のリマインダーのログ
cat morning.log
cat morning.error.log

# 夕方のリマインダーのログ
cat evening.log
cat evening.error.log
```

エラーメッセージがある場合、それに基づいて対処してください。

#### 4. osascriptの実行権限の問題

**解決方法:**

1. システム環境設定 → セキュリティとプライバシー → プライバシー
2. 「アクセシビリティ」または「オートメーション」を選択
3. ターミナルまたはスクリプトエディタに権限が付与されていることを確認

---

## 日報ファイルが破損した場合

### 症状

```
parse error: Invalid numeric literal at line X, column Y
```

### 原因

JSONファイルが破損している、または不正な形式になっている。

### 解決方法

#### 1. バックアップがある場合

```bash
# 破損したファイルを退避
mv 2025/11/2025-11-22.json 2025/11/2025-11-22.json.broken

# バックアップから復元（Time Machineなど）
```

#### 2. バックアップがない場合

```bash
# JSONファイルの構文をチェック
jq . 2025/11/2025-11-22.json

# 手動でファイルを修正（エラー箇所を特定）
vim 2025/11/2025-11-22.json

# または新しいファイルを作成
./edit_report.sh 2025-11-22
```

#### 3. 最小限のテンプレートファイルを作成

```bash
cat > 2025/11/2025-11-22.json <<'EOF'
{
  "date": "2025-11-22",
  "tasks": [],
  "notes": [],
  "time_tracking": {
    "start_time": null,
    "end_time": null,
    "breaks": []
  }
}
EOF
```

---

## 日付の計算が正しくない場合

### 症状

- 翌日のタスクが間違った日付に保存される
- 昨日のサマリが表示されない

### 原因

macOSとLinuxで`date`コマンドの構文が異なるため、環境によっては日付計算が失敗する可能性があります。

### 解決方法

#### macOSの場合

スクリプトはmacOS向けに最適化されています。以下のコマンドが動作することを確認してください:

```bash
# 明日の日付
date -v+1d +%Y-%m-%d

# 昨日の日付
date -v-1d +%Y-%m-%d
```

#### Linuxの場合

`edit_report.sh`にはLinux用のフォールバックが実装されていますが、他のスクリプトも修正が必要な場合があります。

```bash
# Linuxで明日の日付
date -d "tomorrow" +%Y-%m-%d

# Linuxで昨日の日付
date -d "yesterday" +%Y-%m-%d
```

---

## ログファイルの確認方法

リマインダースクリプトの動作ログは以下の場所に保存されます:

### 朝のリマインダーのログ

```bash
# 標準出力ログ
cat morning.log

# エラーログ
cat morning.error.log
```

### 夕方のリマインダーのログ

```bash
# 標準出力ログ
cat evening.log

# エラーログ
cat evening.error.log
```

### ログの削除

ログファイルが大きくなった場合は削除できます:

```bash
rm -f morning.log morning.error.log evening.log evening.error.log
```

---

## その他のよくある問題

### スクリプトに実行権限がない

**症状:**

```
Permission denied
```

**解決方法:**

```bash
chmod +x *.sh
```

### ディレクトリが存在しない

**症状:**

```
No such file or directory
```

**解決方法:**

ディレクトリは自動的に作成されますが、手動で作成することもできます:

```bash
mkdir -p ~/Library/LaunchAgents
```

### 設定変更が反映されない

**解決方法:**

1. `config.sh`を編集
2. `./generate_plist.sh`を実行
3. plistファイルを再ロード

```bash
launchctl unload ~/Library/LaunchAgents/com.workmanagement.morning.plist
launchctl unload ~/Library/LaunchAgents/com.workmanagement.evening.plist
cp com.workmanagement.*.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.workmanagement.morning.plist
launchctl load ~/Library/LaunchAgents/com.workmanagement.evening.plist
```

---

## サポート

上記の方法で解決しない場合は、以下の情報を含めてIssueを作成してください:

- 発生した問題の詳細
- エラーメッセージの全文
- `jq --version`の出力
- `uname -a`の出力（OSバージョン）
- ログファイルの内容（該当する場合）
