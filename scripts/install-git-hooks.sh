#!/usr/bin/env bash
set -e

# Install git hooks for automatic deployment
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
HOOKS_DIR="$REPO_DIR/.git/hooks"

echo "[Install] Installing git hooks for automatic deployment..."

# Create post-commit hook that triggers deployment
cat > "$HOOKS_DIR/post-commit" << 'EOF'
#!/usr/bin/env bash
# Post-commit hook that triggers automatic deployment

echo "[Git Hook] Commit detected, checking if we should deploy..."

# Only deploy on main branch
current_branch=$(git branch --show-current)
if [ "$current_branch" != "main" ]; then
    echo "[Git Hook] Not on main branch ($current_branch), skipping deployment"
    exit 0
fi

# Check if we're in a clean state (no uncommitted changes)
if ! git diff-index --quiet HEAD --; then
    echo "[Git Hook] Working directory has uncommitted changes, skipping deployment"
    exit 0
fi

echo "[Git Hook] Triggering automatic deployment..."

# Run deployment in background to avoid blocking the commit
nohup bash -c "
    cd '$PWD'
    echo '[Deploy] Starting deployment from git hook...'
    if command -v deploy-all >/dev/null 2>&1; then
        deploy-all
    elif [ -f './scripts/deploy-dynamic.sh' ]; then
        ./scripts/deploy-dynamic.sh
    else
        echo '[Deploy] No deployment script found!'
        exit 1
    fi
" > /tmp/git-deploy.log 2>&1 &

echo "[Git Hook] Deployment started in background (check /tmp/git-deploy.log for status)"
EOF

# Make the hook executable
chmod +x "$HOOKS_DIR/post-commit"

# Create a pre-push hook that can be used as an alternative
cat > "$HOOKS_DIR/pre-push" << 'EOF'
#!/usr/bin/env bash
# Pre-push hook that can trigger deployment before pushing to remote

echo "[Git Hook] About to push to remote..."

# Check if we want to deploy before pushing
if [ "${DEPLOY_BEFORE_PUSH:-}" = "1" ]; then
    echo "[Git Hook] DEPLOY_BEFORE_PUSH is set, running deployment..."
    
    if command -v deploy-all >/dev/null 2>&1; then
        deploy-all
    elif [ -f './scripts/deploy-dynamic.sh' ]; then
        ./scripts/deploy-dynamic.sh
    else
        echo '[Deploy] No deployment script found!'
        exit 1
    fi
    
    echo "[Git Hook] Deployment completed, continuing with push..."
fi
EOF

chmod +x "$HOOKS_DIR/pre-push"

# Create a manual deployment trigger script
cat > "$REPO_DIR/deploy.sh" << 'EOF'
#!/usr/bin/env bash
# Manual deployment trigger script

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "[Manual Deploy] Starting manual deployment..."

if command -v deploy-all >/dev/null 2>&1; then
    deploy-all "$@"
elif [ -f './scripts/deploy-dynamic.sh' ]; then
    ./scripts/deploy-dynamic.sh "$@"
else
    echo '[Deploy] No deployment script found!'
    echo '[Deploy] Available options:'
    echo '[Deploy]   1. Install deploy-all: nix profile install .#deploy-script'
    echo '[Deploy]   2. Run directly: ./scripts/deploy-dynamic.sh'
    exit 1
fi
EOF

chmod +x "$REPO_DIR/deploy.sh"

echo "[Install] Git hooks installed successfully!"
echo "[Install] Available deployment methods:"
echo "[Install]   1. Automatic on commit (main branch): Enabled via post-commit hook"
echo "[Install]   2. Before push: Set DEPLOY_BEFORE_PUSH=1 before git push"
echo "[Install]   3. Manual: Run ./deploy.sh"
echo "[Install]"
echo "[Install] To install the deploy-all command globally:"
echo "[Install]   nix profile install .#deploy-script"
echo "[Install]"
echo "[Install] Log file for background deployments: /tmp/git-deploy.log"