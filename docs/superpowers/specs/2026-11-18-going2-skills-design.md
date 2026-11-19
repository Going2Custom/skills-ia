# Going2 Skills — Design

**Data:** 2026-11-18
**Status:** aprovado em brainstorming, aguardando revisão do spec

## Objetivo

Substituir as três skills atuais (`company-standards`, `nestjs-standards`, `nextjs-standards`) por **duas skills enxutas** — `going2-backend` e `going2-frontend` — que padronizam o código gerado pelo Claude, garantem um **mínimo de segurança** e preservam os padrões já usados na Going2, incorporando o melhor de skills públicas de referência.

## Fontes de referência

Conteúdo é **reescrito com nossas palavras** e adaptado ao stack; nada é copiado literalmente (o material da Sentry deriva do OWASP sob CC BY-SA 4.0).

| Fonte | Licença | Uso |
|---|---|---|
| anthropics/skills — frontend-design | Apache-2.0 | piso de qualidade de UI, textos de interface |
| vercel-labs/agent-skills — vercel-react-best-practices | MIT (declarado) | performance React/Next aplicável |
| vercel-labs/agent-skills — web-design-guidelines (web-interface-guidelines) | MIT | acessibilidade, formulários, estados de tela |
| kadajett/agent-nestjs-skills — nestjs-best-practices | MIT (declarado no frontmatter) | arquitetura, validação, erros, testes Nest |
| planetscale/database-skills — postgres | MIT | índices, schema, queries, transações |
| getsentry/skills — security-review | Apache-2.0 / CC BY-SA 4.0 (OWASP) | baseline de segurança, critério de confiança |
| cloudflare/security-audit-skill | MIT | checklist "obvious things", controle de acesso |

## 1. Estrutura do repositório

```
going2-backend/
├── SKILL.md
└── references/
    ├── patterns.md
    ├── database.md
    └── security.md
going2-frontend/
├── SKILL.md
└── references/
    ├── patterns.md
    ├── ui-guidelines.md
    ├── performance.md
    └── security.md
evals/
├── going2-backend.json
└── going2-frontend.json
README.md
NOTICE.md
```

**Removidos:** `company-standards/`, `nestjs-standards/`, `nextjs-standards/` (raiz), `.claude/skills/{company,nestjs,nextjs}-standards/`, `*.skill`, symlink `.claude/skills/skill-creator`. `skills-lock.json` permanece.

**Migração:** antes de remover, todo conteúdo exclusivo das cópias em `.claude/skills/` (seção Orval, evals) é incorporado nas novas skills.

**README:** instalação apenas via `npx skills add Going2Custom/skills-ia/going2-backend` / `going2-frontend` e cópia manual para `.claude/skills/`. Remove o comando `claude skill install`. Nota de migração: quem tem `nestjs-standards`, `nextjs-standards` ou `company-standards` instaladas deve removê-las.

**NOTICE.md:** atribuição e licença de cada fonte.

## 2. Regras comuns às duas skills

### Versões
- A skill **não fixa versão** de nenhuma lib.
- Projeto novo ou dependência nova: **última versão estável** (nunca beta/RC/canary).
- Após instalar, `pnpm audit` deve retornar **zero vulnerabilidades, de qualquer severidade**. Se a correção exigir major com breaking change, o Claude para e avisa.
- Lockfile sempre commitado.
- Projeto existente: respeitar as versões do `package.json`; não atualizar sem pedido.

### Testes (obrigatórios)
- Todo código novo vem com testes.
- `coverageThreshold` de **80% em linhas e branches** configurado (Jest no backend, Vitest no frontend) para falhar o CI abaixo disso.

### Formato das regras de segurança
- `SKILL.md` lista as regras em uma linha cada (aplicadas **ao escrever**) e um **checklist de auto-revisão** (~10 itens) rodado ao final.
- Checklist distingue **falha real** (atacante controla a entrada e há impacto concreto) de **nota de hardening** (ausência de defesa em profundidade) para evitar falsos positivos.
- Não há skill separada de segurança.

### Estilo
- Sem comentários explicando o que o código faz; só o porquê quando não for óbvio.
- Nunca `any`.

## 3. going2-backend

### SKILL.md (~120 linhas)
- Stack (sem versões): NestJS, TypeScript, TypeORM, PostgreSQL, JWT + Passport, CASL, class-validator, @nestjs/swagger, Jest.
- Como aplicar: identificar o artefato → abrir a referência → gerar o módulo completo (entity, DTOs, response DTO, service, controller, module, testes).
- Nomenclatura e estrutura de pastas (mantidas).
- Regras críticas: as atuais + `ParseUUIDPipe` em todo `:id`; mensagens de validação e exceção em português sem interpolar input do usuário; nenhuma promise solta; nenhum estado de request em service singleton.
- Versões, testes, segurança mínima, checklist.

### Mudanças de padrão aprovadas
1. **Response DTO:** controllers retornam `dto/[feature]-response.dto.ts` com `@ApiProperty`, usado em `@ApiOkResponse({ type })`. Nunca retornar a entidade crua. Motivo: não vazar campos sensíveis e manter Swagger/Orval exatos.
2. **Migrations sempre**, inclusive em dev (`synchronize: false`).

### Mantido como está
`@InjectRepository` direto no service (sem classe de repositório própria), PK UUID, enums nativos, `PoliciesGuard` por controller.

### references/patterns.md
- Templates: entity (estende `EntityBase`), create/update/response DTOs, controller, service, module — com correções: mensagens em PT, sem `where: { deletedAt: null }` (o TypeORM já exclui soft-deleted).
- `main.ts`: `ValidationPipe({ whitelist, forbidNonWhitelisted, transform })`, `helmet()`, CORS com allowlist, Swagger desabilitado em produção.
- Config validada no boot (`JWT_SECRET` obrigatório e forte).
- Testes: `Test.createTestingModule` com `getRepositoryToken` mockado; service cobre caminho feliz, not found e permissão negada; e2e com supertest nas rotas novas; config de `coverageThreshold`.

### references/database.md
- `@Index()` em toda coluna de FK.
- Unique parcial com soft delete: `@Index([...], { unique: true, where: '"deleted_at" IS NULL' })`.
- Datas `timestamptz`.
- Relações carregadas explicitamente (`relations` / `leftJoinAndSelect`); proibido `eager: true` e lazy relations.
- Paginação com `take` máximo 100 e `order` determinístico.
- Transações curtas via `dataSource.transaction`, usando só o `manager`; nenhuma chamada externa dentro.
- `synchronize: false`, migrations com `down()`.
- QueryBuilder sempre com parâmetros; identificadores (coluna de ordenação, direção) por allowlist.

### references/security.md (14 regras, com exemplo certo/errado)
1. Toda rota autenticada e autorizada (CASL), deny by default; `@Public()` só explícito e justificado; checar caminhos paralelos (bulk, export).
2. IDOR: buscar filtrando por dono/tenant ou `ability.can(action, subject(entity))` na instância.
3. `ValidationPipe` com whitelist; DTOs separados; `role`, `ownerId`, `isAdmin` nunca no DTO público.
4. Sem `${}` em `query()`, `.where()`, `orderBy`.
5. Respostas via response DTO; `password` com `select: false`.
6. Senhas com argon2id ou bcrypt custo ≥ 12; login com mensagem genérica.
7. JWT: algoritmo fixo, validar `exp`, segredo via config, nunca decode sem verify; `validate()` recarrega o usuário.
8. Segredos só em env; `.env` no `.gitignore`.
9. `@nestjs/throttler` em login, reset de senha e rotas caras; limite de tamanho do body; paginação com teto.
10. CORS com allowlist; nunca refletir `Origin` com credentials.
11. `helmet()`.
12. Erros fail-closed: sem stack trace/erro SQL na resposta; Swagger e debug fechados em produção.
13. Logs sem senha, token ou PII; registrar eventos de auth e negação.
14. URLs/redirects vindos do usuário via allowlist (open redirect, SSRF).

## 4. going2-frontend

### SKILL.md (~120 linhas)
- Stack (sem versões): Next.js App Router, TypeScript, shadcn/ui + Radix, Tailwind, React Hook Form + Zod, TanStack Query, Axios, NextAuth, Orval, nuqs, Vitest + React Testing Library, Cypress.
- Nomenclatura e estrutura de pastas (mantidas).
- Regras críticas: as atuais (`index.tsx` visual com `'use client'` + `useX.tsx` lógica, shadcn primeiro, `cn()`, sonner com mesmo id em loading/success/error, `data-testid`, sem `any`) +
  - **Dados só via hooks gerados pelo Orval** (`src/gen/`); nada de `fetch`/axios em `useEffect`; nada de tipos de API escritos à mão; `pnpm orval` quando o Swagger mudar.
  - **Server Component apenas como casca de rota** (`page.tsx`, `layout.tsx`, checagem de sessão); dados no cliente via TanStack Query.
  - **Estado navegável na URL via nuqs** (filtros, busca, paginação, abas, ordenação), com parsers tipados, dentro do `useX.tsx`.
- Versões, testes, segurança mínima, checklist.

### references/patterns.md
- Templates: componente (index + hook), page, form (Zod gerado pelo Orval + RHF + sonner).
- Orval corrigido: imports por tag (`mode: 'tags-split'`), target `zod` separado para gerar schemas, nomes reais dos exports.
- nuqs: `NuqsAdapter` no layout raiz; listagem paginada/filtrada alimentando os parâmetros do hook Orval; `history: 'replace'` para filtros digitados, `'push'` para paginação/abas; throttle/debounce em busca.
- Testes: Vitest + RTL para hook e componente (incluindo adapter de teste do nuqs), Cypress para fluxos principais, `coverageThreshold`.
- **Exemplos de Orval e nuqs conferidos na documentação atual antes de escrever.**

### references/ui-guidelines.md
- Acessibilidade: `aria-label` em botão só com ícone, label em todo campo, `<button>` para ação e `<Link>` para navegação, foco visível (nunca `outline-none` sem substituto), `aria-live` em mensagens.
- Formulários: `autocomplete`/`name`/`type` corretos, nunca bloquear colar, botão habilitado até o envio começar, erro ao lado do campo, foco no primeiro erro, aviso de alterações não salvas.
- Estados de loading, vazio e erro sempre tratados; `AlertDialog` antes de ação destrutiva.
- `Intl` com `pt-BR` para datas, números e moeda.
- `prefers-reduced-motion`; nunca `transition: all`.
- Textos de interface: verbo específico no botão, toast ecoa o verbo ("Salvar" → "Salvo"), erro diz como corrigir, sentence case.

### references/performance.md
- `optimizePackageImports` (ex.: lucide-react); `next/dynamic` para componentes pesados.
- `Promise.all` para chamadas independentes.
- Derivar estado no render em vez de `useEffect` + `setState`.
- Nunca definir componente dentro de componente.
- Ternário em vez de `&&` com valores numéricos.
- Passar ao cliente só os campos necessários.
- Fora: SWR, data fetching em RSC, microotimizações de JS, memoização prematura.

### references/security.md (8 regras, com exemplo certo/errado)
1. Nada sensível em `NEXT_PUBLIC_*`.
2. `dangerouslySetInnerHTML` proibido (DOMPurify se inevitável); validar esquema de URLs em `href`/`src`.
3. `callbackUrl`/`next` só relativos ou origem permitida (callback `redirect` do NextAuth).
4. Tokens na sessão NextAuth (cookie httpOnly/Secure/SameSite), nunca `localStorage`; expor ao cliente só o necessário.
5. Autorização é do backend; esconder UI é só UX.
6. Zod valida entrada em Server Actions e Route Handlers; Server Actions sempre checam auth.
7. Headers/CSP em `next.config`: CSP sem `unsafe-eval`, `frame-ancestors`, `nosniff`, `Referrer-Policy`.
8. Lockfile commitado, `pnpm audit` limpo, Orval gerado só do spec do nosso backend.

## 5. Validação

- `evals/going2-backend.json` (~4 casos): módulo completo (response DTO, `ParseUUIDPipe`, testes, índice em FK); rota com risco de IDOR (checagem de dono); + casos atuais adaptados.
- `evals/going2-frontend.json` (~4 casos): listagem paginada (Orval + nuqs + testes); formulário (Zod do Orval, toasts, acessibilidade); + casos atuais adaptados.
- Exemplos de código conferidos na documentação atual (Orval, nuqs, TypeORM, NestJS, NextAuth).
- Rodada comparativa com skill-creator (skill nova vs. antiga): **opcional**, só se solicitado.

## Fora de escopo
- Skill separada de segurança ou de auditoria completa.
- Design autoral / landing pages.
- Microsserviços, filas, versionamento de API, operação de banco (WAL, replicação, tuning).
