#!/bin/bash
# check-repo-config.sh - Hotfix Cascade Auto-Merge Configuration Checker

REPO="$1"
if [ -z "$REPO" ]; then
  REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
fi

echo "╔═══════════════════════════════════════════════════╗"
echo "║  Hotfix Cascade Auto-Merge Configuration Report  ║"
echo "╚═══════════════════════════════════════════════════╝"
echo ""
echo "📁 Repository: $REPO"
echo ""

# Verificar si estamos en el directorio correcto
if [ ! -d ".github/workflows" ]; then
  echo "⚠️  WARNING: Not in repository root or .github/workflows not found"
  echo ""
fi

echo "🌿 Release Branches:"
REQUIRED_BRANCHES=("release/1.0" "release/1.1" "release/2.0" "develop")
MISSING_BRANCHES=0
for branch in "${REQUIRED_BRANCHES[@]}"; do
  if gh api repos/$REPO/branches/$branch >/dev/null 2>&1; then
    echo "  ✅ $branch exists"
  else
    echo "  ❌ $branch missing"
    MISSING_BRANCHES=$((MISSING_BRANCHES + 1))
  fi
done

echo ""
echo "📋 Workflow Files:"
WORKFLOW_FOUND=0
if [ -f ".github/workflows/cascade-merge.yml" ]; then
  echo "  ✅ cascade-merge.yml exists"
  WORKFLOW_FOUND=$((WORKFLOW_FOUND + 1))
else
  echo "  ❌ cascade-merge.yml missing"
fi

if [ -f ".github/workflows/setup-ci.yml" ]; then
  echo "  ✅ setup-ci.yml exists"
  WORKFLOW_FOUND=$((WORKFLOW_FOUND + 1))
else
  echo "  ⚠️  setup-ci.yml missing (optional but recommended)"
fi

echo ""
echo "🤖 GitHub Actions Permissions:"
ACTIONS_PERMS=$(gh api repos/$REPO/actions/permissions)
ACTIONS_ENABLED=$(echo "$ACTIONS_PERMS" | jq -r '.enabled')
CAN_APPROVE=$(echo "$ACTIONS_PERMS" | jq -r '.can_approve_pull_request_reviews')
DEFAULT_WORKFLOW_PERMS=$(echo "$ACTIONS_PERMS" | jq -r '.default_workflow_permissions')

# Detectar si los campos existen en la respuesta de la API
CAN_APPROVE_AVAILABLE=true
WORKFLOW_PERMS_AVAILABLE=true

if [ "$CAN_APPROVE" == "null" ] || [ -z "$CAN_APPROVE" ]; then
  CAN_APPROVE_AVAILABLE=false
  CAN_APPROVE="N/A"
fi

if [ "$DEFAULT_WORKFLOW_PERMS" == "null" ] || [ -z "$DEFAULT_WORKFLOW_PERMS" ]; then
  WORKFLOW_PERMS_AVAILABLE=false
  DEFAULT_WORKFLOW_PERMS="N/A"
fi

echo "  Actions enabled: $ACTIONS_ENABLED"
echo "  Default permissions: $DEFAULT_WORKFLOW_PERMS"
echo "  Can create and approve PRs: $CAN_APPROVE"

echo ""
echo "🔀 Merge Settings:"
REPO_INFO=$(gh api repos/$REPO)
ALLOW_MERGE_COMMIT=$(echo "$REPO_INFO" | jq -r '.allow_merge_commit')
ALLOW_SQUASH_MERGE=$(echo "$REPO_INFO" | jq -r '.allow_squash_merge')
ALLOW_REBASE_MERGE=$(echo "$REPO_INFO" | jq -r '.allow_rebase_merge')
DELETE_BRANCH=$(echo "$REPO_INFO" | jq -r '.delete_branch_on_merge')

echo "  Merge commit allowed: $ALLOW_MERGE_COMMIT"
echo "  Squash merge allowed: $ALLOW_SQUASH_MERGE"
echo "  Rebase merge allowed: $ALLOW_REBASE_MERGE"
echo "  Auto-delete head branches: $DELETE_BRANCH"

echo ""
echo "🔒 Branch Protection:"
for branch in "develop" "main"; do
  PROTECTION=$(gh api repos/$REPO/branches/$branch/protection 2>/dev/null)
  if [ $? -eq 0 ]; then
    REQUIRE_PR=$(echo "$PROTECTION" | jq -r '.required_pull_request_reviews != null')
    APPROVALS=$(echo "$PROTECTION" | jq -r '.required_pull_request_reviews.required_approving_review_count // 0')
    echo "  $branch:"
    echo "    Require PRs: $REQUIRE_PR"
    echo "    Required approvals: $APPROVALS"
  else
    echo "  $branch: No protection rules"
  fi
done

echo ""
echo "🔑 Repository Secrets:"
HAS_MERGE_TOKEN=false
if gh secret list -a actions 2>/dev/null | grep -q "MERGE_TOKEN"; then
  echo "  ✅ MERGE_TOKEN configured"
  HAS_MERGE_TOKEN=true
else
  echo "  ⚠️  MERGE_TOKEN not found (required only if using protected branches)"
fi

echo ""
echo "╔═══════════════════════════════════════════════════╗"
echo "║           Configuration Issues Found              ║"
echo "╚═══════════════════════════════════════════════════╝"
echo ""

# Check critical settings for Hotfix Cascade
ISSUES_FOUND=0

# 1. Verificar ramas requeridas
if [ $MISSING_BRANCHES -gt 0 ]; then
  echo "❌ CRITICAL: Missing $MISSING_BRANCHES required release branch(es)"
  echo "   Fix: Run ./scripts/setup-release-branches.sh to create missing branches"
  echo "   Or manually create: release/1.0, release/1.1, release/2.0, develop"
  ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi

# 2. Verificar workflow de cascada
if [ $WORKFLOW_FOUND -eq 0 ]; then
  echo "❌ CRITICAL: cascade-merge.yml workflow not found"
  echo "   Fix: Create .github/workflows/cascade-merge.yml"
  echo "   See: docs/HotfixCascada.md for complete workflow template"
  ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi

# 3. Verificar permisos de Actions
# Nota: can_approve_pull_request_reviews no siempre está disponible en la API
if [ "$CAN_APPROVE_AVAILABLE" == "false" ]; then
  echo "ℹ️  INFO: Cannot verify PR approval permissions via GitHub API"
  echo "   This is normal for some repository types"
  echo "   Please manually verify in GitHub Settings → Actions → General:"
  echo "   1. Workflow permissions: 'Read and write permissions' (should be selected)"
  echo "   2. Check: '☑ Allow GitHub Actions to create and approve pull requests'"
  echo ""
  echo "   The cascade workflow REQUIRES these settings to work properly"
elif [ "$CAN_APPROVE" == "true" ]; then
  # Todo bien, no hacer nada aquí
  :
elif [ "$CAN_APPROVE" == "false" ]; then
  echo "❌ CRITICAL: Actions cannot create and approve pull requests"
  echo "   Fix: Settings → Actions → General → Workflow permissions:"
  echo "   ✓ Read and write permissions"
  echo "   ✓ Allow GitHub Actions to create and approve pull requests"
  ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi

# 4. Verificar auto-delete branches (DEBE estar desactivado)
if [ "$DELETE_BRANCH" == "true" ]; then
  echo "❌ CRITICAL: Auto-delete head branches is enabled"
  echo "   Fix: Settings → General → Pull Requests:"
  echo "   ✗ UNCHECK 'Automatically delete head branches'"
  echo "   The cascade workflow needs source branches to remain for sequential merges"
  ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi

# 5. Verificar al menos un método de merge habilitado
if [ "$ALLOW_MERGE_COMMIT" != "true" ] && [ "$ALLOW_SQUASH_MERGE" != "true" ] && [ "$ALLOW_REBASE_MERGE" != "true" ]; then
  echo "❌ CRITICAL: No merge method is enabled"
  echo "   Fix: Settings → General → Pull Requests:"
  echo "   Enable at least one: Merge commits, Squash, or Rebase"
  ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi

# 6. Verificar Actions habilitado
if [ "$ACTIONS_ENABLED" != "true" ]; then
  echo "❌ CRITICAL: GitHub Actions is disabled"
  echo "   Fix: Settings → Actions → General:"
  echo "   ✓ Enable GitHub Actions for this repository"
  ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi

# 7. Advertencias (no críticas)
WARNINGS=0

# Verificar si hay branch protection y no hay MERGE_TOKEN
PROTECTED_BRANCHES=$(gh api repos/$REPO/branches 2>/dev/null | jq '[.[] | select(.protected == true)] | length' 2>/dev/null || echo 0)
if [ "$PROTECTED_BRANCHES" -gt 0 ] && [ "$HAS_MERGE_TOKEN" = false ]; then
  echo "⚠️  WARNING: Protected branches detected but MERGE_TOKEN not configured"
  echo "   Protected branches may block automatic cascade merges"
  echo "   Fix: Create a Personal Access Token with 'repo' scope and add as MERGE_TOKEN secret"
  echo "   See: docs/HotfixCascada.md - Section 'Crear Personal Access Token'"
  WARNINGS=$((WARNINGS + 1))
fi

# Verificar permisos de workflow
if [ "$WORKFLOW_PERMS_AVAILABLE" == "false" ]; then
  echo "ℹ️  INFO: Cannot determine default workflow permissions from GitHub API"
  echo "   Please verify manually: Settings → Actions → General → Workflow permissions"
  echo "   Should be set to: 'Read and write permissions' (not 'Read repository contents')"
elif [ "$DEFAULT_WORKFLOW_PERMS" == "write" ]; then
  # Todo bien, no hacer nada
  :
elif [ "$DEFAULT_WORKFLOW_PERMS" == "read" ]; then
  echo "⚠️  WARNING: Default workflow permissions is 'read'"
  echo "   Recommendation: Settings → Actions → General → Workflow permissions:"
  echo "   ✓ Select 'Read and write permissions'"
  WARNINGS=$((WARNINGS + 1))
fi

echo ""
if [ $ISSUES_FOUND -eq 0 ] && [ $WARNINGS -eq 0 ]; then
  echo "✅ All configurations are correct for Hotfix Cascade Auto-Merge!"
  echo ""
  echo "🚀 Next steps:"
  echo "   1. Create a hotfix branch from a release branch"
  echo "   2. Make your changes and push"
  echo "   3. Create a PR to the release branch"
  echo "   4. Merge the PR and watch the cascade happen automatically!"
elif [ $ISSUES_FOUND -eq 0 ]; then
  echo "✅ Critical configurations are correct!"
  echo "⚠️  Found $WARNINGS warning(s) - cascade will work but may have limitations"
else
  echo "❌ Found $ISSUES_FOUND critical issue(s) that will prevent cascade from working"
  if [ $WARNINGS -gt 0 ]; then
    echo "⚠️  Also found $WARNINGS warning(s)"
  fi
  echo ""
  echo "📚 See documentation for detailed setup:"
  echo "   - docs/HotfixCascada.md"
  echo "   - AutoMergeHotfixCascada/README.md"
fi

echo ""
echo "╔═══════════════════════════════════════════════════╗"
echo "║              Quick Reference                      ║"
echo "╚═══════════════════════════════════════════════════╝"
echo ""
echo "📖 How the cascade works:"
echo "   hotfix/xxx → release/1.0 → release/1.1 → release/2.0 → develop"
echo ""
echo "🔧 Required setup scripts:"
echo "   ./scripts/setup-release-branches.sh    - Create release branch structure"
echo "   ./scripts/create-hotfix-pr.sh          - Interactive hotfix branch creator"
echo "   ./scripts/check_repo_config.sh         - Run this health check"
echo ""