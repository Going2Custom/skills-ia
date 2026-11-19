# Padrões de Backend — Referência

Templates com o nome genérico `Feature`. Troque pelo nome real da feature mantendo a estrutura.

## Entity

```typescript
import { EntityBase } from '@/common/entity/entity-base';
import { Column, Entity, Index, JoinColumn, ManyToOne } from 'typeorm';
import { UserEntity } from '@/users/user.entity';

@Entity('features')
@Index(['name'], { unique: true, where: '"deleted_at" IS NULL' })
export class FeatureEntity extends EntityBase {
  @Column({ length: 255 })
  name: string;

  @Column({ name: 'is_active', default: true })
  isActive: boolean;

  @Index()
  @Column({ name: 'owner_id', type: 'uuid' })
  ownerId: string;

  @ManyToOne(() => UserEntity)
  @JoinColumn({ name: 'owner_id' })
  owner: UserEntity;
}
```

- Sempre estender `EntityBase` (fornece `id`, `created_at`, `updated_at`, `deleted_at`).
- Tabela em `snake_case` e no plural; coluna com `{ name: 'snake_case' }` e propriedade em `camelCase`.
- Toda FK tem `@Index()`; unique com soft delete é parcial. Detalhes em `database.md`.

## DTOs

```typescript
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsBoolean, IsNotEmpty, IsOptional, IsString, MaxLength } from 'class-validator';

export class CreateFeatureDto {
  @ApiProperty({ maxLength: 255 })
  @IsNotEmpty({ message: 'O nome é obrigatório' })
  @IsString({ message: 'O nome deve ser um texto' })
  @MaxLength(255, { message: 'O nome deve ter no máximo 255 caracteres' })
  name: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean({ message: 'O campo ativo deve ser verdadeiro ou falso' })
  isActive?: boolean;
}
```

```typescript
import { PartialType } from '@nestjs/swagger';
import { CreateFeatureDto } from './create-feature.dto';

export class UpdateFeatureDto extends PartialType(CreateFeatureDto) {}
```

- `ownerId`, `role` e `isAdmin` nunca entram no DTO de entrada: o dono vem do usuário autenticado.
- Mensagens em português, fixas, sem interpolar input do usuário.

## Response DTO

```typescript
import { ApiProperty } from '@nestjs/swagger';
import { FeatureEntity } from '../feature.entity';

export class FeatureResponseDto {
  @ApiProperty() id: string;
  @ApiProperty() name: string;
  @ApiProperty() isActive: boolean;
  @ApiProperty() createdAt: Date;

  static fromEntity(entity: FeatureEntity): FeatureResponseDto {
    const dto = new FeatureResponseDto();
    dto.id = entity.id;
    dto.name = entity.name;
    dto.isActive = entity.isActive;
    dto.createdAt = entity.createdAt;
    return dto;
  }
}
```

Resposta paginada:

```typescript
import { ApiProperty } from '@nestjs/swagger';
import { FeatureResponseDto } from './feature-response.dto';

export class PageMetaDto {
  @ApiProperty() page: number;
  @ApiProperty() perPage: number;
  @ApiProperty() total: number;
}

export class FeaturePageResponseDto {
  @ApiProperty({ type: [FeatureResponseDto] }) data: FeatureResponseDto[];
  @ApiProperty({ type: PageMetaDto }) meta: PageMetaDto;
}
```

Liste campos explicitamente em `fromEntity`; nunca espalhe a entity (`...entity`), senão campos novos vazam sem ninguém perceber.

## Controller

```typescript
import {
  Body, Controller, Delete, Get, HttpCode, Param, ParseUUIDPipe, Post, Put, Query, UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOkResponse, ApiOperation, ApiTags } from '@nestjs/swagger';
import { PoliciesGuard } from '@/casl/guard/policies.guard';
import { CheckPolicies } from '@/casl/decorators/check-policies.decorator';
import { Action } from '@/casl/action.enum';
import { CurrentUser } from '@/auth/decorators/current-user.decorator';
import { AuthUser } from '@/auth/interfaces/auth-user.interface';
import { PageQueryDto } from '@/common/paginations/page-query.dto';
import { FeatureService } from './feature.service';
import { FeatureEntity } from './feature.entity';
import { CreateFeatureDto } from './dto/create-feature.dto';
import { UpdateFeatureDto } from './dto/update-feature.dto';
import { FeatureResponseDto } from './dto/feature-response.dto';
import { FeaturePageResponseDto } from './dto/feature-page-response.dto';

@UseGuards(PoliciesGuard)
@ApiBearerAuth()
@ApiTags('features')
@Controller('features')
export class FeatureController {
  constructor(private readonly featureService: FeatureService) {}
  @ApiOperation({ summary: 'Listar features' })
  @ApiOkResponse({ type: FeaturePageResponseDto })
  @CheckPolicies((ability) => ability.can(Action.Read, FeatureEntity))
  @Get()
  async findAll(@CurrentUser() user: AuthUser, @Query() query: PageQueryDto) {
    return this.featureService.findAll(user, query.page, query.perPage);
  }
  @ApiOperation({ summary: 'Buscar feature por id' })
  @ApiOkResponse({ type: FeatureResponseDto })
  @CheckPolicies((ability) => ability.can(Action.Read, FeatureEntity))
  @Get(':id')
  async findOne(@Param('id', ParseUUIDPipe) id: string, @CurrentUser() user: AuthUser) {
    const entity = await this.featureService.findOne(id, user);
    return FeatureResponseDto.fromEntity(entity);
  }
  @ApiOperation({ summary: 'Criar feature' })
  @ApiOkResponse({ type: FeatureResponseDto })
  @CheckPolicies((ability) => ability.can(Action.Create, FeatureEntity))
  @Post()
  async create(@Body() dto: CreateFeatureDto, @CurrentUser() user: AuthUser) {
    const entity = await this.featureService.create(dto, user);
    return FeatureResponseDto.fromEntity(entity);
  }
  @ApiOperation({ summary: 'Atualizar feature' })
  @ApiOkResponse({ type: FeatureResponseDto })
  @CheckPolicies((ability) => ability.can(Action.Update, FeatureEntity))
  @Put(':id')
  async update(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateFeatureDto,
    @CurrentUser() user: AuthUser,
  ): Promise<FeatureResponseDto> {
    const entity = await this.featureService.update(id, dto, user);
    return FeatureResponseDto.fromEntity(entity);
  }
  @ApiOperation({ summary: 'Remover feature' })
  @CheckPolicies((ability) => ability.can(Action.Delete, FeatureEntity))
  @HttpCode(204)
  @Delete(':id')
  async remove(@Param('id', ParseUUIDPipe) id: string, @CurrentUser() user: AuthUser) {
    await this.featureService.remove(id, user);
  }
}
```

Notas:

- Ajuste ao decorator do boilerplate: `@CheckPolicies`, `Action` e os caminhos de import acima seguem o formato esperado do módulo CASL; use a assinatura que o boilerplate do projeto já define.
- `@CurrentUser()` vem do módulo de auth do boilerplate (ajuste o nome se for diferente). `AuthUser` é a interface mínima do usuário autenticado: `export interface AuthUser { id: string }`.

- A política CASL decide se a ação é permitida para o tipo; a checagem de dono é feita no service, com `ownerId`.
- `PageQueryDto` usa `@Type(() => Number)`, `@IsInt()`, `@Min(1)` e `@Max(100)` em `page` e `perPage`.

## Service

```typescript
import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { AuthUser } from '@/auth/interfaces/auth-user.interface';
import { FeatureEntity } from './feature.entity';
import { CreateFeatureDto } from './dto/create-feature.dto';
import { UpdateFeatureDto } from './dto/update-feature.dto';
import { FeatureResponseDto } from './dto/feature-response.dto';
import { FeaturePageResponseDto } from './dto/feature-page-response.dto';

@Injectable()
export class FeatureService {
  constructor(
    @InjectRepository(FeatureEntity)
    private readonly repository: Repository<FeatureEntity>,
  ) {}

  async findAll(user: AuthUser, page: number, perPage: number): Promise<FeaturePageResponseDto> {
    const take = Math.min(perPage, 100);
    const [entities, total] = await this.repository.findAndCount({
      where: { ownerId: user.id },
      order: { createdAt: 'DESC', id: 'ASC' },
      skip: (page - 1) * take,
      take,
    });
    const data = entities.map((entity) => FeatureResponseDto.fromEntity(entity));
    return { data, meta: { page, perPage: take, total } };
  }

  async findOne(id: string, user: AuthUser): Promise<FeatureEntity> {
    const entity = await this.repository.findOne({ where: { id, ownerId: user.id } });
    if (!entity) throw new NotFoundException('Registro não encontrado');
    return entity;
  }

  async create(dto: CreateFeatureDto, user: AuthUser): Promise<FeatureEntity> {
    const entity = this.repository.create({ ...dto, ownerId: user.id });
    return this.repository.save(entity);
  }

  async update(id: string, dto: UpdateFeatureDto, user: AuthUser): Promise<FeatureEntity> {
    const entity = await this.findOne(id, user);
    Object.assign(entity, dto);
    return this.repository.save(entity);
  }

  async remove(id: string, user: AuthUser): Promise<void> {
    const entity = await this.findOne(id, user);
    await this.repository.softDelete(entity.id);
  }
}
```

- Registro de outro dono responde `NotFoundException`, igual a inexistente: não revela que o id existe.
- `Object.assign` só é seguro com `whitelist` ativo e DTO sem campos privilegiados.

## Module

```typescript
import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { FeatureController } from './feature.controller';
import { FeatureService } from './feature.service';
import { FeatureEntity } from './feature.entity';

@Module({
  imports: [TypeOrmModule.forFeature([FeatureEntity])],
  controllers: [FeatureController],
  providers: [FeatureService],
  exports: [FeatureService],
})
export class FeatureModule {}
```

## main.ts

```typescript
import { ValidationPipe } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { NestFactory } from '@nestjs/core';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import helmet from 'helmet';
import { AppModule } from './app.module';

async function bootstrap(): Promise<void> {
  const app = await NestFactory.create(AppModule);
  const config = app.get(ConfigService);
  app.use(helmet());
  app.enableCors({
    origin: config.getOrThrow<string>('CORS_ORIGINS').split(','),
    credentials: true,
  });
  app.useGlobalPipes(
    new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true }),
  );
  if (config.get<string>('NODE_ENV') !== 'production') {
    const swaggerConfig = new DocumentBuilder().setTitle('API').addBearerAuth().build();
    SwaggerModule.setup('docs', app, SwaggerModule.createDocument(app, swaggerConfig));
  }

  await app.listen(config.get<number>('PORT') ?? 3000);
}

bootstrap();
```

- Não ative `enableImplicitConversion` no `transform`; em DTOs de query converta explicitamente com `@Type(() => Number)`.
- `CORS_ORIGINS` é uma lista separada por vírgula; nunca `origin: true` com `credentials`. Swagger só fora de produção.

## Configuração

```typescript
import { ConfigModule } from '@nestjs/config';

export function validate(config: Record<string, unknown>): Record<string, unknown> {
  const secret = config.JWT_SECRET;
  if (typeof secret !== 'string' || secret.length < 32) {
    throw new Error('JWT_SECRET deve existir e ter ao menos 32 caracteres');
  }
  if (typeof config.CORS_ORIGINS !== 'string' || config.CORS_ORIGINS.length === 0) {
    throw new Error('CORS_ORIGINS deve existir');
  }
  return config;
}

ConfigModule.forRoot({ isGlobal: true, validate });
```

A aplicação falha no boot com configuração inválida. Estenda `validate` às demais variáveis obrigatórias.

Variáveis de ambiente:

`DATABASE_HOST`, `DATABASE_PORT`, `DATABASE_USER`, `DATABASE_PASSWORD`, `DATABASE_NAME`, `JWT_SECRET`, `JWT_EXPIRES_IN`, `CORS_ORIGINS`, `MAIL_HOST`, `MAIL_USER`, `MAIL_PASS`, `STORAGE_PROVIDER` (`gcs` ou `s3`).

## Testes

`feature.service.spec.ts`:

```typescript
import { NotFoundException } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { FeatureEntity } from './feature.entity';
import { FeatureService } from './feature.service';

type RepositoryMock = jest.Mocked<
  Pick<Repository<FeatureEntity>, 'findOne' | 'findAndCount' | 'create' | 'save' | 'softDelete'>
>;

describe('FeatureService', () => {
  let service: FeatureService;
  let repositoryMock: RepositoryMock;
  const user = { id: 'user-1' };

  beforeEach(async () => {
    repositoryMock = {
      findOne: jest.fn(), findAndCount: jest.fn(), create: jest.fn(),
      save: jest.fn(), softDelete: jest.fn(),
    };

    const moduleRef = await Test.createTestingModule({
      providers: [
        FeatureService,
        { provide: getRepositoryToken(FeatureEntity), useValue: repositoryMock },
      ],
    }).compile();

    service = moduleRef.get(FeatureService);
  });

  it('deve retornar o registro do dono', async () => {
    const entity = { id: 'feature-1', ownerId: user.id } as FeatureEntity;
    repositoryMock.findOne.mockResolvedValue(entity);

    await expect(service.findOne('feature-1', user)).resolves.toBe(entity);
    expect(repositoryMock.findOne).toHaveBeenCalledWith({
      where: { id: 'feature-1', ownerId: user.id },
    });
  });

  it('deve lançar NotFoundException quando o registro não existe', async () => {
    repositoryMock.findOne.mockResolvedValue(null);

    await expect(service.findOne('feature-1', user)).rejects.toThrow(NotFoundException);
  });

  it('deve lançar NotFoundException quando o registro pertence a outro usuário', async () => {
    repositoryMock.findOne.mockResolvedValue(null);

    await expect(service.findOne('feature-1', { id: 'user-2' })).rejects.toThrow(
      NotFoundException,
    );
  });
});
```

Esqueleto e2e (`test/feature.e2e-spec.ts`):

```typescript
import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '@/app.module';

describe('FeatureController (e2e)', () => {
  let app: INestApplication;
  let token: string;

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleRef.createNestApplication();
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true }));
    await app.init();
    token = await loginAsTestUser(app);
  });

  afterAll(() => app.close());

  it('GET /features/:id com id inválido retorna 400', async () => {
    await request(app.getHttpServer())
      .get('/features/nao-e-uuid')
      .set('Authorization', `Bearer ${token}`)
      .expect(400);
  });
});
```

`loginAsTestUser` é o helper de autenticação do projeto (gera um token válido para um usuário de teste).

Cobertura mínima no `package.json`:

```json
"jest": {
  "coverageThreshold": { "global": { "lines": 80, "branches": 80 } }
}
```

## Comandos úteis

```bash
pnpm start:dev            # servidor de desenvolvimento
pnpm build                # build
pnpm test                 # testes (Jest)
pnpm test:cov             # testes com cobertura
pnpm migration:generate   # gera migration a partir das entities
pnpm migration:run        # aplica migrations pendentes
pnpm audit                # vulnerabilidades (deve ficar zerado)
pnpm seed                 # seeders
pnpm make:entity          # scaffold de entity
```

Sem os scripts de migration no `package.json`, use a CLI do TypeORM:
`pnpm typeorm migration:generate src/database/migrations/Nome -d src/database/data-source.ts` e `pnpm typeorm migration:run -d src/database/data-source.ts`.
