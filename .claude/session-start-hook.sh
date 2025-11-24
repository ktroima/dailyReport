#!/bin/bash
# セッション開始時にagent_instructionsを読み込むhook

# プロジェクトルートからの相対パス
INSTRUCTIONS_FILE=".vibe_kanban/rules/agent_instructions.md"

if [ -f "$INSTRUCTIONS_FILE" ]; then
    echo "📖 Agent Instructions を読み込んでいます..."
    echo ""
    echo "=========================================="
    echo "重要: 以下のルールを必ず遵守してください"
    echo "=========================================="
    echo ""
    echo "📄 ファイル: $INSTRUCTIONS_FILE"
    echo ""
    echo "【必須事項】"
    echo "✅ セッション終了時に必ずセッションドキュメントを作成"
    echo "   - テンプレート: docs/templates/session_template.md"
    echo "   - 保存先: docs/agent_sessions/YYYY-MM-DD_HHmm_task-name.md"
    echo "   - 形式: agent_instructions.md の指示に従う"
    echo ""
    echo "✅ 自己評価を正直かつ客観的に記録"
    echo "   - 未検証項目は明確に記載"
    echo "   - 過大評価を避ける"
    echo "   - 懸念点を正直に記録"
    echo ""
    echo "✅ コーディング規約を遵守"
    echo "   - Bash: snake_case関数, UPPER_CASE変数"
    echo "   - インデント: 2スペース"
    echo "   - エラーハンドリング必須"
    echo ""
    echo "=========================================="
    echo ""

    # Claudeに対してファイルの読み込みを促す
    echo "💡 このセッションの最初のタスクとして、以下のファイルを必ず読み込んでください："
    echo "   .vibe_kanban/rules/agent_instructions.md"
    echo ""

    exit 0
else
    echo "⚠️  Agent Instructions が見つかりません: $INSTRUCTIONS_FILE"
    exit 1
fi
