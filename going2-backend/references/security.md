# Segurança — Referência

Aplique estas regras enquanto escreve o código; o checklist de auto-revisão fica no `SKILL.md`. Classifique cada problema como **falha** (atacante controla a entrada e há impacto concreto) ou **nota de hardening** (falta de defesa em profundidade), para não bloquear a entrega por falso positivo.

## 1. Toda rota autenticada e autorizada, deny by default

Use um guard global que nega por padrão e um decorator `@Public()` explícito, com justificativa, para as raras rotas abertas. Revise também os caminhos paralelos da mesma operação (bulk, export, importação), que costumam escapar da checagem.

Autenticação global (ajuste ao boilerplate se já existir):

```typescript
export const IS_PUBLIC_KEY = 'isPublic';
export const Public = () => SetMetadata(IS_PUBLIC_KEY, true);

@Injectable()
export class JwtAuthGuard extends AuthGuard('jwt') {
  constructor(private readonly reflector: Reflector) {
    super();
  }

  canActivate(context: ExecutionContext) {
    const isPublic = this.reflector.getAllAndOverride<boolean>(IS_PUBLIC_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);
    return isPublic ? true : super.canActivate(context);
  }
}

// app.module.ts
providers: [{ provide: APP_GUARD, useClass: JwtAuthGuard }],
```

O `PoliciesGuard` depende de `req.user`, preenchido pelo `JwtAuthGuard`; guards globais rodam antes dos de controller, então a ordem já fica certa.

```typescript
// errado: rota sem guard, aberta por esquecimento
@Get('export')
exportAll() {
  return this.featureService.exportAll();
}

// certo
@Public()
@Get('health')
health() {
  return { status: 'ok' };
}

@UseGuards(PoliciesGuard)
@CheckPolicies((ability) => ability.can(Action.Read, FeatureEntity))
@Get('export')
exportAll(@CurrentUser() user: AuthUser) {
  return this.featureService.exportAll(user);
}
```

Se o projeto aplica guard por controller, nunca deixe controller sem `@UseGuards`.

## 2. IDOR: autorização na instância

Autorizar só o tipo (`ability.can(Action.Update, FeatureEntity)`) não impede que o usuário mexa no registro de outro. Filtre a busca pelo dono/tenant ou verifique a instância.

```typescript
// errado
const feature = await this.featureRepository.findOne({ where: { id } });

// certo: filtro por dono
const feature = await this.featureRepository.findOne({ where: { id, ownerId: user.id } });
if (!feature) throw new NotFoundException('Registro não encontrado');

// certo: CASL na instância (feature é um FeatureEntity carregado do banco)
if (!ability.can(Action.Update, feature)) {
  throw new NotFoundException('Registro não encontrado');
}
```

Para instância de classe da entity, o CASL detecta o tipo pelo construtor, então `ability.can(Action.Update, feature)` casa com as regras definidas contra `FeatureEntity`. Só para objeto simples (ex.: resultado de `query()` ou DTO) use `subject('Feature', plainObject)` de `@casl/ability`, com a string igual ao tipo usado ao definir a habilidade. Devolver 404 em vez de 403 evita revelar que o id existe.

## 3. Validação de entrada e campos privilegiados

Mantenha `ValidationPipe` global com `whitelist: true` e `forbidNonWhitelisted: true`. Use DTOs separados de criação e atualização, e nunca declare `role`, `ownerId` ou `isAdmin` no DTO público: esses valores vêm do token ou do service (mass assignment).

```typescript
// errado
export class CreateFeatureDto {
  @IsString({ message: 'O nome deve ser um texto' })
  name: string;

  @IsUUID('4', { message: 'Dono inválido' })
  ownerId: string;
}

// certo
export class CreateFeatureDto {
  @IsString({ message: 'O nome deve ser um texto' })
  name: string;
}

const feature = this.featureRepository.create({ ...dto, ownerId: user.id });
```

## 4. Sem interpolação em SQL

Nunca use `${}` em `query()`, `.where()` ou `orderBy`. Valores vão por parâmetro e identificadores por allowlist (detalhes em `database.md`, seção 8).

```typescript
// errado
await this.dataSource.query(`SELECT * FROM features WHERE name = '${name}'`);

// certo
await this.dataSource.query('SELECT * FROM features WHERE name = $1', [name]);
```

## 5. Respostas só via response DTO

Retorne `FeatureResponseDto.fromEntity(entity)`, nunca a entity crua. Campos sensíveis também saem da leitura padrão com `select: false`, como segunda barreira.

```typescript
@Column({ type: 'varchar', length: 255, select: false })
password: string;
```

Para ler o campo (login), peça explicitamente com `addSelect('u.password')` no QueryBuilder.

## 6. Senhas e mensagem de login genérica

Hash com argon2id (ou bcrypt com custo 12 ou mais). Responda com a mesma mensagem para usuário inexistente e senha errada, para não permitir enumeração de contas.

```typescript
const hash = await argon2.hash(password, { type: argon2.argon2id });

const user = await this.findByEmailWithPassword(dto.email);
const valid = user ? await argon2.verify(user.password, dto.password) : false;
if (!valid) throw new UnauthorizedException('Credenciais inválidas');
```

Quando o usuário não existe, ainda assim faça um `argon2.verify` contra um hash fixo para igualar o tempo de resposta (nota de hardening).

## 7. JWT

Fixe o algoritmo, valide `exp`, leia o segredo da config e nunca use `decode` sem `verify`. Quem verifica o token nas rotas é a `JwtStrategy` do Passport (não o `JwtModule`), então o algoritmo é fixado nela. No `validate()`, recarregue o usuário do banco e rejeite se ele estiver inativo ou removido.

```typescript
// errado
const payload = this.jwtService.decode(token);

// certo: emissão
JwtModule.registerAsync({
  inject: [ConfigService],
  useFactory: (config: ConfigService) => ({
    secret: config.getOrThrow<string>('JWT_SECRET'),
    signOptions: { algorithm: 'HS256', expiresIn: '15m' },
  }),
});

// certo: verificação
@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(config: ConfigService, private readonly userService: UserService) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      secretOrKey: config.getOrThrow<string>('JWT_SECRET'),
      algorithms: ['HS256'],
      ignoreExpiration: false,
    });
  }

  async validate(payload: JwtPayload): Promise<AuthUser> {
    const user = await this.userService.findActiveById(payload.sub);
    if (!user) throw new UnauthorizedException('Sessão inválida');
    return { id: user.id };
  }
}
```

`Strategy` e `ExtractJwt` vêm de `passport-jwt`; o retorno de `validate()` vira `req.user`.

## 8. Segredos só em variáveis de ambiente

Nada de chave, senha ou token no código, em exemplos ou em seed. `.env` no `.gitignore`; versionar apenas `.env.example` com valores fictícios. Leia com `config.getOrThrow` para a aplicação falhar ao subir se faltar algo.

```typescript
// errado
const secret = 'minha-chave-super-secreta';

// certo
const secret = this.config.getOrThrow<string>('JWT_SECRET');
```

## 9. Rate limit, tamanho de body e paginação com teto

Ative `ThrottlerGuard` globalmente, aperte o limite em login, reset de senha e rotas caras, limite o tamanho do body e imponha teto de paginação (100).

```typescript
ThrottlerModule.forRoot([{ ttl: 60_000, limit: 100 }]);

{ provide: APP_GUARD, useClass: ThrottlerGuard }

@Throttle({ default: { limit: 5, ttl: 60_000 } })
@Post('login')
login(@Body() dto: LoginDto) {
  return this.authService.login(dto);
}
```

```typescript
const app = await NestFactory.create<NestExpressApplication>(AppModule);
app.useBodyParser('json', { limit: '1mb' });
```

O padrão do Express é 100kb; só aumente o limite em rotas que realmente precisam. Atrás de proxy, configure `trust proxy` para o throttler enxergar o IP real.

## 10. CORS com allowlist

Liste as origens permitidas; nunca reflita o header `Origin` nem use `*` junto de `credentials: true`.

```typescript
// errado
app.enableCors({ origin: true, credentials: true });

// certo
app.enableCors({
  origin: config.getOrThrow<string>('CORS_ORIGINS').split(','),
  credentials: true,
});
```

## 11. `helmet()`

Registre `app.use(helmet())` no `main.ts`, antes das rotas. É nota de hardening quando ausente, mas custa uma linha.

## 12. Erros fail-closed

Erro inesperado responde 500 genérico, sem stack trace nem mensagem de SQL. Swagger, debug e logs verbosos ficam fechados em produção.

```typescript
// errado
catch (error) {
  throw new BadRequestException(error.message);
}

// certo
catch (error) {
  this.logger.error('Falha ao criar registro', error instanceof Error ? error.stack : undefined);
  throw new InternalServerErrorException('Não foi possível concluir a operação');
}

if (config.get<string>('NODE_ENV') !== 'production') {
  SwaggerModule.setup('api', app, document);
}
```

## 13. Logs sem dado sensível

Nunca registre senha, token, cabeçalho `Authorization` ou PII (CPF, e-mail completo, telefone). Registre eventos de autenticação (login ok/falho) e negações de acesso, com id do usuário e do recurso, para auditoria.

```typescript
// errado
this.logger.log(`Login: ${JSON.stringify(dto)}`);

// certo
this.logger.warn(`Acesso negado: user=${user.id} resource=feature:${id}`);
```

## 14. URLs e redirects do usuário por allowlist

Webhook, callback e redirect informados pelo usuário só valem se o host estiver na allowlist. Isso previne open redirect e SSRF. Parseie com `URL`, exija `https` e compare o `hostname` exato.

```typescript
// errado
await this.httpService.axiosRef.post(dto.webhookUrl, payload);

// certo
const ALLOWED_HOSTS = new Set(['hooks.partner.com', 'api.partner.com']);

private assertAllowedUrl(input: string): URL {
  let url: URL;
  try {
    url = new URL(input);
  } catch {
    throw new BadRequestException('URL inválida');
  }
  if (url.protocol !== 'https:' || !ALLOWED_HOSTS.has(url.hostname)) {
    throw new BadRequestException('Destino não permitido');
  }
  return url;
}

const url = this.assertAllowedUrl(dto.webhookUrl);
await this.httpService.axiosRef.post(url.toString(), payload, { maxRedirects: 0, timeout: 5_000 });
```

`maxRedirects: 0` é obrigatório: sem ele, um host permitido responde `302` para um IP interno e o Axios segue o redirect sem passar pela allowlist. O `timeout` impede que um destino lento segure a requisição. Para SSRF completo, também bloqueie IPs privados e de metadata da cloud na resolução de DNS.

---

Baseado em getsentry/skills security-review (OWASP, CC BY-SA 4.0), cloudflare/security-audit-skill (MIT) e kadajett/agent-nestjs-skills — conteúdo reescrito.
