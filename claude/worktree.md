# Worktree 運用方針（Claude 向け）

## 採用基準

以下の場合のみ worktree を使う。日常的なブランチ作業は素の checkout で十分。

- PoC / 検証作業（マージされるか未確定）
- 未マージ上流 PR への依存作業
- 複数ブランチを並行で触る必要がある作業
- ビルド成果物 / 依存ファイルの分離が必要な作業

## 配置規約

worktree はメインリポジトリ内 `.worktrees/{branch-alias}/` に置く。

- ghq list を汚さない（ghq 管理対象は main repo のみ）
- 関連作業が main repo と物理的に co-located
- main repo を消せば worktree も消える（cleanup が単純）

`.worktrees/.gitignore` に `*` を入れて配下を全て ignore する。これで main repo 側の `git status` には何も漏れない。

## 標準手順

### 作成

```bash
# main repo 内で実行
git fetch origin

# .worktrees/ が無ければ作成 + .gitignore 配置（初回のみ）
[ -d .worktrees ] || { mkdir .worktrees && echo '*' > .worktrees/.gitignore; }

# worktree を作成
git worktree add -b {branch-name} \
  .worktrees/{branch-alias} \
  origin/{base-branch}

cd .worktrees/{branch-alias}
```

### 一覧 / 現在地確認

```bash
git worktree list
pwd  # main repo 内か worktree 内かを必ず確認
```

statusline 末尾に `⎇` が出ていれば worktree 内。

### 削除

```bash
# main repo から実行
git worktree remove .worktrees/{branch-alias}
git branch -D {branch-name}

# push 済みの場合のみ
git push origin --delete {branch-name}
```

## ブランチ命名

- PoC: `poc/{feature-name}`
- 実験/調査: `experiment/{topic}` or `spike/{topic}`
- 上流依存: `wip/{feature-name}`

worktree のディレクトリ名 `{branch-alias}` はブランチ名のスラッシュをハイフンに置換（例: `poc/foo` → `poc-foo`）。

## 上流追従（rebase / cherry-pick 方式）

merge せず PoC コミットを range で載せ替える。

1. PoC コミット range を記録（base hash + コミット数）
2. 上流更新時:
   - `git fetch origin`
   - 統合ブランチを新しい上流から作り直す
   - 記録した range を `cherry-pick` で再適用
3. 競合は手動解決

## Claude 運用上の注意

- worktree 作成前に `.worktrees/.gitignore` の存在を確認し、無ければ作成
- `.venv` / `node_modules` は worktree ごとに作り直す
- 同一ブランチを複数 worktree で同時 checkout は不可（git の制約）
- 作業前に `pwd` と statusline で main repo / worktree のどちらにいるかを確認
