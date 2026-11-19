# Padrões de Frontend

Templates com a feature genérica `Feature`. Os nomes reais dos hooks, tipos e schemas gerados vêm das tags e dos `operationId` do Swagger do backend; confira `src/gen/` antes de importar. O alias `@/` aponta para a raiz do projeto.

## Componente

Sempre dois arquivos em `components/(features)/feature-list/`.
`index.tsx` — só JSX, sem lógica:

```tsx
'use client';

import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table';
import { useFeatureList } from './useFeatureList';

export function FeatureList() {
  const list = useFeatureList();

  return (
    <section className="space-y-4">
      <Input
        type="search" name="search" aria-label="Buscar funcionalidades" placeholder="Buscar funcionalidades"
        value={list.search} onChange={(event) => list.onSearchChange(event.target.value)}
        data-testid="feature-search-input"
      />

      {list.isError ? (
        <div role="alert">
          <p>Não foi possível carregar as funcionalidades.</p>
          <Button onClick={list.onRetry} data-testid="feature-list-retry">Tentar novamente</Button>
        </div>
      ) : list.isLoading ? (
        <p aria-live="polite">Carregando…</p>
      ) : list.features.length === 0 ? (
        <p data-testid="feature-list-empty">Nenhuma funcionalidade encontrada.</p>
      ) : (
        <Table data-testid="feature-table">
          <TableHeader>
            <TableRow><TableHead>Nome</TableHead><TableHead>Status</TableHead></TableRow>
          </TableHeader>
          <TableBody>
            {list.features.map((feature) => (
              <TableRow key={feature.id} data-testid={`feature-row-${feature.id}`}>
                <TableCell>{feature.name}</TableCell>
                <TableCell>{feature.status}</TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      )}

      <nav aria-label="Paginação" className="flex items-center gap-2">
        <Button onClick={list.onPreviousPage} disabled={!list.hasPreviousPage} data-testid="feature-previous-page">Anterior</Button>
        <span>Página {list.page}</span>
        <Button onClick={list.onNextPage} disabled={!list.hasNextPage} data-testid="feature-next-page">Próxima</Button>
      </nav>
    </section>
  );
}
```

`useFeatureList.tsx` — toda a lógica; os dados vêm do hook gerado (veja [Estado na URL](#estado-na-url-nuqs) para `useFeatureFilters`):

```tsx
import { useDebouncedValue } from '@/hooks/useDebouncedValue';
import { useListFeatures } from '@/src/gen/endpoints/features/features';
import { useFeatureFilters } from './useFeatureFilters';

const PER_PAGE = 10;

export const useFeatureList = () => {
  const [filters, setFilters] = useFeatureFilters();
  const search = useDebouncedValue(filters.search, 300);
  const { data, isLoading, isError, refetch } = useListFeatures({
    page: filters.page,
    perPage: PER_PAGE,
    search: search || undefined,
    status: filters.status ?? undefined,
  });

  return {
    features: data?.data ?? [],
    page: filters.page,
    search: filters.search,
    isLoading,
    isError,
    hasPreviousPage: filters.page > 1,
    hasNextPage: filters.page * PER_PAGE < (data?.meta.total ?? 0),
    onSearchChange: (value: string) => void setFilters({ search: value, page: 1 }, { history: 'replace' }),
    onPreviousPage: () => void setFilters({ page: filters.page - 1 }),
    onNextPage: () => void setFilters({ page: filters.page + 1 }),
    onRetry: () => void refetch(),
  };
};
```
`useDebouncedValue(value, delayMs)` é um hook utilitário comum (`useState` + `setTimeout` com cleanup em `useEffect`), necessário porque a busca é feita no cliente.

## Page

`page.tsx` é Server Component e serve só de casca: checa a sessão no servidor, redireciona se não houver e renderiza o componente cliente, sem buscar dados.

```tsx
import { redirect } from 'next/navigation';
import { auth } from '@/auth';
import { FeatureList } from '@/components/(features)/feature-list';

export default async function FeaturesPage() {
  const session = await auth();
  if (!session?.user) redirect('/login');

  return (
    <main className="container py-6">
      <FeatureList />
    </main>
  );
}
```

`auth()` é a API atual do NextAuth (exportada do `auth.ts` do projeto); projeto existente com `getServerSession(authOptions)` mantém essa forma.

## Formulário

Sempre React Hook Form + o schema Zod gerado pelo Orval (`CreateFeatureBody`) + a mutation gerada (`useCreateFeature`). Os toasts usam o mesmo `id` e o texto do sucesso ecoa o verbo do botão.

`useFeatureForm.tsx`:
```tsx
import { zodResolver } from '@hookform/resolvers/zod';
import { useQueryClient } from '@tanstack/react-query';
import { useForm } from 'react-hook-form';
import { toast } from 'sonner';
import type { z } from 'zod';
import { CreateFeatureBody } from '@/src/gen/endpoints/features/features.zod';
import { getListFeaturesQueryKey, useCreateFeature } from '@/src/gen/endpoints/features/features';

type FeatureFormValues = z.infer<typeof CreateFeatureBody>;

const TOAST_ID = 'save-feature';

export const useFeatureForm = () => {
  const queryClient = useQueryClient();
  const { mutateAsync } = useCreateFeature();
  const form = useForm<FeatureFormValues>({
    resolver: zodResolver(CreateFeatureBody),
    defaultValues: { name: '' },
  });

  const onSubmit = async (values: FeatureFormValues) => {
    toast.loading('Salvando…', { id: TOAST_ID });
    try {
      await mutateAsync({ data: values });
      await queryClient.invalidateQueries({ queryKey: getListFeaturesQueryKey() });
      toast.success('Funcionalidade salva', { id: TOAST_ID });
      form.reset();
    } catch {
      toast.error('Não foi possível salvar. Tente novamente.', { id: TOAST_ID });
    }
  };

  return { form, onSubmit: form.handleSubmit(onSubmit), isSubmitting: form.formState.isSubmitting };
};
```

`index.tsx`:
```tsx
'use client';

import { Button } from '@/components/ui/button';
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage } from '@/components/ui/form';
import { Input } from '@/components/ui/input';
import { useFeatureForm } from './useFeatureForm';

export function FeatureForm() {
  const { form, onSubmit, isSubmitting } = useFeatureForm();

  return (
    <Form {...form}>
      <form onSubmit={onSubmit} className="space-y-4">
        <FormField
          control={form.control}
          name="name"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Nome</FormLabel>
              <FormControl>
                <Input autoComplete="off" data-testid="feature-form-name" {...field} />
              </FormControl>
              <FormMessage />
            </FormItem>
          )}
        />
        <Button type="submit" disabled={isSubmitting} data-testid="feature-form-submit">
          {isSubmitting ? 'Salvando…' : 'Salvar'}
        </Button>
      </form>
    </Form>
  );
}
```

As mensagens de validação vêm do schema gerado (reflexo dos decorators do backend, em português); não redeclare o schema à mão.

## Orval

O Orval lê o Swagger do backend e gera tipos, funções de API, hooks do TanStack Query e schemas Zod, com dois targets sobre o mesmo spec (client `react-query` e client `zod`), ambos em `mode: 'tags-split'`.

`orval.config.ts`:
```ts
import { defineConfig } from 'orval';

const input = { target: process.env.SWAGGER_URL ?? 'http://localhost:3000/api-json' };

export default defineConfig({
  api: {
    input,
    output: {
      mode: 'tags-split',
      client: 'react-query',
      httpClient: 'axios',
      target: './src/gen/endpoints',
      schemas: './src/gen/model',
      override: { mutator: { path: './app/services/api.ts', name: 'customInstance' } },
    },
  },
  apiZod: {
    input,
    output: {
      mode: 'tags-split',
      client: 'zod',
      target: './src/gen/endpoints',
      fileExtension: '.zod.ts',
    },
  },
});
```

O `fileExtension: '.zod.ts'` evita conflito de nome com os arquivos do client HTTP. O Swagger fica fechado em produção; gere sempre a partir do ambiente de desenvolvimento do nosso backend.

`app/services/api.ts` — o mutator recebe a config do request e devolve só o corpo da resposta:

```ts
import Axios, { type AxiosError, type AxiosRequestConfig } from 'axios';

export const AXIOS_INSTANCE = Axios.create({ baseURL: process.env.NEXT_PUBLIC_API_URL });

export const customInstance = <T>(config: AxiosRequestConfig, options?: AxiosRequestConfig): Promise<T> =>
  AXIOS_INSTANCE({ ...config, ...options }).then(({ data }) => data);

export type ErrorType<Error> = AxiosError<Error>;
```

O que é gerado e onde, com a tag `features` e operações `listFeatures` e `createFeature`:
| Arquivo | Conteúdo |
|---|---|
| `src/gen/endpoints/features/features.ts` | Funções de API e hooks: `useListFeatures`, `useCreateFeature`, `getListFeaturesQueryKey` |
| `src/gen/endpoints/features/features.zod.ts` | Schemas Zod: `CreateFeatureBody`, `ListFeaturesQueryParams`, `ListFeaturesResponse` |
| `src/gen/model/` | Tipos TypeScript dos DTOs, ex.: `FeatureResponseDto`, com `index.ts` |

Nomes dos schemas Zod: `{Operacao}Body`, `{Operacao}QueryParams`, `{Operacao}Params` (path) e `{Operacao}Response`, em PascalCase a partir do `operationId`.

### Assinatura dos hooks
- Query: `useListFeatures(params, { query })` — `params` é a query string e `query` aceita as opções do `useQuery` (`enabled`, `staleTime`, `placeholderData`).
- Mutation: `useCreateFeature()` devolve a mutation do TanStack Query; chame `mutateAsync({ data })` com o corpo tipado.
- Por causa do mutator, a resposta vem sem o envelope do Axios: `data?.data` e `data?.meta` no formato `{ data, meta: { page, perPage, total } }`.

Import correto por tag:
```ts
import { useListFeatures } from '@/src/gen/endpoints/features/features';
import { CreateFeatureBody } from '@/src/gen/endpoints/features/features.zod';
```

Nunca importe de `@/src/gen/api` nem de `api.zod`: com `tags-split` esses arquivos não existem, há um por tag. Schemas Zod são constantes, não hooks: use `CreateFeatureBody` direto no `zodResolver`.

Rode `pnpm orval` quando o Swagger do backend mudar (endpoint novo, DTO alterado, campo renomeado) e commite `src/gen/` junto com o código que usa a mudança. Nunca edite `src/gen/` à mão: a próxima geração apaga a edição.

## Estado na URL (nuqs)

Filtros, busca, paginação, abas e ordenação vivem na URL, não em `useState`. O `NuqsAdapter` entra uma vez no layout raiz.:

```tsx
// app/layout.tsx (Server Component)
import { NuqsAdapter } from 'nuqs/adapters/next/app';

<body><NuqsAdapter>{children}</NuqsAdapter></body>
```

`useFeatureFilters.tsx` agrupa os filtros com parsers tipados. Paginação usa `history: 'push'` (o voltar do navegador troca de página); busca digitada usa `'replace'` com `limitUrlUpdates: throttle(...)` para não poluir o histórico nem sobrecarregar a URL:

```tsx
import { parseAsInteger, parseAsString, parseAsStringLiteral, throttle, useQueryStates } from 'nuqs';

const FEATURE_STATUSES = ['active', 'inactive'] as const;

const featureFilters = {
  page: parseAsInteger.withDefault(1).withOptions({ history: 'push' }),
  search: parseAsString.withDefault('').withOptions({ history: 'replace', limitUrlUpdates: throttle(300) }),
  status: parseAsStringLiteral(FEATURE_STATUSES).withOptions({ history: 'push' }),
};

export const useFeatureFilters = () => useQueryStates(featureFilters);
```

Pontos de uso (`useQueryState('chave', parser)` serve para um parâmetro só; `useQueryStates` atualiza vários numa única navegação):

- Ao mudar qualquer filtro, volte `page` para 1 na mesma chamada. Como a documentação não define como `push` e `replace` por chave se resolvem num mesmo update, passe `{ history: 'replace' }` no nível da chamada ao digitar (opção de chamada vence a do parser): `setFilters({ search: value, page: 1 }, { history: 'replace' })`, já feito em `useFeatureList`.
- O estado devolvido pelo hook atualiza na hora; só a escrita na URL é limitada. Como a listagem é buscada no cliente (TanStack Query), aplique também debounce no valor enviado ao hook do Orval (`useDebouncedValue`), senão cada tecla dispara um request.
- O padrão `shallow: true` não dispara request ao servidor ao mudar a URL, o que é o desejado (os dados vêm do TanStack Query). Valor inválido na URL vira `null` ou o default; para limpar tudo, `setFilters(null)`.
- Só passe ao hook do Orval filtros que o Swagger expõe; confira `ListFeaturesQueryParams`.

## Testes

Testes ficam ao lado do código. Hooks e componentes que usam nuqs rodam no adapter de testes (`nuqs/adapters/testing`), com a URL inicial em `searchParams`; o módulo gerado do Orval é mockado com `vi.mock`, sem request real.

`useFeatureList.test.tsx`:

```tsx
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { act, renderHook } from '@testing-library/react';
import { NuqsTestingAdapter } from 'nuqs/adapters/testing';
import type { ReactNode } from 'react';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { useListFeatures } from '@/src/gen/endpoints/features/features';
import { useFeatureList } from './useFeatureList';

vi.mock('@/src/gen/endpoints/features/features', () => ({ useListFeatures: vi.fn() }));

const listResult = {
  data: { data: [], meta: { page: 1, perPage: 10, total: 25 } },
  isLoading: false, isError: false, refetch: vi.fn(),
} as unknown as ReturnType<typeof useListFeatures>;

const createWrapper = (searchParams: string) => {
  const queryClient = new QueryClient();
  return ({ children }: { children: ReactNode }) => (
    <QueryClientProvider client={queryClient}>
      <NuqsTestingAdapter searchParams={searchParams}>{children}</NuqsTestingAdapter>
    </QueryClientProvider>
  );
};

describe('useFeatureList', () => {
  beforeEach(() => vi.mocked(useListFeatures).mockReturnValue(listResult));

  it('volta para a página 1 ao buscar', async () => {
    const { result } = renderHook(() => useFeatureList(), { wrapper: createWrapper('?page=3') });
    expect(useListFeatures).toHaveBeenCalledWith(expect.objectContaining({ page: 3, perPage: 10 }));

    await act(async () => {
      result.current.onSearchChange('abc');
    });
    expect(result.current.search).toBe('abc');
    expect(result.current.hasPreviousPage).toBe(false);
  });
});
```

`index.test.tsx` — componente com React Testing Library, mockando o hook de lógica:

```tsx
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it, vi } from 'vitest';
import { FeatureList } from './index';
import { useFeatureList } from './useFeatureList';

vi.mock('./useFeatureList', () => ({ useFeatureList: vi.fn() }));

const baseState = {
  features: [], page: 1, search: '', isLoading: false, isError: false,
  hasPreviousPage: false, hasNextPage: false,
  onSearchChange: vi.fn(), onPreviousPage: vi.fn(), onNextPage: vi.fn(), onRetry: vi.fn(),
} satisfies ReturnType<typeof useFeatureList>;

describe('FeatureList', () => {
  it('chama onRetry no erro', async () => {
    const onRetry = vi.fn();
    vi.mocked(useFeatureList).mockReturnValue({ ...baseState, isError: true, onRetry });
    render(<FeatureList />);
    await userEvent.click(screen.getByRole('button', { name: 'Tentar novamente' }));
    expect(onRetry).toHaveBeenCalledOnce();
    expect(screen.queryByTestId('feature-table')).not.toBeInTheDocument();
  });
});
```

Cypress cobre os fluxos principais, sempre por `data-testid` (comando customizado `cy.login(email, password)` com cache de sessão):

```ts
// cypress/e2e/feature/feature.cy.ts
describe('Funcionalidades', () => {
  it('cria uma funcionalidade', () => {
    cy.login('admin@example.com', 'admin123');
    cy.visit('/features');
    cy.get('[data-testid="feature-form-name"]').type('Nova funcionalidade');
    cy.get('[data-testid="feature-form-submit"]').click();
    cy.contains('Funcionalidade salva').should('be.visible');
  });
});
```

`vitest.config.ts` — o `coverageThreshold` do Jest no backend equivale a `coverage.thresholds` no Vitest; o CI falha abaixo de 80% em linhas e branches:

```ts
import react from '@vitejs/plugin-react';
import { defineConfig } from 'vitest/config';

export default defineConfig({
  plugins: [react()],
  test: {
    environment: 'jsdom',
    coverage: {
      provider: 'v8',
      exclude: ['src/gen/**', '**/*.test.{ts,tsx}'],
      thresholds: { lines: 80, branches: 80 },
    },
  },
});
```

## Tailwind

Sempre `cn()` (de `@/lib/utils`) para combinar classes condicionais e a `className` recebida:
```tsx
<div className={cn('flex gap-2', isActive && 'font-semibold', className)} />
```

## Variáveis de ambiente

```env
NEXTAUTH_URL=
NEXTAUTH_SECRET=
NEXT_PUBLIC_API_URL=
SWAGGER_URL=
```

`NEXT_PUBLIC_*` é público no bundle: só URLs e flags sem segredo. `NEXTAUTH_SECRET` nunca leva o prefixo `NEXT_PUBLIC_`. Siga os nomes de variável que o projeto já usa (ex.: `AUTH_*`).

## Comandos úteis

```bash
pnpm dev              # Desenvolvimento
pnpm build && pnpm lint  # Build e lint
pnpm test             # Vitest
pnpm test --coverage  # Vitest com cobertura e thresholds
pnpm cy:run           # Cypress headless (cy:open: interativo)
pnpm orval            # Regenerar src/gen a partir do Swagger
pnpm audit            # Deve retornar zero vulnerabilidades
```
