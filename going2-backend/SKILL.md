---
name: going2-backend
description: >
  Padrões de backend da Going2 para NestJS + TypeORM + PostgreSQL. Use sempre que for criar,
  revisar ou refatorar código de backend: módulo, entity, DTO, service, controller, migration,
  guard, autenticação, autorização, validação, Swagger ou testes. Aplique mesmo quando o usuário
  não pedir "seguir padrões" — consistência e segurança mínima são obrigatórias.
---

# Going2 — Backend

Este guia define como escrever backend na Going2: estrutura, nomenclatura, regras de código, testes e um piso de segurança que vale para toda entrega. O objetivo é que qualquer módulo gerado tenha o mesmo formato, passe em revisão sem retrabalho e não introduza falhas óbvias.

## Stack

| Área | Padrão |
|---|---|
| Framework | NestJS + TypeScript |
| ORM | TypeORM + PostgreSQL |
| Auth | JWT + Passport + CASL |
| Validação | class-validator + class-transformer |
| Docs | @nestjs/swagger |
| Testes | Jest + supertest |

## Como aplicar

1. Identifique o artefato pedido (entity, DTO, service, controller, module, migration, guard, teste).
2. Leia a referência certa antes de escrever código:
   - `references/patterns.md` — templates de entity, DTOs, response DTO, controller, service, module, `main.ts`, config e testes. Abra sempre.
   - `references/database.md` — índices, soft delete, relações, paginação, transações e migrations. Abra ao mexer em entity, query ou migration.
   - `references/security.md` — as regras de segurança com exemplo certo e errado. Abra ao criar rota, auth, upload ou qualquer entrada de usuário.
3. Gere o módulo completo: entity, `Create`/`Update` DTOs, response DTO, service, controller, module e os `*.spec.ts` correspondentes.
4. Rode o Checklist de auto-revisão ao final.

## Nomenclatura

| Padrão | Convenção |
|---|---|
| Arquivos e pastas | `kebab-case` |
| Classes e interfaces | `PascalCase` |
| Variáveis e funções | `camelCase` |
| Constantes | `SCREAMING_SNAKE_CASE` |
| Nomes e valores de enum | `PascalCase` |
| Tabelas do banco | `snake_case` |

## Estrutura de pastas

```
src/[feature]/
├── dto/
│   ├── create-[feature].dto.ts
│   ├── update-[feature].dto.ts
│   └── [feature]-response.dto.ts
├── interfaces/
├── repositories/
├── [feature].controller.ts
├── [feature].controller.spec.ts
├── [feature].service.ts
├── [feature].service.spec.ts
├── [feature].module.ts
└── [feature].entity.ts
```

## Regras críticas

- Entities **devem** estender `EntityBase` de `@/common/entity/entity-base`.
- Colunas no banco em `snake_case` via `{ name: 'snake_case' }`; propriedades TypeScript em `camelCase`.
- Nunca apagar de verdade: soft delete via `deleted_at` do `EntityBase` (`softDelete`). Não filtrar `deletedAt` no `where`, o TypeORM já exclui os removidos.
- Nunca usar `any`; tipar tudo.
- Todo campo de DTO tem `@ApiProperty` e decorators do class-validator com mensagem em português.
- Controllers usam `@UseGuards(PoliciesGuard)`, `@ApiBearerAuth()` e `@ApiTags()`.
- Services lançam exceções do Nest: `NotFoundException`, `ForbiddenException`, `BadRequestException`, `ConflictException`.
- Controllers retornam o response DTO (`dto/[feature]-response.dto.ts`), declarado em `@ApiOkResponse({ type })`. Nunca retornar a entity crua.
- Todo parâmetro `:id` usa `ParseUUIDPipe`.
- Mensagens de validação e exceção em português, sem interpolar input do usuário.
- Nenhuma promise solta: sempre `await` ou retorno explícito.
- Service é singleton: nenhum estado de request em propriedade de classe.
- Migrations sempre, inclusive em desenvolvimento (`synchronize: false`).
- `@InjectRepository` direto no service, PK UUID e enums nativos do PostgreSQL.
- Sem comentários que expliquem o que o código faz; comente só o porquê quando não for óbvio.

## Versões de dependências

- Esta skill não fixa versão de nenhuma biblioteca.
- Projeto novo ou dependência nova: última versão estável (nunca beta, RC ou canary).
- Depois de instalar, `pnpm audit` deve retornar zero vulnerabilidades, de qualquer severidade. Se a correção exigir major com breaking change, pare e avise o usuário.
- O lockfile é sempre commitado.
- Projeto existente: respeite as versões do `package.json`; não atualize sem pedido.

## Testes

- Todo código novo vem com testes.
- Configure `coverageThreshold` global de 80% em linhas e branches no Jest para o CI falhar abaixo disso.
- Cada service cobre: caminho feliz, not found e permissão negada (registro de outro dono).
- Toda rota nova tem teste e2e com supertest (ao menos id inválido, sem token e caminho feliz).

## Segurança mínima

Detalhes e exemplos em `references/security.md`.

1. Toda rota autenticada e autorizada via CASL, deny by default; `@Public()` só explícito e justificado; revise caminhos paralelos (bulk, export).
2. Evite IDOR: busque filtrando por dono/tenant ou use `ability.can(action, subject(entity))` na instância.
3. `ValidationPipe` com `whitelist`; DTOs separados; `role`, `ownerId` e `isAdmin` nunca no DTO público.
4. Nunca use `${}` em `query()`, `.where()` ou `orderBy`; sempre parâmetros.
5. Responda via response DTO; `password` com `select: false`.
6. Senhas com argon2id ou bcrypt de custo 12 ou mais; login com mensagem genérica.
7. JWT com algoritmo fixo, `exp` validado, segredo via config, nunca decode sem verify; `validate()` recarrega o usuário.
8. Segredos só em variáveis de ambiente; `.env` no `.gitignore`.
9. `@nestjs/throttler` em login, reset de senha e rotas caras; limite de tamanho do body; paginação com teto.
10. CORS com allowlist; nunca refletir `Origin` com credentials.
11. `helmet()` ativo.
12. Erros fail-closed: sem stack trace ou erro SQL na resposta; Swagger e debug fechados em produção.
13. Logs sem senha, token ou PII; registre eventos de auth e negações.
14. URLs e redirects vindos do usuário passam por allowlist (open redirect, SSRF).

## Checklist de auto-revisão

- [ ] Toda rota tem guard e política CASL; nenhuma rota pública sem justificativa.
- [ ] Rotas com `:id` checam o dono/tenant (sem IDOR) e usam `ParseUUIDPipe`.
- [ ] DTOs de entrada não têm campos privilegiados (`role`, `ownerId`, `isAdmin`).
- [ ] Nenhum `${}` em SQL, `.where()` ou `orderBy`; identificadores por allowlist.
- [ ] Response DTO sem campos sensíveis; entity nunca retornada direto.
- [ ] Índice em toda FK e unique parcial com `"deleted_at" IS NULL` quando houver soft delete.
- [ ] Testes escritos e cobertura de 80% ou mais em linhas e branches.
- [ ] `pnpm audit` limpo e lockfile commitado.
- [ ] Nenhum segredo no código ou em exemplos; `.env` ignorado.
- [ ] Logs e erros sem PII, token ou stack trace.

Classifique cada problema como **falha** (entrada controlada por atacante + impacto concreto — corrigir antes de entregar) ou **nota de hardening** (falta de defesa em profundidade — mencionar ao usuário, sem bloquear).
