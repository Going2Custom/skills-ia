# Going2 Skills Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Substituir `company-standards`, `nestjs-standards` e `nextjs-standards` por duas skills enxutas, `going2-backend` e `going2-frontend`, conforme `docs/superpowers/specs/2026-11-18-going2-skills-design.md`.

**Architecture:** Cada skill tem um `SKILL.md` curto (sempre carregado) e `references/*.md` por tema (carregados sob demanda). Não há código executável: o "teste" é um script de verificação (`scripts/check-skills.sh`) que valida estrutura, palavras-chave obrigatórias e padrões proibidos. Ele é escrito primeiro e falha; cada tarefa faz uma parte dele passar.

**Tech Stack:** Markdown, bash (macOS/BSD-compatível), JSON. Conteúdo descreve NestJS + TypeORM + Postgres e Next.js App Router + shadcn + TanStack Query + Orval + nuqs.

## Global Constraints

- **Spec é a fonte da verdade:** cada tarefa lista as seções do spec que deve cobrir; todo item dessas seções precisa aparecer no arquivo.
- **Idioma:** prosa das skills em português; código, nomes de arquivos e identificadores em inglês; mensagens de validação/exceção/toast em português.
- **Nunca fixar versão de lib** no texto (proibido "NestJS 11", "Next.js 16+", "Tailwind 4+", "TypeScript 5+" etc.).
- **Nada copiado literalmente** das fontes externas; reescrever com nossas palavras. Fontes clonadas para consulta em `/private/tmp/claude-501/-Users-cadu-going2-interno-skills-ia/bc5b7745-85c5-4955-bbe6-4deb631fc184/scratchpad/sources/` (se não existirem mais, reclonar: `anthropics/skills`, `vercel-labs/agent-skills`, `vercel-labs/web-interface-guidelines`, `kadajett/agent-nestjs-skills`, `planetscale/database-skills`, `getsentry/skills`, `cloudflare/security-audit-skill`).
- **APIs de lib conferidas na documentação atual** (context7 MCP: `resolve-library-id` + `query-docs`) antes de escrever exemplos de Orval, nuqs, NextAuth, TypeORM, @nestjs/throttler e Vitest/Jest coverage.
- **Tamanho:** cada `SKILL.md` ≤ 200 linhas; cada `references/*.md` ≤ 450 linhas.
- **Exemplos de código:** nunca `any`; sem comentários que expliquem o "o quê"; nomes genéricos `Feature`/`feature`.
- **Testes:** cobertura mínima de 80% em linhas e branches (`coverageThreshold`).
- **Versões:** última estável; `pnpm audit` com zero vulnerabilidades de qualquer severidade; lockfile commitado; projeto existente mantém as versões do `package.json`.
- **Commits** terminam com `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Trabalho no branch `feat/going2-skills`.

---

## File Structure

| Arquivo | Responsabilidade |
|---|---|
| `scripts/check-skills.sh` | Verificação automática de estrutura e conteúdo |
| `going2-backend/SKILL.md` | Stack, como aplicar, nomenclatura, regras críticas, versões, testes, segurança (1 linha/regra), checklist |
| `going2-backend/references/patterns.md` | Templates Nest (entity, DTOs, response DTO, controller, service, module), `main.ts`, config, testes |
| `going2-backend/references/database.md` | TypeORM + Postgres |
| `going2-backend/references/security.md` | 14 regras com exemplo certo/errado |
| `going2-frontend/SKILL.md` | Idem, frontend |
| `going2-frontend/references/patterns.md` | Componente, page, form, Orval, nuqs, testes |
| `going2-frontend/references/ui-guidelines.md` | Acessibilidade, formulários, estados, textos |
| `going2-frontend/references/performance.md` | Regras React/Next aplicáveis |
| `going2-frontend/references/security.md` | 8 regras com exemplo certo/errado |
| `evals/going2-backend.json`, `evals/going2-frontend.json` | Casos de avaliação |
| `README.md`, `NOTICE.md` | Instalação/migração e atribuições |

Removidos: `company-standards/`, `nestjs-standards/`, `nextjs-standards/`, `*.skill`, `.claude/skills/company-standards/`, `.claude/skills/nestjs-standards/`, `.claude/skills/nextjs-standards/`, `.claude/skills/skill-creator` (symlink).

---

### Task 1: Script de verificação

**Files:**
- Create: `scripts/check-skills.sh`

**Interfaces:**
- Produces: `bash scripts/check-skills.sh [backend|frontend|evals|repo|all]` — imprime `FAIL: <motivo>` por problema e sai com código 1 se houver falha; imprime `OK <grupo>` e sai 0 se tudo passar. Default `all`.

- [ ] **Step 1: Escrever o script**

```bash
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

  forbid_regex '(NestJS|Next\.js|TypeScript|Tailwind( CSS)?|React|TypeORM|PostgreSQL|Node(\.js)?) v?[0-9]+(\.[0-9]+)*\+?([^0-9./-]|$)' "${all[@]}"
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
```

Nota sobre o padrão de versão: ele deve pegar `NestJS 11`, `Next.js 16+`, `TypeScript 5+`, mas **não** `@nestjs/...` nem caminhos. Se gerar falso positivo em texto legítimo, ajustar a regex (não o texto) e registrar no commit.

- [ ] **Step 2: Rodar e confirmar que falha**

Run: `chmod +x scripts/check-skills.sh && bash scripts/check-skills.sh`
Expected: várias linhas `FAIL: arquivo ausente: going2-backend/SKILL.md` etc., e saída com código 1.

- [ ] **Step 3: Sanidade da regex de versão**

Run:
```bash
T=$(mktemp -d); printf 'NestJS 11+ / TypeScript 5+\n' > "$T/v.md"; grep -cE '(NestJS|Next\.js|TypeScript|Tailwind( CSS)?|React|TypeORM|PostgreSQL|Node(\.js)?) v?[0-9]+(\.[0-9]+)*\+?([^0-9./-]|$)' "$T/v.md"
printf 'import { X } from "@nestjs/common";\nNext.js App Router\n' > "$T/v2.md"; grep -cE '(NestJS|Next\.js|TypeScript|Tailwind( CSS)?|React|TypeORM|PostgreSQL|Node(\.js)?) v?[0-9]+(\.[0-9]+)*\+?([^0-9./-]|$)' "$T/v2.md"
```
Expected: `1` e depois `0`.

- [ ] **Step 4: Commit**

```bash
git add scripts/check-skills.sh
git commit -m "chore: add skills verification script

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: going2-backend — SKILL.md e patterns.md

**Files:**
- Create: `going2-backend/SKILL.md`
- Create: `going2-backend/references/patterns.md`
- Consultar: `nestjs-standards/references/nestjs.md`, `company-standards/references/standards.md` (conteúdo atual a preservar); spec seções 2 e 3.

**Interfaces:**
- Consumes: `scripts/check-skills.sh backend` (Task 1).
- Produces: nomes usados por Tasks 3 e 6 — `FeatureEntity`, `CreateFeatureDto`, `UpdateFeatureDto`, `FeatureResponseDto` (arquivo `dto/feature-response.dto.ts`), `FeatureService`, `FeatureController`, `FeatureModule`, método estático `FeatureResponseDto.fromEntity(entity: FeatureEntity): FeatureResponseDto`.

- [ ] **Step 1: Confirmar APIs atuais**

Via context7, conferir: `ValidationPipe` options e `ParseUUIDPipe` (NestJS), `ConfigModule.forRoot({ validate })`, `@nestjs/throttler` (`ThrottlerModule.forRoot`, `@Throttle`), `helmet` com Nest, `jest` `coverageThreshold`. Anotar qualquer mudança de API em relação ao exemplo abaixo e usar a forma atual.

- [ ] **Step 2: Escrever `going2-backend/SKILL.md`**

Frontmatter exato:

```markdown
---
name: going2-backend
description: >
  Padrões de backend da Going2 para NestJS + TypeORM + PostgreSQL. Use sempre que for criar,
  revisar ou refatorar código de backend: módulo, entity, DTO, service, controller, migration,
  guard, autenticação, autorização, validação, Swagger ou testes. Aplique mesmo quando o usuário
  não pedir "seguir padrões" — consistência e segurança mínima são obrigatórias.
---
```

Seções, nesta ordem (conteúdo = spec §2 e §3 "SKILL.md", sem omitir itens):
1. `# Going2 — Backend` + 1 parágrafo de propósito.
2. `## Stack` — tabela sem versões.
3. `## Como aplicar` — passos: identificar artefato → ler a referência certa (`references/patterns.md`, `references/database.md`, `references/security.md`, com 1 linha dizendo quando abrir cada) → gerar módulo completo (entity, create/update/response DTOs, service, controller, module, `*.spec.ts`) → rodar o Checklist.
4. `## Nomenclatura` e `## Estrutura de pastas` — preservar tabela e árvore atuais de `nestjs-standards/SKILL.md`, acrescentando `dto/[feature]-response.dto.ts` e `[feature].service.spec.ts`, `[feature].controller.spec.ts`.
5. `## Regras críticas` — atuais + spec §3 (ParseUUIDPipe, mensagens PT sem interpolar input, sem promise solta, sem estado de request em singleton, response DTO, migrations sempre).
6. `## Versões de dependências` — spec §2 "Versões", literal.
7. `## Testes` — spec §2 "Testes" + o que cada service/rota deve cobrir (caminho feliz, not found, permissão negada; e2e nas rotas novas).
8. `## Segurança mínima` — as 14 regras do spec §3, uma linha cada, apontando para `references/security.md`.
9. `## Checklist de auto-revisão` — 10 itens `- [ ]`, cobrindo: guard/CASL em toda rota; checagem de dono; DTO sem campos privilegiados; sem `${}` em SQL; response DTO sem campos sensíveis; índices em FK e unique parcial; testes + cobertura ≥ 80%; `pnpm audit` limpo; segredos fora do código; logs/erros sem PII ou stack. Após a lista, parágrafo: "Classifique cada problema como **falha** (entrada controlada por atacante + impacto concreto — corrigir antes de entregar) ou **nota de hardening** (falta de defesa em profundidade — mencionar ao usuário, sem bloquear)."

- [ ] **Step 3: Escrever `going2-backend/references/patterns.md`**

Seções e exemplos obrigatórios:

`## Entity`
```typescript
import { EntityBase } from '@/common/entity/entity-base';
import { Column, Entity, Index, JoinColumn, ManyToOne } from 'typeorm';
import { UserEntity } from '@/users/user.entity';

@Entity('features')
@Index(['name'], { unique: true, where: '"deleted_at" IS NULL' })
export class FeatureEntity extends EntityBase {
  @Column({ length: 255 })
  name: string;

  @Column({ name: 'is_active', default: true })
  isActive: boolean;

  @Index()
  @Column({ name: 'owner_id', type: 'uuid' })
  ownerId: string;

  @ManyToOne(() => UserEntity)
  @JoinColumn({ name: 'owner_id' })
  owner: UserEntity;
}
```
+ regras em bullets (EntityBase, snake_case, soft delete, índice em FK → ver `database.md`).

`## DTOs` — `CreateFeatureDto` e `UpdateFeatureDto` com `@ApiProperty`/`@ApiPropertyOptional` e mensagens em português (`'O nome é obrigatório'`, `'O nome deve ser um texto'`); `UpdateFeatureDto extends PartialType(CreateFeatureDto)` de `@nestjs/swagger`. Nota: `ownerId`, `role`, `isAdmin` nunca entram no DTO de entrada.

`## Response DTO`
```typescript
import { ApiProperty } from '@nestjs/swagger';
import { FeatureEntity } from '../feature.entity';

export class FeatureResponseDto {
  @ApiProperty()
  id: string;

  @ApiProperty()
  name: string;

  @ApiProperty()
  isActive: boolean;

  @ApiProperty()
  createdAt: Date;

  static fromEntity(entity: FeatureEntity): FeatureResponseDto {
    const dto = new FeatureResponseDto();
    dto.id = entity.id;
    dto.name = entity.name;
    dto.isActive = entity.isActive;
    dto.createdAt = entity.createdAt;
    return dto;
  }
}
```
+ DTO de resposta paginada `FeaturePageResponseDto` com `data: FeatureResponseDto[]` e `meta: { page, perPage, total }` (classe `PageMetaDto` com `@ApiProperty`).

`## Controller` — `@UseGuards(PoliciesGuard)`, `@ApiBearerAuth()`, `@ApiTags('features')`, `@Controller('features')`; cada rota com `@ApiOperation` (summary em PT), `@ApiOkResponse({ type: FeatureResponseDto })` (ou `[...]`/page DTO), `@Param('id', ParseUUIDPipe) id: string`, `@CurrentUser() user` passado ao service para checagem de dono; retorna `FeatureResponseDto.fromEntity(...)`. Manter a forma de declarar políticas que já existe no boilerplate (`@CheckPolicies(...)`) — se o padrão atual não estiver no repositório, usar `@CheckPolicies((ability) => ability.can(Action.Read, FeatureEntity))` e marcar com uma nota "ajuste ao decorator do boilerplate".

`## Service` — `@InjectRepository(FeatureEntity)`; `findAll(user, page, perPage)` com `findAndCount`, `take: Math.min(perPage, 100)`, `order: { createdAt: 'DESC', id: 'ASC' }`, filtrando por `ownerId: user.id`; `findOne(id, user)` com `where: { id, ownerId: user.id }` → `NotFoundException('Registro não encontrado')`; `create`, `update`, `remove` via `softDelete`. Sem `deletedAt` no where.

`## Module` — igual ao atual.

`## main.ts`
```typescript
const app = await NestFactory.create(AppModule);
app.use(helmet());
app.enableCors({ origin: config.getOrThrow<string>('CORS_ORIGINS').split(','), credentials: true });
app.useGlobalPipes(
  new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true }),
);
if (config.get<string>('NODE_ENV') !== 'production') {
  SwaggerModule.setup('docs', app, SwaggerModule.createDocument(app, swaggerConfig));
}
```
(completar com imports e `config = app.get(ConfigService)`.) Nota: não usar `enableImplicitConversion`; em query DTOs usar `@Type(() => Number)`.

`## Configuração` — `ConfigModule.forRoot({ isGlobal: true, validate })` com validação que falha no boot se `JWT_SECRET` faltar ou tiver < 32 caracteres; lista de variáveis de ambiente atual + `CORS_ORIGINS`.

`## Testes` — `feature.service.spec.ts` completo com `Test.createTestingModule`, `{ provide: getRepositoryToken(FeatureEntity), useValue: repositoryMock }` tipado como `jest.Mocked<Pick<Repository<FeatureEntity>, 'findOne' | 'findAndCount' | 'create' | 'save' | 'softDelete'>>`, e três `it`: retorna o registro do dono; lança `NotFoundException` quando não existe; lança `NotFoundException` quando pertence a outro usuário. Esqueleto de e2e com `supertest` (`GET /features/:id` com id inválido → 400). Bloco `jest` do `package.json`:
```json
"coverageThreshold": { "global": { "lines": 80, "branches": 80 } }
```

`## Comandos úteis` — atuais (`pnpm start:dev`, `pnpm test`, `pnpm test:cov`, `pnpm migration:generate`, `pnpm migration:run`, `pnpm audit`); se algum script não existir no boilerplate, escrever o comando TypeORM CLI equivalente.

- [ ] **Step 4: Rodar a verificação**

Run: `bash scripts/check-skills.sh backend`
Expected: só falhas de `database.md` e `security.md` ausentes. Nenhuma falha em `SKILL.md` ou `patterns.md`. Corrigir se houver.

- [ ] **Step 5: Commit**

```bash
git add going2-backend
git commit -m "feat(going2-backend): add SKILL.md and patterns reference

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: going2-backend — database.md e security.md

**Files:**
- Create: `going2-backend/references/database.md`
- Create: `going2-backend/references/security.md`
- Consultar: spec §3; fontes `planetscale/database-skills/skills/postgres/references/{schema-design,indexing,query-patterns}.md`, `kadajett` rules `db-*`, `security-*`; `getsentry` `references/{authorization,injection,api-security,authentication}.md`; `cloudflare` `references/ATTACK-CLASSES.md`.

**Interfaces:**
- Consumes: nomes de Task 2 (`FeatureEntity`, `FeatureService`, `FeatureResponseDto`).

- [ ] **Step 1: Escrever `database.md`**

Uma seção `##` por item do spec §3 "references/database.md" (8 itens), cada uma com: regra em 1–2 frases, motivo em 1 frase, exemplo TypeORM curto. Exemplos obrigatórios:
- índice FK: `@Index()` + `@Column({ name: 'owner_id', type: 'uuid' })`;
- unique parcial: `@Index(['email'], { unique: true, where: '"deleted_at" IS NULL' })`;
- `EntityBase` com `@CreateDateColumn({ name: 'created_at', type: 'timestamptz' })`, idem `updated_at`, `@DeleteDateColumn({ name: 'deleted_at', type: 'timestamptz' })` — com nota "se o `EntityBase` do projeto usa `timestamp`, gerar migration para converter";
- relações: errado `eager: true`, certo `find({ relations: { owner: true } })` e `createQueryBuilder('f').leftJoinAndSelect('f.owner', 'o')`;
- paginação: `findAndCount({ take, skip, order })` com teto 100;
- transação:
```typescript
await this.dataSource.transaction(async (manager) => {
  const order = await manager.save(OrderEntity, orderData);
  await manager.save(OrderItemEntity, items.map((item) => ({ ...item, orderId: order.id })));
});
await this.paymentGateway.charge(order.id);
```
com bullet "dentro da transação use só `manager`, nunca os repositórios injetados; chamadas externas ficam fora";
- `synchronize: false` + `migrationsRun` no deploy + `down()` em toda migration;
- QueryBuilder: errado `.where(\`name = '${name}'\`)`, certo `.where('f.name = :name', { name })`; ordenação via allowlist `const SORTABLE = ['name', 'createdAt'] as const`.

Final: seção `## Fora do escopo` (tuning, replicação, WAL — falar com quem cuida do banco).

- [ ] **Step 2: Escrever `security.md`**

Topo: 3 linhas sobre como usar (aplicar ao escrever; checklist no `SKILL.md`; falha vs nota de hardening). Depois as 14 regras do spec §3, cada uma `## N. Título`, 1–3 frases, e bloco `// errado` / `// certo` em TypeScript quando houver código. Exemplos obrigatórios:
- regra 1: `@Public()` como decorator explícito + guard global que nega por padrão; nota: "se o projeto aplica guard por controller, nunca deixe controller sem `@UseGuards`";
- regra 2 (IDOR): errado `findOne({ where: { id } })` em rota de usuário; certo `findOne({ where: { id, ownerId: user.id } })` ou `ability.can(Action.Update, subject('Feature', entity))`;
- regra 5: `@Column({ select: false }) password: string;`;
- regra 6: `argon2.hash(password, { type: argon2.argon2id })`; login responde `'Credenciais inválidas'` para usuário inexistente e senha errada;
- regra 9: `ThrottlerModule.forRoot([{ ttl: 60_000, limit: 100 }])` + `@Throttle({ default: { limit: 5, ttl: 60_000 } })` no login (usar a API conferida no Step 1 da Task 2), `ThrottlerGuard` global, `app.useBodyParser('json', { limit: '1mb' })` (conferir API);
- regra 14: allowlist de hosts para URL de webhook/redirect com `new URL(input).hostname`.
Rodapé: `Baseado em getsentry/skills security-review (OWASP, CC BY-SA 4.0), cloudflare/security-audit-skill (MIT) e kadajett/agent-nestjs-skills — conteúdo reescrito.`

- [ ] **Step 3: Rodar a verificação**

Run: `bash scripts/check-skills.sh backend`
Expected: `OK backend`

- [ ] **Step 4: Commit**

```bash
git add going2-backend
git commit -m "feat(going2-backend): add database and security references

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: going2-frontend — SKILL.md e patterns.md

**Files:**
- Create: `going2-frontend/SKILL.md`
- Create: `going2-frontend/references/patterns.md`
- Consultar: `.claude/skills/nextjs-standards/SKILL.md` e `.claude/skills/nextjs-standards/references/nextjs.md` (versão **com** Orval — fonte do conteúdo atual); spec §2 e §4.

**Interfaces:**
- Consumes: `scripts/check-skills.sh frontend`.
- Produces: nomes usados por Tasks 5 e 6 — componente `FeatureList` em `components/(features)/feature-list/{index.tsx,useFeatureList.tsx}`, `FeatureForm` em `components/(features)/feature-form/{index.tsx,useFeatureForm.tsx}`, hook nuqs `useFeatureFilters`.

- [ ] **Step 1: Confirmar APIs atuais (obrigatório)**

Via context7:
- **Orval:** saída de `mode: 'tags-split'` (caminho e nome dos arquivos gerados), configuração do client `zod` (segundo target), nome dos exports zod (ex.: `createFeatureBody`), assinatura dos hooks react-query gerados (`useGetFeatures(params, options)`), `mutator`.
- **nuqs:** import do `NuqsAdapter` para Next App Router, `useQueryState`/`useQueryStates`, `parseAsInteger`, `parseAsString`, `parseAsStringLiteral`, opções `history`, `shallow`, `throttleMs`/`limitUrlUpdates`, adapter de testes (`NuqsTestingAdapter` ou equivalente).
- **NextAuth:** forma atual de obter sessão no servidor (`auth()` ou `getServerSession`) — usar a que o projeto atual usa; se ambíguo, mostrar `auth()` com nota.
- **Vitest:** `coverage.thresholds`.
Registrar no commit as fontes consultadas.

- [ ] **Step 2: Escrever `going2-frontend/SKILL.md`**

Frontmatter exato:

```markdown
---
name: going2-frontend
description: >
  Padrões de frontend da Going2 para Next.js App Router + shadcn/ui + TanStack Query + Orval + nuqs.
  Use sempre que for criar, revisar ou refatorar código de frontend: componente, hook, página,
  formulário, listagem, filtro, chamada de API, autenticação ou testes. Aplique mesmo quando o
  usuário não pedir "seguir padrões" — consistência, acessibilidade e segurança mínima são obrigatórias.
---
```

Seções, nesta ordem (conteúdo = spec §2 e §4 "SKILL.md", sem omitir itens):
1. `# Going2 — Frontend` + propósito.
2. `## Stack` — tabela sem versões, incluindo Orval e nuqs.
3. `## Como aplicar` — identificar artefato → abrir referência (`references/patterns.md`, `references/ui-guidelines.md`, `references/performance.md`, `references/security.md`, 1 linha de quando abrir cada) → gerar `index.tsx` + `useX.tsx` + testes → Checklist.
4. `## Nomenclatura` e `## Estrutura de pastas` — preservar os atuais, acrescentando `useX.test.tsx`/`index.test.tsx` e `src/gen/` (gerado, nunca editar à mão).
5. `## Regras críticas` — atuais + Orval, Server Component como casca, nuqs (spec §4).
6. `## Versões de dependências` — spec §2.
7. `## Testes` — spec §2 + hook e componente com Vitest/RTL, Cypress nos fluxos principais.
8. `## Segurança mínima` — 8 regras, uma linha cada.
9. `## Checklist de auto-revisão` — 10 itens: dados só via `src/gen`; `index.tsx` sem lógica; estado navegável no nuqs; loading/vazio/erro tratados; acessibilidade (labels, `aria-label`, foco); ação destrutiva com `AlertDialog`; nada sensível em `NEXT_PUBLIC_*` nem `localStorage`; sem `dangerouslySetInnerHTML`/redirect aberto; testes + cobertura ≥ 80%; `pnpm audit` limpo. Mesmo parágrafo falha vs nota de hardening do backend.

- [ ] **Step 3: Escrever `going2-frontend/references/patterns.md`**

Seções (usar APIs conferidas no Step 1):
- `## Componente` — `FeatureList` `index.tsx` (`'use client'`, só JSX, shadcn `Table`, `data-testid`) + `useFeatureList.tsx`.
- `## Page` — `page.tsx` server como casca: checa sessão e redireciona; renderiza o componente cliente.
- `## Formulário` — `useFeatureForm.tsx` com `useForm({ resolver: zodResolver(createFeatureBody) })` (schema gerado), `useCreateFeature` gerado, `toast.loading('Salvando...', { id })` → `toast.success('Funcionalidade salva', { id })` / `toast.error('Não foi possível salvar. Tente novamente.', { id })`; `index.tsx` com `Form`, `FormField`, `FormItem`, `FormLabel`, `FormControl`, `FormMessage`.
- `## Orval` — `orval.config.ts` com dois targets (react-query + zod) e `mode: 'tags-split'`; tabela do que é gerado e onde; import correto por tag; "rode `pnpm orval` quando o Swagger mudar; commite `src/gen/` junto"; "nunca edite `src/gen/` à mão".
- `## Estado na URL (nuqs)` — `NuqsAdapter` em `app/layout.tsx`; `useFeatureFilters` com `useQueryStates({ page: parseAsInteger.withDefault(1), search: parseAsString.withDefault(''), status: parseAsStringLiteral(['active', 'inactive'] as const) })`; `history: 'push'` para page, `'replace'` + throttle para search; `useFeatureList` lendo os filtros e passando ao hook Orval; ao mudar filtro, voltar `page` para 1.
- `## Testes` — `useFeatureList.test.tsx` com `renderHook`, `QueryClientProvider` e o adapter de testes do nuqs, mockando o módulo gerado com `vi.mock`; `index.test.tsx` com RTL buscando por `getByRole`/`getByTestId`; Cypress `cy.get('[data-testid="feature-form-submit"]')`; `vitest.config.ts` com `coverage: { provider: 'v8', thresholds: { lines: 80, branches: 80 } }` — a palavra `coverageThreshold` aparece no texto explicando a equivalência com o Jest do backend.
- `## Tailwind` — `cn()`.
- `## Variáveis de ambiente` e `## Comandos úteis` — atuais + `pnpm orval`, `pnpm test --coverage`, `pnpm audit`.

- [ ] **Step 4: Rodar a verificação**

Run: `bash scripts/check-skills.sh frontend`
Expected: só falhas de `ui-guidelines.md`, `performance.md`, `security.md` ausentes.

- [ ] **Step 5: Commit**

```bash
git add going2-frontend
git commit -m "feat(going2-frontend): add SKILL.md and patterns reference

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: going2-frontend — ui-guidelines, performance, security

**Files:**
- Create: `going2-frontend/references/ui-guidelines.md`
- Create: `going2-frontend/references/performance.md`
- Create: `going2-frontend/references/security.md`
- Consultar: spec §4; `web-interface-guidelines/command.md`, `anthropics/skills/skills/frontend-design/SKILL.md`, `vercel-agent-skills/skills/react-best-practices/rules/`, `getsentry` `languages/javascript.md` + `references/xss.md`, `cloudflare` `references/CLIENT-SIDE.md`.

**Interfaces:**
- Consumes: `FeatureList`, `FeatureForm`, `useFeatureFilters` (Task 4).

- [ ] **Step 1: `ui-guidelines.md`**

Seções `##` para cada grupo do spec §4 "ui-guidelines.md" (Acessibilidade, Formulários, Estados de tela, Ações destrutivas, Formatação, Movimento, Textos de interface). Cada item em bullet acionável, com exemplo JSX curto onde ajuda:
- botão de ícone: `<Button size="icon" aria-label="Excluir funcionalidade"><Trash2 aria-hidden /></Button>`;
- `AlertDialog` antes de excluir;
- `new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' }).format(value)` e `Intl.DateTimeFormat('pt-BR')`;
- estado vazio com ação ("Nenhuma funcionalidade ainda. Criar funcionalidade");
- tabela de textos: errado/certo (`Enviar` → `Salvar alterações`; `Erro!` → `Não foi possível salvar. Verifique a conexão e tente novamente.`).
Rodapé de atribuição (vercel-labs/web-interface-guidelines MIT, anthropics/skills frontend-design Apache-2.0).

- [ ] **Step 2: `performance.md`**

Uma seção por item do spec §4 "performance.md" (6 itens), cada uma com errado/certo:
- `next.config.ts` com `experimental.optimizePackageImports: ['lucide-react']` (conferir via context7 se ainda é `experimental` ou se lucide já é otimizado por padrão; registrar o resultado);
- `const Chart = dynamic(() => import('./chart'), { ssr: false })` dentro de componente cliente;
- `Promise.all` em `page.tsx` server com duas chamadas;
- errado `useEffect(() => setFullName(first + ' ' + last), [first, last])`, certo `const fullName = \`${first} ${last}\``;
- componente definido dentro de componente (errado/certo);
- `{count > 0 ? <Badge>{count}</Badge> : null}` vs `{count && ...}`;
- passar ao cliente só os campos necessários.
Seção `## O que não usar aqui` (SWR, fetch de dados em RSC, memoização prematura). Rodapé de atribuição (vercel-labs/agent-skills, MIT).

- [ ] **Step 3: `security.md`**

Topo igual ao do backend. As 8 regras do spec §4, `## N. Título`, com errado/certo:
- 1: `NEXT_PUBLIC_API_URL` ok, `NEXT_PUBLIC_STRIPE_SECRET` errado;
- 2: errado `dangerouslySetInnerHTML={{ __html: comment }}`; certo `{comment}`; função `isSafeHref(url)` aceitando só `http:`, `https:`, `mailto:`;
- 3: callback `redirect({ url, baseUrl })` do NextAuth aceitando só `url.startsWith('/')` ou `new URL(url).origin === baseUrl`; validar `callbackUrl` igual ao usar `router.push`;
- 4: errado `localStorage.setItem('token', ...)`; certo sessão NextAuth; callback `session` expondo só `id`, `name`, `email`, `role`;
- 5: esconder botão é UX; API decide;
- 6: Server Action com `const session = await auth(); if (!session) throw ...; const data = schema.parse(input);`;
- 7: `next.config.ts` `headers()` com `Content-Security-Policy` (sem `unsafe-eval`; nota sobre ajustar `script-src` com nonce se necessário), `X-Content-Type-Options: nosniff`, `Referrer-Policy: strict-origin-when-cross-origin`, `frame-ancestors 'none'`;
- 8: lockfile, `pnpm audit` zero, Orval só do spec do nosso backend.
Rodapé de atribuição (getsentry/OWASP CC BY-SA 4.0, Cloudflare MIT).

- [ ] **Step 4: Rodar a verificação**

Run: `bash scripts/check-skills.sh frontend`
Expected: `OK frontend`

- [ ] **Step 5: Commit**

```bash
git add going2-frontend
git commit -m "feat(going2-frontend): add ui, performance and security references

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Evals

**Files:**
- Create: `evals/going2-backend.json`
- Create: `evals/going2-frontend.json`
- Consultar: `.claude/skills/company-standards/evals/evals.json` (formato e casos atuais).

**Interfaces:**
- Consumes: nomes de Tasks 2–5.

- [ ] **Step 1: Escrever `evals/going2-backend.json`**

```json
{
  "skill_name": "going2-backend",
  "evals": [
    {
      "id": 1,
      "prompt": "Preciso criar um módulo de 'products' no backend NestJS com nome, preço e categoria (relacionamento com categories). Cria tudo seguindo os padrões da empresa.",
      "expected_output": "Entity ProductEntity estendendo EntityBase, tabela 'products', @Index() em category_id, unique parcial com deleted_at IS NULL se houver campo único; CreateProductDto/UpdateProductDto com @ApiProperty e mensagens em português; ProductResponseDto com fromEntity; service com findAndCount e take limitado a 100, NotFoundException em português; controller com PoliciesGuard, ApiBearerAuth, ApiTags, ParseUUIDPipe e @ApiOkResponse({ type: ProductResponseDto }); module; product.service.spec.ts cobrindo sucesso, não encontrado e permissão; menção a coverageThreshold 80%.",
      "files": []
    },
    {
      "id": 2,
      "prompt": "Cria um endpoint PUT /invoices/:id para o usuário logado editar a própria fatura.",
      "expected_output": "Service busca com where { id, ownerId: user.id } (ou checagem CASL na instância) e lança NotFoundException quando a fatura é de outro usuário; DTO de update sem ownerId/status privilegiado; ParseUUIDPipe; ValidationPipe com whitelist/forbidNonWhitelisted; teste cobrindo tentativa de editar fatura de outro usuário.",
      "files": []
    },
    {
      "id": 3,
      "prompt": "Implementa o login com email e senha no backend.",
      "expected_output": "Hash com argon2id (ou bcrypt custo >= 12); mensagem genérica 'Credenciais inválidas' para usuário inexistente e senha errada; @Throttle restritivo na rota; JWT com segredo via ConfigService e expiração; password com select: false e nunca na resposta; testes do service de auth.",
      "files": []
    },
    {
      "id": 4,
      "prompt": "Adiciona um endpoint de listagem de pedidos com filtro por status e ordenação escolhida pelo cliente.",
      "expected_output": "Query DTO com @Type(() => Number) para page/perPage e allowlist para campo de ordenação e direção; QueryBuilder com parâmetros nomeados, sem interpolação; take limitado a 100 e order determinístico; leftJoinAndSelect explícito sem eager; resposta paginada com DTO tipado no Swagger; testes.",
      "files": []
    }
  ]
}
```

- [ ] **Step 2: Escrever `evals/going2-frontend.json`**

```json
{
  "skill_name": "going2-frontend",
  "evals": [
    {
      "id": 1,
      "prompt": "Quero criar um componente de listagem de usuários no frontend Next.js, com busca por nome e paginação. O componente se chama UserList.",
      "expected_output": "components/(users)/user-list/index.tsx com 'use client' e só JSX (shadcn Table, data-testid, estados loading/vazio/erro) e useUserList.tsx usando o hook gerado pelo Orval em src/gen; page e search na URL via nuqs (useQueryStates com parseAsInteger/parseAsString, throttle na busca, page volta a 1 ao buscar); testes Vitest do hook com adapter de testes do nuqs e do componente; menção à cobertura de 80%.",
      "files": []
    },
    {
      "id": 2,
      "prompt": "Cria um formulário de cadastro de clientes com campos: nome, email e telefone. Usa os padrões do projeto para validação e feedback de erro/sucesso.",
      "expected_output": "useClientForm com useForm + zodResolver usando o schema Zod gerado pelo Orval (não escrito à mão), mutation gerada pelo Orval, toast.loading/success/error com o mesmo id e textos específicos em português; JSX com Form, FormField, FormItem, FormLabel, FormMessage, autocomplete nos campos, botão desabilitado só durante o envio; testes.",
      "files": []
    },
    {
      "id": 3,
      "prompt": "Adiciona um botão de excluir pedido na tabela de pedidos.",
      "expected_output": "Botão de ícone com aria-label, AlertDialog de confirmação, mutation gerada pelo Orval, toasts com o mesmo id, invalidação da query da listagem, data-testid, lógica no hook e não no index.tsx; teste do fluxo.",
      "files": []
    },
    {
      "id": 4,
      "prompt": "Depois do login, redireciona o usuário para a página que ele tentou acessar antes (callbackUrl).",
      "expected_output": "Validação do callbackUrl aceitando só caminho relativo ou mesma origem (callback redirect do NextAuth), sem open redirect; token mantido na sessão NextAuth e nunca em localStorage; nenhum segredo em NEXT_PUBLIC_*; teste cobrindo callbackUrl externo sendo rejeitado.",
      "files": []
    }
  ]
}
```

- [ ] **Step 3: Rodar a verificação**

Run: `bash scripts/check-skills.sh evals`
Expected: `OK evals`

- [ ] **Step 4: Commit**

```bash
git add evals
git commit -m "test: add evals for going2-backend and going2-frontend

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Remover skills antigas, README e NOTICE

**Files:**
- Delete: `company-standards/`, `nestjs-standards/`, `nextjs-standards/`, `company-standards.skill`, `nestjs-standards.skill`, `nextjs-standards.skill`, `.claude/skills/company-standards/`, `.claude/skills/nestjs-standards/`, `.claude/skills/nextjs-standards/`, `.claude/skills/skill-creator`
- Modify: `README.md`
- Create: `NOTICE.md`

**Interfaces:**
- Consumes: Tasks 2–6 concluídas (todo conteúdo exclusivo das cópias já migrado: Orval → Task 4, evals → Task 6).

- [ ] **Step 1: Confirmar que nada exclusivo vai se perder**

Run: `grep -n "Orval\|orval" going2-frontend/references/patterns.md | head -3 && ls evals/`
Expected: linhas com Orval e os dois arquivos de evals. Se faltar, voltar à task correspondente.

- [ ] **Step 2: Remover**

```bash
git rm -r -q company-standards nestjs-standards nextjs-standards \
  company-standards.skill nestjs-standards.skill nextjs-standards.skill \
  .claude/skills/company-standards .claude/skills/nestjs-standards \
  .claude/skills/nextjs-standards .claude/skills/skill-creator
```

- [ ] **Step 3: Reescrever `README.md`**

```markdown
# Going2 — Skills IA

Skills do Claude Code com os padrões de desenvolvimento da Going2: estrutura, nomenclatura, testes e um mínimo de segurança. Instale no projeto e peça normalmente — o Claude aplica os padrões sozinho.

## Skills

| Skill | Para |
|---|---|
| `going2-backend` | NestJS + TypeORM + PostgreSQL: módulos, entities, DTOs, controllers, services, migrations, testes e segurança |
| `going2-frontend` | Next.js App Router + shadcn/ui + TanStack Query + Orval + nuqs: componentes, hooks, páginas, formulários, testes, acessibilidade e segurança |

## Instalação

Pré-requisito: [Claude Code](https://claude.ai/code).

### Via skills.sh (recomendado)

```bash
npx skills add Going2Custom/skills-ia/going2-backend
npx skills add Going2Custom/skills-ia/going2-frontend
```

### Manual

Copie a pasta da skill para `.claude/skills/` do seu projeto (ou `~/.claude/skills/` para todos os projetos):

```bash
git clone https://github.com/Going2Custom/skills-ia.git /tmp/skills-ia
cp -R /tmp/skills-ia/going2-backend .claude/skills/
```

## Migrando das skills antigas

`nestjs-standards`, `nextjs-standards` e `company-standards` foram substituídas. Remova-as antes de instalar as novas para não ter regras conflitantes:

```bash
rm -rf .claude/skills/nestjs-standards .claude/skills/nextjs-standards .claude/skills/company-standards
```

## Como funciona

Peça normalmente:

> "Cria um módulo de produtos no backend"
> "Cria uma listagem de pedidos com filtro e paginação"
> "Cria um formulário de cadastro de cliente"

O Claude segue a estrutura de pastas, os padrões de código, escreve os testes (cobertura mínima de 80%) e roda o checklist de segurança antes de entregar.

## Estrutura do repositório

```
going2-backend/      SKILL.md + references/ (patterns, database, security)
going2-frontend/     SKILL.md + references/ (patterns, ui-guidelines, performance, security)
evals/               casos de avaliação das skills
scripts/             check-skills.sh — verificação de estrutura e conteúdo
docs/superpowers/    design e plano de implementação
```

Antes de abrir PR alterando uma skill, rode `bash scripts/check-skills.sh`.

## Créditos

As skills incorporam ideias de skills públicas, reescritas para o nosso stack. Veja [NOTICE.md](NOTICE.md).
```

- [ ] **Step 4: Criar `NOTICE.md`**

```markdown
# Atribuições

O conteúdo de `going2-backend` e `going2-frontend` foi escrito pela Going2 a partir dos padrões internos e de ideias das skills abaixo. Nenhum trecho foi copiado literalmente; regras foram reescritas e adaptadas.

| Fonte | Licença | Usada em |
|---|---|---|
| [anthropics/skills — frontend-design](https://github.com/anthropics/skills) | Apache-2.0 | going2-frontend (ui-guidelines) |
| [vercel-labs/agent-skills — vercel-react-best-practices](https://github.com/vercel-labs/agent-skills) | MIT | going2-frontend (performance) |
| [vercel-labs/web-interface-guidelines](https://github.com/vercel-labs/web-interface-guidelines) (via vercel-labs/agent-skills — web-design-guidelines) | MIT | going2-frontend (ui-guidelines) |
| [kadajett/agent-nestjs-skills — nestjs-best-practices](https://github.com/kadajett/agent-nestjs-skills) | MIT (declarada no SKILL.md) | going2-backend (patterns, security) |
| [planetscale/database-skills — postgres](https://github.com/planetscale/database-skills) | MIT | going2-backend (database) |
| [getsentry/skills — security-review](https://github.com/getsentry/skills) | Apache-2.0; referências derivadas do OWASP Cheat Sheet Series sob CC BY-SA 4.0 | going2-backend e going2-frontend (security) |
| [cloudflare/security-audit-skill](https://github.com/cloudflare/security-audit-skill) | MIT | going2-backend e going2-frontend (security, checklist) |
```

- [ ] **Step 5: Rodar a verificação completa**

Run: `bash scripts/check-skills.sh`
Expected: `OK all`

- [ ] **Step 6: Commit**

```bash
git add -A README.md NOTICE.md
git commit -m "chore: replace legacy skills with going2-backend and going2-frontend

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: Revisão final contra o spec

**Files:**
- Modify: qualquer arquivo das skills, se houver lacuna.

- [ ] **Step 1: Cobertura do spec**

Para cada bullet das seções 2, 3 e 4 de `docs/superpowers/specs/2026-11-18-going2-skills-design.md`, localizar o trecho correspondente com `grep -n` nas skills. Listar qualquer item sem correspondência e adicioná-lo no arquivo certo.

- [ ] **Step 2: Leitura como usuário**

Ler `going2-backend/SKILL.md` e `going2-frontend/SKILL.md` inteiros e responder: um dev novo saberia qual referência abrir para "criar um formulário" e para "criar uma migration"? Exemplos compilariam (imports presentes, nomes consistentes com Tasks 2 e 4)? Corrigir o que falhar.

- [ ] **Step 3: Verificação**

Run: `bash scripts/check-skills.sh && git status --short`
Expected: `OK all` e working tree limpa (ou só as correções deste passo).

- [ ] **Step 4: Commit (se houve correções)**

```bash
git add -A going2-backend going2-frontend
git commit -m "fix: close gaps found in final spec review

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```
