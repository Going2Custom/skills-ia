# Performance — Referência

Seis regras de React e Next que pegam a maior parte dos problemas reais. Exemplos usam `Feature` genérico; os componentes completos estão em `patterns.md`.

## 1. Importe só o que usa de pacotes com muitos exports

Bibliotecas de ícones e utilitários exportam centenas de módulos; o import nomeado pode puxar tudo no dev e inflar o build. O Next resolve só os módulos usados via `optimizePackageImports`.

Conferido na documentação atual do Next: a opção continua em `experimental`, e o `lucide-react` já faz parte da lista otimizada por padrão. Então, para `lucide-react`, nenhuma configuração é necessária; use a opção para outros pacotes com muitos exports (ex.: uma lib de ícones ou utilitários interna) e confirme na documentação se o pacote já está na lista padrão.

```ts
// errado: import de barrel de um pacote fora da lista padrão, sem configurar
import { Alpha, Beta } from 'big-icon-pack';

// certo: next.config.ts
import type { NextConfig } from 'next';

const nextConfig: NextConfig = {
  experimental: {
    optimizePackageImports: ['big-icon-pack'],
  },
};

export default nextConfig;
```

Nunca troque por imports de caminho profundo (`pacote/dist/...`) só para emagrecer o bundle.

## 2. Componentes pesados com `next/dynamic`

Gráficos, editores ricos e mapas carregam sob demanda. `ssr: false` só é permitido dentro de Client Component (em Server Component o Next recusa); como todo `index.tsx` nosso já tem `'use client'`, o uso fica no componente visual.

```tsx
// errado: o gráfico entra no bundle inicial da rota
import { FeatureChart } from './feature-chart';

// certo
'use client';

import dynamic from 'next/dynamic';
import { Skeleton } from '@/components/ui/skeleton';

const FeatureChart = dynamic(() => import('./feature-chart'), {
  ssr: false,
  loading: () => <Skeleton className="h-64 w-full" />,
});
```

Use `ssr: false` só quando o componente depende de APIs do navegador (`window`); do contrário, `dynamic` sem a opção já divide o bundle e mantém o SSR. O arquivo importado precisa de `export default`.

## 3. Chamadas independentes em paralelo

Await em sequência soma as latências. Se duas chamadas não dependem uma da outra, dispare juntas. Vale para `page.tsx` server (checagem de sessão + dado de casca) e para funções de servidor em geral.

```tsx
// errado
const session = await auth();
const settings = await getSettings();

// certo
const [session, settings] = await Promise.all([auth(), getSettings()]);
```

No cliente, o TanStack Query já dispara queries do mesmo componente em paralelo; não encadeie `await` dentro de `queryFn`.

## 4. Derive no render, não com `useEffect` + `setState`

Valor que dá para calcular a partir de props, estado ou dados da query não precisa de estado próprio. O efeito causa um render extra e abre janela de valor desatualizado.

```tsx
// errado
const [fullName, setFullName] = useState('');
useEffect(() => setFullName(`${first} ${last}`), [first, last]);

// certo
const fullName = `${first} ${last}`;
```

O mesmo vale para filtrar, ordenar e contar listas: calcule no render. `useEffect` é para sincronizar com algo fora do React (listener do navegador, timer). Reação a evento do usuário vai no handler, não em efeito. E dado da API nunca é buscado em `useEffect`: use o hook gerado pelo Orval.

## 5. Nunca defina componente dentro de componente

O componente interno é recriado a cada render: o React o trata como tipo novo, desmonta e remonta a subárvore e perde estado e foco.

```tsx
// errado
export function FeatureList({ features }: FeatureListProps) {
  const Row = ({ feature }: { feature: FeatureResponseDto }) => <li>{feature.name}</li>;
  return <ul>{features.map((feature) => <Row key={feature.id} feature={feature} />)}</ul>;
}

// certo
function FeatureRow({ feature }: { feature: FeatureResponseDto }) {
  return <li>{feature.name}</li>;
}

export function FeatureList({ features }: FeatureListProps) {
  return <ul>{features.map((feature) => <FeatureRow key={feature.id} feature={feature} />)}</ul>;
}
```

## 6. Ternário em vez de `&&` com número

`0 && <X />` renderiza o `0` na tela.

```tsx
// errado: com count = 0 aparece "0"
{count && <Badge>{count}</Badge>}

// certo
{count > 0 ? <Badge>{count}</Badge> : null}
```

## 7. Passe ao cliente só os campos necessários

Props de Server Component para Client Component são serializadas no HTML; objeto inteiro vira payload maior e pode vazar campo interno. Como a casca de rota nossa não busca dados, a regra vale principalmente para o que `page.tsx` entrega (sessão, parâmetros) e para o que o `select` do Query devolve ao componente.

```tsx
// errado: a sessão inteira desce para o cliente
<FeatureList session={session} />

// certo
<FeatureList userId={session.user.id} />
```

Na lista, mapeie para o que a linha usa (`select` do TanStack Query ou o próprio DTO de resposta enxuto do backend) em vez de repassar objetos grandes por vários níveis.

## O que não usar aqui

- **SWR:** o padrão é TanStack Query via hooks do Orval.
- **Data fetching em Server Components:** dados vêm do cliente; o RSC é só a casca de rota (ver `SKILL.md`).
- **Memoização prematura:** `useMemo`, `useCallback` e `React.memo` só depois de medir um problema real no Profiler.
- **Microotimizações de JS** (trocar `map` por `for`, cachear `length`): não valem o ruído na revisão.

---

Baseado em vercel-labs/agent-skills react-best-practices (MIT) — conteúdo reescrito.
