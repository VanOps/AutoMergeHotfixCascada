#!/bin/bash
# create-hotfix-pr.sh - Create hotfix branch from release

set -e

echo "╔═══════════════════════════════════════╗"
echo "║    Create Hotfix Branch               ║"
echo "╚═══════════════════════════════════════╝"
echo ""

# Verificar que estamos en un repositorio git
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "❌ Not in a git repository"
    exit 1
fi

# Listar ramas release
echo "📋 Available release branches:"
RELEASE_BRANCHES=($(git branch -r | grep -E 'origin/release/[0-9]' | sed 's|origin/||' | sort -V))

if [ ${#RELEASE_BRANCHES[@]} -eq 0 ]; then
    echo "❌ No release branches found"
    echo "Run: ./scripts/setup-release-branches.sh"
    exit 1
fi

for i in "${!RELEASE_BRANCHES[@]}"; do
    echo "  $((i+1)). ${RELEASE_BRANCHES[$i]}"
done

echo ""
read -p "Select release branch (1-${#RELEASE_BRANCHES[@]}): " CHOICE

if ! [[ "$CHOICE" =~ ^[0-9]+$ ]] || [ "$CHOICE" -lt 1 ] || [ "$CHOICE" -gt ${#RELEASE_BRANCHES[@]} ]; then
    echo "❌ Invalid selection"
    exit 1
fi

BASE_BRANCH="${RELEASE_BRANCHES[$((CHOICE-1))]}"

# Solicitar nombre del hotfix
echo ""
read -p "Hotfix name (e.g., 'critical-bug', 'security-patch'): " HOTFIX_NAME

if [ -z "$HOTFIX_NAME" ]; then
    echo "❌ Name cannot be empty"
    exit 1
fi

HOTFIX_BRANCH="hotfix/$HOTFIX_NAME"

# Crear la rama
echo ""
echo "🔄 Creating branch $HOTFIX_BRANCH from $BASE_BRANCH..."
git fetch origin
git checkout -b "$HOTFIX_BRANCH" "origin/$BASE_BRANCH"

echo ""
echo "✅ Hotfix branch created!"
echo ""
echo "⚠️  CASCADE WARNING:"
echo "   When you merge PR to $BASE_BRANCH, it will cascade to:"

# Mostrar cascada
ALL_BRANCHES=($(git branch -r | grep -E 'origin/(release/[0-9]|develop)' | sed 's|origin/||' | sort -V))
FOUND=false
for branch in "${ALL_BRANCHES[@]}"; do
    if [ "$branch" == "$BASE_BRANCH" ]; then
        FOUND=true
    elif [ "$FOUND" == "true" ]; then
        echo "     → $branch"
    fi
done

# Crear pequeño cambio para evitar PR vacío
echo "Initial hotfix commit" > HOTFIX_NOTES.md
git add HOTFIX_NOTES.md
git commit -m "chore: Initialize hotfix branch $HOTFIX_BRANCH"
git push -u origin "$HOTFIX_BRANCH"

# Crear PR usando gh CLI
echo ""
echo "🚀 Creating PR..."
gh pr create --base "$BASE_BRANCH" --head "$HOTFIX_BRANCH" --title "Hotfix: $HOTFIX_NAME" --body "This PR introduces a hotfix: $HOTFIX_NAME"
echo ""
echo "✅ PR created successfully!"
echo "Remember to merge the PR to trigger the cascade process."
