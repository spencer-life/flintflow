#!/usr/bin/env bash
# detect.sh — auto-detect external services for the current project.
# Outputs JSON to stdout. Used by the project-map skill.
#
# Usage: bash detect.sh [project_root]
#   project_root defaults to $(pwd) or the git root if cwd is inside a git repo.

set -euo pipefail

# --- Resolve project root ---
PROJECT_ROOT="${1:-}"
if [[ -z "$PROJECT_ROOT" ]]; then
	if PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null); then
		:
	else
		PROJECT_ROOT="$(pwd)"
	fi
fi
PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd)"

# --- Project name (basename of root) ---
PROJECT_NAME="$(basename "$PROJECT_ROOT")"

# --- GitHub detection ---
GITHUB_OWNER=""
GITHUB_REPO=""
GITHUB_URL=""
if cd "$PROJECT_ROOT" 2>/dev/null && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
	REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")
	# Handle both git@github.com:owner/repo.git and https://github.com/owner/repo(.git)
	if [[ "$REMOTE_URL" =~ github\.com[:/]([^/]+)/(.+) ]]; then
		GITHUB_OWNER="${BASH_REMATCH[1]}"
		GITHUB_REPO="${BASH_REMATCH[2]%.git}"
		GITHUB_URL="https://github.com/${GITHUB_OWNER}/${GITHUB_REPO}"
	fi
fi

# --- package.json ---
PKG_DESCRIPTION=""
PKG_NAME=""
HAS_DISCORD_DEP="false"
HAS_SUPABASE_DEP="false"
if [[ -f "$PROJECT_ROOT/package.json" ]] && command -v jq >/dev/null 2>&1; then
	PKG_NAME=$(jq -r '.name // ""' "$PROJECT_ROOT/package.json" 2>/dev/null || echo "")
	PKG_DESCRIPTION=$(jq -r '.description // ""' "$PROJECT_ROOT/package.json" 2>/dev/null || echo "")
	if jq -e '.dependencies // {} | to_entries[] | select(.key | test("^(discord\\.js|@discordjs/)"))' "$PROJECT_ROOT/package.json" >/dev/null 2>&1; then
		HAS_DISCORD_DEP="true"
	fi
	if jq -e '.dependencies // {} | to_entries[] | select(.key | test("^@supabase/"))' "$PROJECT_ROOT/package.json" >/dev/null 2>&1; then
		HAS_SUPABASE_DEP="true"
	fi
fi
[[ -n "$PKG_NAME" ]] && PROJECT_NAME="$PKG_NAME"

# --- Railway detection ---
HAS_RAILWAY="false"
if [[ -f "$PROJECT_ROOT/railway.json" ]] || [[ -f "$PROJECT_ROOT/railway.toml" ]]; then
	HAS_RAILWAY="true"
fi

# --- Netlify detection ---
HAS_NETLIFY="false"
if [[ -f "$PROJECT_ROOT/netlify.toml" ]]; then
	HAS_NETLIFY="true"
fi

# --- Cloudflare Workers detection ---
HAS_CLOUDFLARE="false"
if [[ -f "$PROJECT_ROOT/wrangler.jsonc" ]] || [[ -f "$PROJECT_ROOT/wrangler.json" ]] || [[ -f "$PROJECT_ROOT/wrangler.toml" ]]; then
	HAS_CLOUDFLARE="true"
fi

# --- Supabase detection ---
HAS_SUPABASE="false"
SUPABASE_PROJECT_ID=""
if [[ -d "$PROJECT_ROOT/supabase" ]] && [[ -f "$PROJECT_ROOT/supabase/config.toml" ]]; then
	HAS_SUPABASE="true"
	SUPABASE_PROJECT_ID=$(grep -E '^project_id\s*=' "$PROJECT_ROOT/supabase/config.toml" 2>/dev/null | head -1 | sed -E 's/^project_id\s*=\s*"?([^"]+)"?/\1/' || echo "")
fi
[[ "$HAS_SUPABASE_DEP" == "true" ]] && HAS_SUPABASE="true"

# --- Doppler detection ---
HAS_DOPPLER="false"
DOPPLER_PROJECT=""
DOPPLER_CONFIG=""
if [[ -f "$PROJECT_ROOT/doppler.yaml" ]] || [[ -f "$PROJECT_ROOT/.doppler.yaml" ]]; then
	HAS_DOPPLER="true"
	DOPPLER_FILE="$PROJECT_ROOT/doppler.yaml"
	[[ -f "$PROJECT_ROOT/.doppler.yaml" ]] && DOPPLER_FILE="$PROJECT_ROOT/.doppler.yaml"
	DOPPLER_PROJECT=$(grep -E '^\s*project:' "$DOPPLER_FILE" 2>/dev/null | head -1 | sed -E 's/^\s*project:\s*"?([^"]+)"?/\1/' || echo "")
	DOPPLER_CONFIG=$(grep -E '^\s*config:' "$DOPPLER_FILE" 2>/dev/null | head -1 | sed -E 's/^\s*config:\s*"?([^"]+)"?/\1/' || echo "")
fi

# --- Python deps (requirements.txt / pyproject.toml) ---
# Handles Spencer's Python projects (Insurance UW Bot, etc.) that don't have package.json.
for pyfile in "$PROJECT_ROOT/requirements.txt" "$PROJECT_ROOT/requirements-dev.txt" "$PROJECT_ROOT/pyproject.toml"; do
	if [[ -f "$pyfile" ]]; then
		if grep -qiE '^(discord(\.py)?|py-cord|nextcord|disnake)\b' "$pyfile" 2>/dev/null; then
			HAS_DISCORD_DEP="true"
		fi
		if grep -qiE '^supabase\b' "$pyfile" 2>/dev/null; then
			HAS_SUPABASE="true"
		fi
	fi
done

# --- .env.example signals (catches services not in deps, e.g. Supabase Postgres via DATABASE_URL) ---
for envfile in "$PROJECT_ROOT/.env.example" "$PROJECT_ROOT/.env.sample" "$PROJECT_ROOT/.env.template"; do
	if [[ -f "$envfile" ]]; then
		grep -qE '^SUPABASE_(URL|ANON_KEY|SERVICE_ROLE)' "$envfile" 2>/dev/null && HAS_SUPABASE="true"
		grep -qE '^DISCORD_(TOKEN|BOT_TOKEN|CLIENT_ID)' "$envfile" 2>/dev/null && HAS_DISCORD_DEP="true"
	fi
done

# --- Discord detection ---
HAS_DISCORD="false"
[[ "$HAS_DISCORD_DEP" == "true" ]] && HAS_DISCORD="true"

# --- README first paragraph ---
PURPOSE_DRAFT=""
for readme in "$PROJECT_ROOT/README.md" "$PROJECT_ROOT/readme.md" "$PROJECT_ROOT/README"; do
	if [[ -f "$readme" ]]; then
		# Grab first non-empty, non-heading paragraph
		PURPOSE_DRAFT=$(awk '
      /^#/ { next }
      /^[[:space:]]*$/ { if (found) exit; next }
      { found=1; print; }
    ' "$readme" | head -3 | tr '\n' ' ' | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//')
		break
	fi
done
[[ -z "$PURPOSE_DRAFT" && -n "$PKG_DESCRIPTION" ]] && PURPOSE_DRAFT="$PKG_DESCRIPTION"

# --- Service map cross-reference (existence check only) ---
# Lightweight presence check — actual ID extraction happens in the python block
# below, which has cleaner regex handling.
SERVICE_MAP="$HOME/.claude/projects/-home-mlpc--claude/memory/project_service_map.md"
IN_SERVICE_MAP="false"
if [[ -f "$SERVICE_MAP" ]] && [[ -n "$GITHUB_REPO" ]]; then
	if grep -qi "$GITHUB_REPO" "$SERVICE_MAP" 2>/dev/null; then
		IN_SERVICE_MAP="true"
	fi
fi

# --- Sub-project detection (multi-agency / monorepo) ---
# Scan known monorepo subdir names for child folders that look like their own
# deployable units. Strong signals: own package.json (different name), own deploy
# config (railway.toml, netlify.toml, wrangler.*, supabase/config.toml), own
# Dockerfile. A subdir flagged if at least one strong signal hits.
# Output is a colon-separated list; python below splits + structures it.
SUB_PROJECTS=""
SUB_PROJECT_DIRS=("apps" "packages" "services" "agencies" "bots" "sites")
for parent in "${SUB_PROJECT_DIRS[@]}"; do
	[[ -d "$PROJECT_ROOT/$parent" ]] || continue
	for sub in "$PROJECT_ROOT/$parent"/*/; do
		[[ -d "$sub" ]] || continue
		sub_name=$(basename "$sub")
		# Skip hidden / dotfile directories
		[[ "$sub_name" == .* ]] && continue
		# Strong-signal check
		strong=0
		if [[ -f "$sub/package.json" ]]; then
			# Different name from root package.json (or root has none) → strong
			if [[ -f "$PROJECT_ROOT/package.json" ]] && command -v jq >/dev/null 2>&1; then
				root_name=$(jq -r '.name // ""' "$PROJECT_ROOT/package.json" 2>/dev/null || echo "")
				sub_pkg_name=$(jq -r '.name // ""' "$sub/package.json" 2>/dev/null || echo "")
				[[ -n "$sub_pkg_name" && "$sub_pkg_name" != "$root_name" ]] && strong=1
			else
				strong=1
			fi
		fi
		[[ -f "$sub/railway.toml" || -f "$sub/railway.json" ]] && strong=1
		[[ -f "$sub/netlify.toml" ]] && strong=1
		[[ -f "$sub/wrangler.toml" || -f "$sub/wrangler.json" || -f "$sub/wrangler.jsonc" ]] && strong=1
		[[ -f "$sub/supabase/config.toml" ]] && strong=1
		[[ -f "$sub/Dockerfile" ]] && strong=1
		if [[ $strong -eq 1 ]]; then
			# Format: parent/sub_name (so caller knows the relative path)
			SUB_PROJECTS="${SUB_PROJECTS}${SUB_PROJECTS:+:}${parent}/${sub_name}"
		fi
	done
done

# --- Emit JSON via python (cleaner than building bash JSON) ---
python3 <<PYEOF
import json
import os
import re

def nz(s):
    """Return None if string is empty, else the string."""
    s = (s or "").strip()
    return s if s else None

project_root = os.environ.get("PR", "$PROJECT_ROOT")
project_name = "$PROJECT_NAME"
github_owner = nz("$GITHUB_OWNER")
github_repo = nz("$GITHUB_REPO")
github_url = nz("$GITHUB_URL")
purpose_draft = nz("""$PURPOSE_DRAFT""")
in_service_map = "$IN_SERVICE_MAP" == "true"

# Service-map lookup (lightweight — parse only if we found a hit)
sm_railway_id = None
sm_railway_name = None
sm_supabase_ref = None
sm_supabase_region = None
sm_netlify_site = None
sm_netlify_url = None
sm_discord_bot_id = None

service_map_path = os.path.expanduser("~/.claude/projects/-home-mlpc--claude/memory/project_service_map.md")
if in_service_map and github_repo and os.path.isfile(service_map_path):
    try:
        with open(service_map_path) as f:
            content = f.read()
        # Find lines mentioning the repo (any case)
        for line in content.splitlines():
            if github_repo.lower() not in line.lower():
                continue
            # Heuristic: extract Supabase ref (20-char alphanumeric)
            if not sm_supabase_ref:
                m = re.search(r"\b([a-z0-9]{20})\b", line)
                if m:
                    sm_supabase_ref = m.group(1)
            # Heuristic: extract Railway project UUID (8-4-4-4-12)
            if not sm_railway_id:
                m = re.search(r"\b([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})\b", line)
                if m:
                    sm_railway_id = m.group(1)
            # Heuristic: extract netlify subdomain (xxx.netlify.app)
            if not sm_netlify_url:
                m = re.search(r"https?://([\w-]+\.netlify\.app)", line)
                if m:
                    sm_netlify_url = "https://" + m.group(1)
                    sm_netlify_site = m.group(1).split(".")[0]
    except Exception:
        pass

# Build per-service blocks (None if not detected)
github = None
if github_owner and github_repo:
    github = {
        "owner": github_owner,
        "repo": github_repo,
        "url": github_url,
    }

railway = None
if "$HAS_RAILWAY" == "true":
    railway = {
        "name": project_name,
        "id": sm_railway_id,
        "dashboard": f"https://railway.com/project/{sm_railway_id}" if sm_railway_id else "https://railway.com/dashboard",
    }

supabase = None
if "$HAS_SUPABASE" == "true":
    ref = sm_supabase_ref or nz("$SUPABASE_PROJECT_ID")
    supabase = {
        "ref": ref,
        "region": sm_supabase_region,
        "dashboard": f"https://supabase.com/dashboard/project/{ref}" if ref else "https://supabase.com/dashboard",
    }

netlify = None
if "$HAS_NETLIFY" == "true":
    netlify = {
        "site": sm_netlify_site or project_name,
        "url": sm_netlify_url,
        "dashboard": f"https://app.netlify.com/sites/{sm_netlify_site or project_name}",
    }

cloudflare = None
if "$HAS_CLOUDFLARE" == "true":
    cloudflare = {
        "name": project_name,
        "dashboard": "https://dash.cloudflare.com",
    }

doppler = None
if "$HAS_DOPPLER" == "true":
    doppler = {
        "project": nz("$DOPPLER_PROJECT") or project_name,
        "config": nz("$DOPPLER_CONFIG"),
        "dashboard": "https://dashboard.doppler.com",
    }

discord = None
if "$HAS_DISCORD" == "true":
    discord = {
        "detected": True,
        "bot_id": sm_discord_bot_id,
        "dashboard": f"https://discord.com/developers/applications/{sm_discord_bot_id}" if sm_discord_bot_id else "https://discord.com/developers/applications",
    }

# Sub-projects: bash emits "parent/name:parent/name:..." or empty.
# Convert to a list of {"path": "agencies/execute-financial", "name": "execute-financial"}.
sub_projects_raw = "$SUB_PROJECTS"
sub_projects = None
if sub_projects_raw:
    sub_projects = [
        {"path": item, "name": item.split("/", 1)[1] if "/" in item else item}
        for item in sub_projects_raw.split(":") if item
    ]

out = {
    "project_name": project_name,
    "project_root": project_root,
    "github": github,
    "railway": railway,
    "supabase": supabase,
    "netlify": netlify,
    "cloudflare": cloudflare,
    "doppler": doppler,
    "discord": discord,
    "purpose_draft": purpose_draft,
    "in_service_map": in_service_map,
    "sub_projects": sub_projects,
}

print(json.dumps(out, indent=2))
PYEOF
