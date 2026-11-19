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

`callbackUrl` e `next` vêm da query string e são controlados pelo atacante. Comparar prefixo (`startsWith('/')`) não basta: `/\evil.com` e `/\t/evil.com` são normalizados pelo parser de URL para `//evil.com`. Use um único helper que rejeita barra invertida e caracteres de controle, resolve a URL contra a origem e só devolve caminho local.

```ts
// lib/safe-redirect.ts
export function getSafeRedirect(raw: string, origin: string): string {
  if (/[\\\u0000-\u001f\u007f]/.test(raw)) return '/';
  try {
    const url = new URL(raw, origin);
    if (url.origin !== origin) return '/';
    return `${url.pathname}${url.search}${url.hash}`;
  } catch {
    return '/';
  }
}
```

Use o helper no callback do Auth.js, caindo para `baseUrl` quando o destino não for aceito:

```ts
// auth.ts
import { getSafeRedirect } from '@/lib/safe-redirect';

callbacks: {
  async redirect({ url, baseUrl }) {
    const safe = getSafeRedirect(url, baseUrl);
    return `${baseUrl}${safe}`;
  },
},
```

E em todo código que redireciona a partir do parâmetro:

```tsx
// errado
router.push(searchParams.get('callbackUrl') ?? '/');

// certo
router.push(getSafeRedirect(searchParams.get('callbackUrl') ?? '/', window.location.origin));
```

Conferido na documentação atual do Auth.js: a assinatura é `redirect({ url, baseUrl })` e deve retornar a URL final. O helper nunca lança, então uma URL malformada não vira erro 500.

## 4. Tokens na sessão, nunca em `localStorage`

`localStorage` é legível por qualquer script da página: um XSS leva o token. A sessão do Auth.js fica em cookie `httpOnly`, `Secure` e `SameSite`. O `accessToken` da API fica só no JWT da sessão (criptografado no cookie); o callback `session` devolve ao cliente apenas `id`, `name`, `email` e `role`, e o `role` serve só para UX (regra 5).

```ts
// errado
localStorage.setItem('token', accessToken);

// certo: auth.ts (o authorize do Credentials devolve id, role e o accessToken do login no backend)
callbacks: {
  jwt({ token, user }) {
    if (user?.id) {
      token.id = user.id;
      token.role = user.role;
      token.accessToken = user.accessToken;
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

Tipos sem `any`, por module augmentation (`types/next-auth.d.ts`):

```ts
import type { DefaultSession } from 'next-auth';
import 'next-auth/jwt';

declare module 'next-auth' {
  interface User {
    role: string;
    accessToken: string;
  }
  interface Session {
    user: { id: string; role: string } & DefaultSession['user'];
  }
}

declare module 'next-auth/jwt' {
  interface JWT {
    id: string;
    role: string;
    accessToken: string;
  }
}
```

O mutator do Axios em `patterns.md` não envia o token, e o padrão é que ele nunca chegue ao JavaScript do cliente. O cliente chama `/api/proxy/...` (mesma origem, cookie de sessão) e um Route Handler lê o JWT no servidor com `getToken` (de `next-auth/jwt`), repassando o token à API com `Authorization`. `auth()` não serve aqui: ele devolve a saída do callback `session`, que não tem o token.

```ts
// app/api/proxy/[...path]/route.ts
import { getToken } from 'next-auth/jwt';
import type { NextRequest } from 'next/server';

const DROPPED_HEADERS = ['content-encoding', 'content-length', 'transfer-encoding'];

async function proxy(request: NextRequest, { params }: { params: Promise<{ path: string[] }> }) {
  const token = await getToken({ req: request, secret: process.env.NEXTAUTH_SECRET });
  if (!token?.accessToken) return Response.json({ message: 'Não autenticado' }, { status: 401 });

  const { path } = await params;
  const headers = new Headers({ Authorization: `Bearer ${token.accessToken}` });
  const contentType = request.headers.get('content-type');
  if (contentType) headers.set('content-type', contentType);

  const upstream = await fetch(`${process.env.API_URL}/${path.join('/')}${request.nextUrl.search}`, {
    method: request.method,
    headers,
    body: ['GET', 'HEAD'].includes(request.method) ? undefined : await request.arrayBuffer(),
  });

  const responseHeaders = new Headers(upstream.headers);
  DROPPED_HEADERS.forEach((name) => responseHeaders.delete(name));
  return new Response(upstream.body, { status: upstream.status, headers: responseHeaders });
}

export { proxy as GET, proxy as POST, proxy as PUT, proxy as PATCH, proxy as DELETE };
```

Aponte o `baseURL` do `AXIOS_INSTANCE` para `/api/proxy` nesse modelo. Os headers removidos descrevem o corpo original: o `fetch` já o descomprimiu, e repassá-los quebra a resposta. Use `AUTH_SECRET` em `secret` se o projeto segue os nomes `AUTH_*`; atrás de proxy HTTPS que termina TLS, passe `secureCookie: true` se `getToken` devolver `null`. Chamadas feitas no servidor (Server Action) usam o mesmo `getToken` ou leem o token dentro do próprio handler.

**Nota de hardening (trade-off):** se o boilerplate já chama a API direto do navegador com Bearer, o token precisa estar na sessão do cliente. Isso o deixa legível por scripts da página (um XSS o leva), então prefira o proxy. Se mantiver o interceptor, o callback `session` passa a repassar `session.accessToken = token.accessToken` (declare `accessToken` também em `Session`), e a sessão é cacheada em vez de buscada a cada request:

```ts
import { getSession } from 'next-auth/react';

let cachedToken: string | undefined;
let cachedAt = 0;
const TOKEN_TTL_MS = 60_000;

AXIOS_INSTANCE.interceptors.request.use(async (config) => {
  if (Date.now() - cachedAt > TOKEN_TTL_MS) {
    cachedToken = (await getSession())?.accessToken;
    cachedAt = Date.now();
  }
  if (cachedToken) config.headers.Authorization = `Bearer ${cachedToken}`;
  return config;
});
```

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

Configure em `next.config.ts`. A CSP não usa `unsafe-eval` em produção, bloqueia plugins (`object-src 'none'`), impede embutir o site em iframe (`frame-ancestors 'none'`) e limita origens.

```ts
import type { NextConfig } from 'next';

const isDev = process.env.NODE_ENV === 'development';

const contentSecurityPolicy = [
  "default-src 'self'",
  `script-src 'self' 'unsafe-inline'${isDev ? " 'unsafe-eval'" : ''}`,
  "style-src 'self' 'unsafe-inline'",
  "img-src 'self' data: blob:",
  `connect-src 'self' ${process.env.NEXT_PUBLIC_API_URL ?? ''}`,
  "object-src 'none'",
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

Os mesmos headers valem no `next dev`, e as ferramentas de desenvolvimento do React precisam de `'unsafe-eval'`; por isso ele entra em `script-src` só quando `isDev` é verdadeiro e nunca no build de produção. Se `img-src` precisar de imagens externas (CDN, avatar), liste cada host explicitamente.

O `'unsafe-inline'` em `script-src` é o ponto de partida porque o Next injeta scripts inline; endureça com CSP por nonce (middleware gerando o nonce e lendo `x-nonce` no layout) assim que o projeto permitir, e trate isso como nota de hardening. Libere só as origens externas realmente usadas (analytics, fontes). Valide a CSP final com `pnpm build && pnpm start`.

## 8. Dependências e código gerado

- Lockfile (`pnpm-lock.yaml`) sempre commitado; instale com `pnpm install --frozen-lockfile` no CI.
- `pnpm audit` com zero vulnerabilidades, de qualquer severidade, antes de entregar. Se a correção exigir major com breaking change, pare e avise.
- Antes de adicionar pacote: nome correto (cuidado com typosquatting), mantido e realmente necessário. Nada de `postinstall` desconhecido.
- Orval gera só do Swagger do nosso backend (`SWAGGER_URL` apontando para o nosso ambiente de desenvolvimento); nunca de um spec de terceiros ou de arquivo que alguém colou. Revise o diff de `src/gen/` no PR.

---

Baseado em getsentry/skills security-review (OWASP, CC BY-SA 4.0) e cloudflare/security-audit-skill (MIT) — conteúdo reescrito.
