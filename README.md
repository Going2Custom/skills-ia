# Going2 — Skills IA

Skills do Claude Code com os padrões de desenvolvimento da Going2. Instale em qualquer projeto para que o Claude gere código consistente com a stack e convenções da empresa.

## Skills disponíveis

| Skill | Descrição |
|---|---|
| `nestjs-standards` | Padrões de backend: entidades, DTOs, services, controllers, módulos |
| `nextjs-standards` | Padrões de frontend: componentes, hooks, páginas, formulários, testes |
| `company-standards` | As duas skills acima em um único pacote |

---

## Instalação

### Pré-requisito

Ter o [Claude Code](https://claude.ai/code) instalado.

---

### Via skills.sh (recomendado)

O [skills.sh](https://skills.sh) é um marketplace de skills para agentes de IA. Use o comando abaixo para instalar diretamente do repositório:

**Backend (NestJS)**
```bash
npx skills add Going2Custom/skills-ia/nestjs-standards
```

**Frontend (Next.js)**
```bash
npx skills add Going2Custom/skills-ia/nextjs-standards
```

**Ambos (pacote completo)**
```bash
npx skills add Going2Custom/skills-ia/company-standards
```

---

### Via Claude Code CLI

**Backend (NestJS)**
```bash
claude skill install https://raw.githubusercontent.com/Going2Custom/skills-ia/main/nestjs-standards.skill
```

**Frontend (Next.js)**
```bash
claude skill install https://raw.githubusercontent.com/Going2Custom/skills-ia/main/nextjs-standards.skill
```

**Ambos (pacote completo)**
```bash
claude skill install https://raw.githubusercontent.com/Going2Custom/skills-ia/main/company-standards.skill
```

---

## Como funciona

Após instalar, o Claude passa a aplicar automaticamente os padrões da empresa ao gerar código. Não é necessário nenhum comando especial — basta pedir normalmente:

> "Cria um módulo de produtos no backend"
> "Cria um componente de listagem de pedidos"
> "Cria um formulário de cadastro de cliente"

O Claude vai seguir a estrutura de pastas, nomenclatura, padrões de entidade, DTO, controller, service, hooks, formulários e testes definidos nas skills.

---

## Stack coberta

### Backend
- NestJS 11+ / TypeScript 5+
- TypeORM + PostgreSQL
- JWT + Passport + CASL
- class-validator + class-transformer
- @nestjs/swagger

### Frontend
- Next.js 16+ (App Router) / TypeScript 5+
- shadcn/ui + Radix UI + Tailwind CSS 4+
- React Hook Form + Zod
- TanStack Query
- NextAuth.js
- Vitest + Cypress

---

## Estrutura do repositório

```
.claude/skills/
├── company-standards/   # Fonte da skill completa
├── nestjs-standards/    # Fonte da skill de backend
└── nextjs-standards/    # Fonte da skill de frontend
*.skill                  # Pacotes prontos para instalação
```
