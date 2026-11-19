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
