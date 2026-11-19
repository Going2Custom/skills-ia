---
name: going2-frontend
description: >
  Padrões de frontend da Going2 para Next.js App Router + shadcn/ui + TanStack Query + Orval + nuqs.
  Use sempre que for criar, revisar ou refatorar código de frontend: componente, hook, página,
  formulário, listagem, filtro, chamada de API, autenticação ou testes. Aplique mesmo quando o
  usuário não pedir "seguir padrões" — consistência, acessibilidade e segurança mínima são obrigatórias.
---

# Going2 — Frontend

Este guia define como escrever frontend na Going2: estrutura, nomenclatura, regras de código, testes e um piso de segurança que vale para toda entrega. O objetivo é que qualquer tela gerada tenha o mesmo formato, passe em revisão sem retrabalho e não introduza falhas óbvias.

## Stack

| Área | Padrão |
|---|---|
| Framework | Next.js (App Router) + TypeScript |
| UI | shadcn/ui + Radix UI |
| Estilo | Tailwind CSS |
| Formulários | React Hook Form + Zod |
| Estado do servidor | TanStack Query |
| HTTP | Axios |
| Auth | NextAuth |
| Código de API | Orval (Swagger → `src/gen/`) |
| Estado na URL | nuqs |
| Testes unitários | Vitest + React Testing Library |
| Testes E2E | Cypress |

## Como aplicar

1. Identifique o artefato pedido (componente, hook, página, formulário, listagem, filtro, teste).
2. Leia a referência certa antes de escrever código:
   - `references/patterns.md` — templates de componente, page, formulário, Orval, nuqs e testes. Abra sempre.
   - `references/ui-guidelines.md` — acessibilidade, formulários, estados de tela e textos de interface. Abra ao criar tela, formulário ou texto visível.
   - `references/performance.md` — regras de performance de React e Next. Abra ao criar listagem, importar lib pesada ou usar `useEffect`.
   - `references/security.md` — as 8 regras de segurança com exemplo certo e errado. Abra ao mexer em auth, redirect, env, HTML dinâmico ou Server Action.
3. Gere o artefato completo: `index.tsx` + `useX.tsx` + testes (`useX.test.tsx` e `index.test.tsx`).
4. Rode o Checklist de auto-revisão ao final.

## Nomenclatura

| Padrão | Convenção |
|---|---|
| Arquivos e pastas | `kebab-case` |
| Componentes React (export) | `PascalCase` |
| Hooks customizados | `use[NomePascalCase].tsx` |
| Classes e interfaces | `PascalCase` |
| Variáveis e funções | `camelCase` |
| Constantes | `SCREAMING_SNAKE_CASE` |

## Estrutura de pastas

```
components/(features)/component-name/
├── index.tsx                 # Só visual — sem lógica de negócio
├── index.test.tsx
├── useComponentName.tsx      # Toda lógica, estado e queries
└── useComponentName.test.tsx

app/(route-group)/route/
├── layout.tsx
└── page.tsx

src/gen/                      # Gerado pelo Orval — nunca editar à mão
```

## Regras críticas

- Componentes **devem** separar o visual (`index.tsx`) da lógica (`useComponentName.tsx`).
- `index.tsx` sempre começa com `'use client'` e contém só JSX.
- Formulários sempre usam React Hook Form + Zod com `zodResolver`, usando o schema gerado pelo Orval.
- Feedback ao usuário via `sonner`: `toast.loading` → `toast.success` / `toast.error` com o mesmo `id`.
- Use `cn()` de `@/lib/utils` para mesclar classes do Tailwind.
- shadcn/ui primeiro: nunca HTML cru para elementos de UI que o shadcn já cobre.
- Nunca use `any`; tipe tudo.
- `data-testid` em todo elemento interativo, para seletores estáveis nos testes.
- **Dados só via hooks gerados pelo Orval** (`src/gen/`): nada de `fetch`/axios em `useEffect`, nada de tipos de API ou schemas Zod escritos à mão. Rode `pnpm orval` quando o Swagger mudar e commite `src/gen/` junto.
- **Server Component apenas como casca de rota** (`page.tsx`, `layout.tsx`, checagem de sessão); os dados são buscados no cliente via TanStack Query.
- **Estado navegável na URL via nuqs** (filtros, busca, paginação, abas, ordenação), com parsers tipados, dentro do `useX.tsx`.
- Sem comentários que expliquem o que o código faz; comente só o porquê quando não for óbvio.

## Versões de dependências

- Esta skill não fixa versão de nenhuma biblioteca.
- Projeto novo ou dependência nova: última versão estável (nunca beta, RC ou canary).
- Depois de instalar, `pnpm audit` deve retornar zero vulnerabilidades, de qualquer severidade. Se a correção exigir major com breaking change, pare e avise o usuário.
- O lockfile é sempre commitado.
- Projeto existente: respeite as versões do `package.json`; não atualize sem pedido.

## Testes

- Todo código novo vem com testes.
- Configure `coverageThreshold` global de 80% em linhas e branches no Vitest (`coverage.thresholds`) para o CI falhar abaixo disso.
- Todo hook `useX.tsx` tem `useX.test.tsx` (`renderHook`) e todo componente tem `index.test.tsx` (React Testing Library, seletores por `getByRole`/`getByTestId`).
- Hooks e componentes que usam nuqs rodam dentro do adapter de testes do nuqs.
- Cypress cobre os fluxos principais (listar, criar, editar, excluir).

## Segurança mínima

Detalhes e exemplos em `references/security.md`.

1. Nada sensível em `NEXT_PUBLIC_*`.
2. `dangerouslySetInnerHTML` proibido (DOMPurify só se inevitável); valide o esquema de URLs em `href`/`src`.
3. `callbackUrl`/`next` só relativos ou de origem permitida (callback `redirect` do NextAuth).
4. Tokens na sessão do NextAuth (cookie httpOnly/Secure/SameSite), nunca em `localStorage`; exponha ao cliente só o necessário.
5. Autorização é do backend; esconder UI é só UX.
6. Zod valida a entrada de Server Actions e Route Handlers; Server Actions sempre checam auth.
7. Headers e CSP no `next.config`: CSP sem `unsafe-eval`, `frame-ancestors`, `nosniff`, `Referrer-Policy`.
8. Lockfile commitado, `pnpm audit` limpo, Orval gerado só do spec do nosso backend.

## Checklist de auto-revisão

- [ ] Dados vêm só de hooks de `src/gen`; nenhum tipo de API ou `fetch` escrito à mão.
- [ ] `index.tsx` sem lógica; toda lógica no `useX.tsx`.
- [ ] Estado navegável (filtro, busca, página, aba) está no nuqs.
- [ ] Loading, vazio e erro tratados em toda tela com dados.
- [ ] Acessibilidade: label em todo campo, `aria-label` em botão só com ícone, foco visível.
- [ ] Ação destrutiva protegida por `AlertDialog`.
- [ ] Nada sensível em `NEXT_PUBLIC_*` nem em `localStorage`.
- [ ] Sem `dangerouslySetInnerHTML` nem redirect aberto.
- [ ] Testes escritos e cobertura de 80% ou mais em linhas e branches.
- [ ] `pnpm audit` limpo e lockfile commitado.

Classifique cada problema como **falha** (entrada controlada por atacante + impacto concreto — corrigir antes de entregar) ou **nota de hardening** (falta de defesa em profundidade — mencionar ao usuário, sem bloquear).
