# Guia de interface — Referência

Regras de acessibilidade, formulários, estados de tela e textos para toda tela da Going2. Os componentes de exemplo (`FeatureList`, `FeatureForm`) estão em `patterns.md`; aqui ficam só os pontos de interface.

## 1. Acessibilidade

- Botão só com ícone leva `aria-label` descritivo, e o ícone fica oculto para leitores de tela.

```tsx
// errado
<Button size="icon"><Trash2 /></Button>

// certo
<Button size="icon" aria-label="Excluir funcionalidade" data-testid="feature-delete">
  <Trash2 aria-hidden />
</Button>
```

- Todo campo tem `<Label>` associado (`FormLabel` dentro do `FormField` do shadcn já faz a ligação). Placeholder não substitui label.
- `<button>` (ou `Button`) para ação; `<Link>` do Next para navegação. Nunca `<div onClick>`.
- Foco visível sempre. Nunca `outline-none` sozinho: troque por `focus-visible:ring-2 focus-visible:ring-ring`.
- Mensagens que aparecem sem ação do usuário (erro de busca, resultado de filtro) ficam em região com `aria-live="polite"`; erros que interrompem usam `role="alert"`.
- Imagens informativas têm `alt`; decorativas usam `alt=""`.
- Hierarquia de títulos sem pular nível (`h1` → `h2` → `h3`), um `h1` por página.

## 2. Formulários

- Todo `Input` declara `name`, `type` e `autoComplete` (atributo HTML `autocomplete`) corretos: `email`, `current-password`, `new-password`, `tel`, `name`. Para campos que o navegador não deve sugerir (ex.: nome de uma funcionalidade), use `autoComplete="off"`.
- `inputMode` para teclado certo no celular (`numeric`, `decimal`); `type="number"` só para quantidades, nunca para CPF, CNPJ ou telefone.
- Nunca bloqueie colar (`onPaste` com `preventDefault`), nem em senha ou confirmação de e-mail.
- Botão de envio fica habilitado até o envio começar; só então `disabled={isSubmitting}`. Validação inválida não desabilita o botão: mostre o erro.
- Erro aparece ao lado do campo (`FormMessage`), com texto que diz como corrigir.
- Ao enviar com erro, foque o primeiro campo inválido. O React Hook Form faz isso por padrão (`shouldFocusError: true`); não desligue.
- Formulário com alterações não salvas avisa antes de sair:

```tsx
useEffect(() => {
  if (!form.formState.isDirty) return;
  const handler = (event: BeforeUnloadEvent) => event.preventDefault();
  window.addEventListener('beforeunload', handler);
  return () => window.removeEventListener('beforeunload', handler);
}, [form.formState.isDirty]);
```

Este `useEffect` sincroniza com um sistema externo (o navegador), por isso é legítimo; veja `performance.md` para os usos que não são.

## 3. Estados de tela

Toda tela com dados trata os quatro estados; nunca renderize só o caminho feliz.

| Estado | O que mostrar |
|---|---|
| Carregando | `Skeleton` com o formato do conteúdo, nunca tela em branco |
| Erro | Mensagem clara e botão "Tentar novamente" ligado ao `refetch` |
| Vazio | Texto explicando e ação para sair do vazio |
| Com dados | Conteúdo; paginação e filtros visíveis |

```tsx
{list.isEmpty && (
  <div className="flex flex-col items-center gap-2 py-12" data-testid="feature-list-empty">
    <p>Nenhuma funcionalidade ainda.</p>
    <Button onClick={list.onCreate} data-testid="feature-list-create">Criar funcionalidade</Button>
  </div>
)}
```

Se o vazio vem de um filtro ativo, diga isso e ofereça "Limpar filtros" em vez de "Criar".

## 4. Ações destrutivas

Excluir, arquivar e qualquer ação irreversível passam por `AlertDialog` do shadcn antes de executar. O texto nomeia o item e o botão de confirmação repete o verbo.

```tsx
<AlertDialog>
  <AlertDialogTrigger asChild>
    <Button variant="destructive" data-testid="feature-delete">Excluir</Button>
  </AlertDialogTrigger>
  <AlertDialogContent>
    <AlertDialogHeader>
      <AlertDialogTitle>Excluir funcionalidade?</AlertDialogTitle>
      <AlertDialogDescription>
        A funcionalidade "{feature.name}" será excluída e não poderá ser recuperada.
      </AlertDialogDescription>
    </AlertDialogHeader>
    <AlertDialogFooter>
      <AlertDialogCancel>Cancelar</AlertDialogCancel>
      <AlertDialogAction onClick={onConfirmDelete} data-testid="feature-delete-confirm">
        Excluir
      </AlertDialogAction>
    </AlertDialogFooter>
  </AlertDialogContent>
</AlertDialog>
```

Nunca use `window.confirm`. Ação reversível (ex.: desfazer logo após arquivar) pode usar toast com "Desfazer" no lugar do diálogo.

## 5. Formatação

Datas, números e moeda sempre com `Intl` e `pt-BR`. Nada de formatar com template string ou `toFixed`.

```ts
const currency = new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' });
const date = new Intl.DateTimeFormat('pt-BR', { dateStyle: 'short' });

currency.format(1234.5);
date.format(new Date(feature.createdAt));
```

- Crie o formatter fora do componente (ou em módulo `lib/format.ts`) para não recriar a cada render.
- A API devolve datas em ISO 8601 UTC; converta só na exibição.
- Textos de interface em português; nomes de código em inglês.

## 6. Movimento

- Nunca `transition: all` (`transition-all` no Tailwind): liste as propriedades (`transition-colors`, `transition-opacity`).
- Respeite `prefers-reduced-motion`: animações decorativas ficam atrás de `motion-safe:` ou são desligadas com `motion-reduce:`.

```tsx
<div className="motion-safe:animate-in motion-safe:fade-in motion-reduce:animate-none" />
```

- Anime só `transform` e `opacity`; duração curta (até 200–300 ms) para feedback de interação.
- Spinner de loading pode girar, mas o estado também precisa de texto ou `aria-label` ("Carregando").

## 7. Textos de interface

- Botão com verbo específico e objeto: nada de "Enviar", "OK" ou "Sim".
- O toast de sucesso ecoa o verbo do botão: "Salvar" → "Salvo", "Excluir" → "Excluído".
- Erro diz o que houve e como corrigir; nunca "Erro!" nem código técnico.
- Sentence case: só a primeira letra maiúscula ("Criar funcionalidade", não "Criar Funcionalidade").
- Reticências `…` em ações que abrem outra etapa ("Filtrar…") e em loading ("Salvando…").

| Errado | Certo |
|---|---|
| `Enviar` | `Salvar alterações` |
| `Erro!` | `Não foi possível salvar. Verifique a conexão e tente novamente.` |
| `Sem dados` | `Nenhuma funcionalidade ainda. Criar funcionalidade` |
| `Tem certeza?` | `Excluir funcionalidade?` |
| `Campo inválido` | `Informe um e-mail no formato nome@empresa.com.br` |

---

Baseado em vercel-labs/web-interface-guidelines (MIT) e anthropics/skills frontend-design (Apache-2.0) — conteúdo reescrito.
