# Segurança — Referência

Aplique estas regras enquanto escreve o código; o checklist de auto-revisão fica no `SKILL.md`. Classifique cada problema como **falha** (atacante controla a entrada e há impacto concreto) ou **nota de hardening** (falta de defesa em profundidade), para não bloquear a entrega por falso positivo.

## 1. Nada sensível em `NEXT_PUBLIC_*`

Toda variável com esse prefixo é embutida no bundle e visível a qualquer visitante. Só URLs públicas e flags sem segredo.

```env
# certo
NEXT_PUBLIC_API_URL=https://api.example.com

# errado: chave secreta exposta no navegador
NEXT_PUBLIC_STRIPE_SECRET=sk_live_...
```

Segredos ficam sem prefixo, lidos só em código de servidor (`auth.ts`, Route Handlers, Server Actions). `.env*` com valores reais no `.gitignore`; commite apenas `.env.example`. Credenciais de teste (Cypress, Vitest) vêm de env (`Cypress.env('E2E_PASSWORD')`), nunca escritas no código.

## 2. HTML dinâmico e URLs

`dangerouslySetInnerHTML` é proibido. O React já escapa texto; renderize como texto. Se o HTML for inevitável (conteúdo rico vindo de editor), sanitize com DOMPurify e registre o motivo na revisão.

```tsx
// errado: XSS com qualquer comentário
<div dangerouslySetInnerHTML={{ __html: comment }} />

// certo
<p>{comment}</p>
```

URL vinda de dado (perfil, link cadastrado) em `href`/`src` aceita só esquemas conhecidos; `javascript:` executa código ao clicar.

```ts
const SAFE_PROTOCOLS = new Set(['http:', 'https:', 'mailto:']);

export function isSafeHref(url: string): boolean {
  try {
    return SAFE_PROTOCOLS.has(new URL(url).protocol);
  } catch {
    return false;
  }
}
```

```tsx
{isSafeHref(feature.website) ? <a href={feature.website} rel="noopener noreferrer">Site</a> : null}
```

## 3. Redirect só para destino permitido

`callbackUrl` e `next` vêm da query string e são controlados pelo atacante. Aceite só caminho relativo ou a própria origem, tanto no Auth.js quanto no código que redireciona.

```ts
// auth.ts
callbacks: {
  async redirect({ url, baseUrl }) {
    if (url.startsWith('/') && !url.startsWith('//')) return `${baseUrl}${url}`;
    if (new URL(url).origin === baseUrl) return url;
    return baseUrl;
  },
},
```

Ao usar o parâmetro manualmente, valide com a mesma regra:

```tsx
// errado
router.push(searchParams.get('callbackUrl') ?? '/');

// certo
const callbackUrl = searchParams.get('callbackUrl');
const target = callbackUrl?.startsWith('/') && !callbackUrl.startsWith('//') ? callbackUrl : '/';
router.push(target);
```

Conferido na documentação atual do Auth.js: a assinatura é `redirect({ url, baseUrl })` e deve retornar a URL final.

## 4. Tokens na sessão, nunca em `localStorage`

`localStorage` é legível por qualquer script da página: um XSS leva o token. A sessão do Auth.js fica em cookie `httpOnly`, `Secure` e `SameSite`. Exponha ao cliente só o necessário no callback `session`.

```ts
// errado
localStorage.setItem('token', accessToken);

// certo: auth.ts
callbacks: {
  jwt({ token, user }) {
    if (user) {
      token.id = user.id;
      token.role = user.role;
    }
    return token;
  },
  session({ session, token }) {
    session.user.id = token.id;
    session.user.role = token.role;
    return session;
  },
},
```

O `session` devolve para o cliente só `id`, `name`, `email` e `role`. O `role` serve apenas para UX (regra 5). O mutator do Axios em `patterns.md` não envia o token; o jeito mais simples é um interceptor que lê a sessão com `getSession()` (de `next-auth/react`):

```ts
import { getSession } from 'next-auth/react';

AXIOS_INSTANCE.interceptors.request.use(async (config) => {
  const session = await getSession();
  if (session?.accessToken) config.headers.Authorization = `Bearer ${session.accessToken}`;
  return config;
});
```

Isso exige que o callback `session` repasse `accessToken` ao cliente, o que o deixa legível por scripts da página (mas não persistido em storage). Se o projeto puder, prefira um Route Handler/proxy no servidor que lê o token com `auth()` e chama a API, mantendo o token fora do JS do cliente. Ajuste ao boilerplate do projeto.

## 5. Autorização é do backend

Esconder botão, item de menu ou página por `role` é só UX. Toda regra de permissão é imposta pela API (CASL); o frontend nunca é a barreira.

```tsx
// UX: ok esconder, mas não proteger
{session.user.role === 'admin' ? <DeleteFeatureButton /> : null}
```

Nunca confie em `role`, `isAdmin` ou `ownerId` vindos do cliente, nem em checagem feita só em `middleware`/layout. Trate `401` e `403` da API (redirecionar para login, mostrar "Você não tem permissão para esta ação").

## 6. Server Actions e Route Handlers: auth e Zod

Server Action é endpoint público: qualquer um pode chamá-la com qualquer entrada. Cheque a sessão e valide com Zod antes de tocar em dado.

```ts
'use server';

import { auth } from '@/auth';
import { CreateFeatureBody } from '@/src/gen/endpoints/features/features.zod';

export async function createFeatureAction(input: unknown) {
  const session = await auth();
  if (!session) throw new Error('Não autenticado');

  const data = CreateFeatureBody.parse(input);
  return saveFeature(session.user.id, data);
}
```

Em Route Handler, use `safeParse` e responda `400` com mensagem em português; sem sessão, `401`. Reutilize o schema gerado pelo Orval; não escreva outro à mão.

## 7. Headers de segurança e CSP

Configure em `next.config.ts`. A CSP não usa `unsafe-eval`, bloqueia embutir o site em iframe (`frame-ancestors 'none'`) e limita origens.

```ts
import type { NextConfig } from 'next';

const contentSecurityPolicy = [
  "default-src 'self'",
  "script-src 'self' 'unsafe-inline'",
  "style-src 'self' 'unsafe-inline'",
  "img-src 'self' data: blob:",
  `connect-src 'self' ${process.env.NEXT_PUBLIC_API_URL ?? ''}`,
  "frame-ancestors 'none'",
  "base-uri 'self'",
  "form-action 'self'",
].join('; ');

const nextConfig: NextConfig = {
  async headers() {
    return [
      {
        source: '/(.*)',
        headers: [
          { key: 'Content-Security-Policy', value: contentSecurityPolicy },
          { key: 'X-Content-Type-Options', value: 'nosniff' },
          { key: 'Referrer-Policy', value: 'strict-origin-when-cross-origin' },
        ],
      },
    ];
  },
};

export default nextConfig;
```

O `'unsafe-inline'` em `script-src` é o ponto de partida porque o Next injeta scripts inline; endureça com CSP por nonce (middleware gerando o nonce e lendo `x-nonce` no layout) assim que o projeto permitir, e trate isso como nota de hardening. Libere só as origens externas realmente usadas (analytics, fontes). Teste em `pnpm build && pnpm start`, pois o dev usa regras mais frouxas.

## 8. Dependências e código gerado

- Lockfile (`pnpm-lock.yaml`) sempre commitado; instale com `pnpm install --frozen-lockfile` no CI.
- `pnpm audit` com zero vulnerabilidades, de qualquer severidade, antes de entregar. Se a correção exigir major com breaking change, pare e avise.
- Antes de adicionar pacote: nome correto (cuidado com typosquatting), mantido e realmente necessário. Nada de `postinstall` desconhecido.
- Orval gera só do Swagger do nosso backend (`SWAGGER_URL` apontando para o nosso ambiente de desenvolvimento); nunca de um spec de terceiros ou de arquivo que alguém colou. Revise o diff de `src/gen/` no PR.

---

Baseado em getsentry/skills security-review (OWASP, CC BY-SA 4.0) e cloudflare/security-audit-skill (MIT) — conteúdo reescrito.
