#!/usr/bin/env bash
set -u
cd "$(dirname "$0")/.."

FAILS=0
fail() { echo "FAIL: $*"; FAILS=$((FAILS + 1)); }

require_file() { [ -f "$1" ] || fail "arquivo ausente: $1"; }

require_text() {
  local file=$1; shift
  [ -f "$file" ] || return
  for needle in "$@"; do
    grep -qF -- "$needle" "$file" || fail "$file não contém: $needle"
  done
}

forbid_regex() {
  local regex=$1; shift
  for file in "$@"; do
    [ -f "$file" ] || continue
    if grep -nE -- "$regex" "$file" >/dev/null; then
      fail "$file contém padrão proibido /$regex/: $(grep -nE -- "$regex" "$file" | head -3 | tr '\n' ' ')"
    fi
  done
}

max_lines() {
  local limit=$1 file=$2
  [ -f "$file" ] || return
  local n; n=$(wc -l < "$file" | tr -d ' ')
  [ "$n" -le "$limit" ] || fail "$file tem $n linhas (máx $limit)"
}

check_skill() {
  local name=$1; shift
  local dir=$name
  local skill="$dir/SKILL.md"
  require_file "$skill"
  [ -f "$skill" ] || return
  head -1 "$skill" | grep -qx -- '---' || fail "$skill sem frontmatter"
  grep -qx "name: $name" "$skill" || fail "$skill: frontmatter name != $name"
  grep -q '^description:' "$skill" || fail "$skill sem description"
  max_lines 200 "$skill"

  for ref in "$@"; do
    require_file "$dir/references/$ref"
    grep -qF "references/$ref" "$skill" || fail "$skill não referencia references/$ref"
    max_lines 450 "$dir/references/$ref"
  done

  local all=("$skill")
  for ref in "$@"; do all+=("$dir/references/$ref"); done

  forbid_regex '(NestJS|Next\.js|TypeScript|Tailwind( CSS)?|React|TypeORM|PostgreSQL|Node(\.js)?) v?[0-9]+(\.[0-9]+)*\+?([^0-9./-]|\.([^0-9]|$)|$)' "${all[@]}"
  forbid_regex ':[[:space:]]*any([^a-zA-Z]|$)|<any>|as any' "${all[@]}"
  forbid_regex 'deletedAt: null|claude skill install|is required'"'" "${all[@]}"
}

check_backend() {
  check_skill going2-backend patterns.md database.md security.md
  local d=going2-backend
  require_text "$d/SKILL.md" "ParseUUIDPipe" "PoliciesGuard" "EntityBase" "pnpm audit" "coverageThreshold" "80%" "Checklist"
  require_text "$d/references/patterns.md" "extends EntityBase" "ResponseDto" "@ApiOkResponse({ type:" "ParseUUIDPipe" "forbidNonWhitelisted" "helmet()" "createTestingModule" "getRepositoryToken" "coverageThreshold" "NotFoundException"
  require_text "$d/references/database.md" "@Index()" "\"deleted_at\" IS NULL" "timestamptz" "eager" "synchronize: false" "dataSource.transaction" "take" "leftJoinAndSelect"
  require_text "$d/references/security.md" "IDOR" "forbidNonWhitelisted" "select: false" "argon2" "ThrottlerGuard" "helmet" "CORS" "@Public()" "SSRF"
}

check_frontend() {
  check_skill going2-frontend patterns.md ui-guidelines.md performance.md security.md
  local d=going2-frontend
  require_text "$d/SKILL.md" "'use client'" "src/gen" "nuqs" "data-testid" "cn()" "sonner" "pnpm audit" "coverageThreshold" "80%" "Checklist"
  require_text "$d/references/patterns.md" "useQueryState" "NuqsAdapter" "parseAsInteger" "orval.config.ts" "tags-split" "zodResolver" "toast.loading" "vitest" "cypress" "coverageThreshold"
  require_text "$d/references/ui-guidelines.md" "aria-label" "AlertDialog" "Intl" "pt-BR" "prefers-reduced-motion" "autocomplete"
  require_text "$d/references/performance.md" "optimizePackageImports" "next/dynamic" "Promise.all" "useEffect"
  require_text "$d/references/security.md" "NEXT_PUBLIC_" "dangerouslySetInnerHTML" "callbackUrl" "localStorage" "Content-Security-Policy" "pnpm audit"
}

check_evals() {
  for name in going2-backend going2-frontend; do
    local f="evals/$name.json"
    require_file "$f"
    [ -f "$f" ] || continue
    local count
    count=$(python3 -I -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d["skill_name"]==sys.argv[2]; print(len(d["evals"]))' "$f" "$name" 2>/dev/null) \
      || { fail "$f inválido ou skill_name errado"; continue; }
    [ "$count" -ge 4 ] || fail "$f tem $count evals (mín 4)"
  done
}

check_repo() {
  for p in company-standards nestjs-standards nextjs-standards \
           .claude/skills/company-standards .claude/skills/nestjs-standards \
           .claude/skills/nextjs-standards .claude/skills/skill-creator; do
    [ -e "$p" ] || [ -L "$p" ] && fail "ainda existe: $p"
  done
  ls ./*.skill >/dev/null 2>&1 && fail "ainda existem arquivos .skill"
  require_file NOTICE.md
  require_text README.md "going2-backend" "going2-frontend" "npx skills add Going2Custom/skills-ia/going2-backend" "npx skills add Going2Custom/skills-ia/going2-frontend"
  require_text NOTICE.md "anthropics/skills" "vercel-labs/agent-skills" "vercel-labs/web-interface-guidelines" "kadajett/agent-nestjs-skills" "planetscale/database-skills" "getsentry/skills" "cloudflare/security-audit-skill" "CC BY-SA 4.0"
  forbid_regex 'claude skill install' README.md
}

target=${1:-all}
case $target in
  backend) check_backend ;;
  frontend) check_frontend ;;
  evals) check_evals ;;
  repo) check_repo ;;
  all) check_backend; check_frontend; check_evals; check_repo ;;
  *) echo "uso: $0 [backend|frontend|evals|repo|all]"; exit 2 ;;
esac

if [ "$FAILS" -gt 0 ]; then
  echo "$FAILS falha(s)"
  exit 1
fi
echo "OK $target"
