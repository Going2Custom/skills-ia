# Banco de Dados — Referência

Regras de TypeORM + PostgreSQL para entities, queries e migrations. Templates completos de entity, service e módulo ficam em `patterns.md`; aqui estão só as decisões de banco.

## 1. Índice em toda FK

**Regra:** toda coluna de chave estrangeira recebe `@Index()`.
**Motivo:** o PostgreSQL não cria índice em FK automaticamente, e joins e filtros por dono viram varredura da tabela inteira.

```typescript
@Entity('feature')
export class FeatureEntity extends EntityBase {
  @Index()
  @Column({ name: 'owner_id', type: 'uuid' })
  ownerId: string;

  @ManyToOne(() => UserEntity, { nullable: false })
  @JoinColumn({ name: 'owner_id' })
  owner: UserEntity;
}
```

## 2. Unique parcial com soft delete

**Regra:** unicidade em tabela com soft delete usa índice parcial que ignora registros removidos.
**Motivo:** um unique comum impede recadastrar o e-mail de um registro apagado logicamente.

```typescript
@Entity('user')
@Index(['email'], { unique: true, where: '"deleted_at" IS NULL' })
export class UserEntity extends EntityBase {
  @Column({ type: 'varchar', length: 255 })
  email: string;
}
```

## 3. Datas em `timestamptz`

**Regra:** colunas de data usam `timestamptz`, inclusive no `EntityBase`.
**Motivo:** `timestamp` não guarda fuso e gera horários errados quando o servidor ou o cliente mudam de timezone.

```typescript
export abstract class EntityBase {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt: Date;

  @DeleteDateColumn({ name: 'deleted_at', type: 'timestamptz' })
  deletedAt?: Date;
}
```

Se o `EntityBase` do projeto usa `timestamp`, gerar migration para converter (`ALTER COLUMN ... TYPE timestamptz USING ... AT TIME ZONE 'UTC'`), informando o fuso em que os dados antigos foram gravados.

## 4. Relações carregadas explicitamente

**Regra:** carregue relações no ponto de uso com `relations` ou `leftJoinAndSelect`; `eager: true` e relações lazy são proibidos.
**Motivo:** eager faz toda query trazer joins que quase ninguém usa, e lazy esconde N+1 atrás de um `await` em propriedade.

```typescript
// errado
@ManyToOne(() => UserEntity, { eager: true })
owner: UserEntity;

// certo
const feature = await this.featureRepository.findOne({
  where: { id, ownerId: user.id },
  relations: { owner: true },
});

const features = await this.featureRepository
  .createQueryBuilder('f')
  .leftJoinAndSelect('f.owner', 'o')
  .where('f.ownerId = :ownerId', { ownerId: user.id })
  .getMany();
```

## 5. Paginação com teto e ordem determinística

**Regra:** toda listagem usa `take` com máximo de 100 e `order` explícito, com a PK como desempate.
**Motivo:** sem teto, um cliente pede a tabela inteira; sem ordem determinística, páginas repetem ou perdem linhas.

```typescript
const MAX_PER_PAGE = 100;

const take = Math.min(perPage, MAX_PER_PAGE);
const [items, total] = await this.featureRepository.findAndCount({
  where: { ownerId: user.id },
  order: { createdAt: 'DESC', id: 'ASC' },
  take,
  skip: (page - 1) * take,
});
```

Valide `perPage` também no DTO (`@Max(100)`); o `Math.min` é a segunda barreira.

## 6. Transações curtas com `manager`

**Regra:** use `dataSource.transaction` e, lá dentro, apenas o `manager` recebido; chamadas externas (gateway, e-mail, HTTP) ficam fora.
**Motivo:** repositórios injetados rodam fora da transação e quebram a atomicidade; chamada externa lenta segura conexão e locks.

```typescript
const order = await this.dataSource.transaction(async (manager) => {
  const created = await manager.save(OrderEntity, orderData);
  await manager.save(
    OrderItemEntity,
    items.map((item) => ({ ...item, orderId: created.id })),
  );
  return created;
});
await this.paymentGateway.charge(order.id);
```

- Dentro da transação use só `manager`, nunca os repositórios injetados; chamadas externas ficam fora.
- Se a chamada externa falhar, trate a compensação (cancelar o pedido) explicitamente no service.

## 7. Migrations: `synchronize: false` e `down()`

**Regra:** `synchronize: false` em todos os ambientes, `migrationsRun` ativo no deploy e `down()` implementado em toda migration.
**Motivo:** `synchronize` pode apagar colunas e dados sem aviso, e migration sem `down()` impede o rollback.

```typescript
TypeOrmModule.forRootAsync({
  inject: [ConfigService],
  useFactory: (config: ConfigService) => ({
    type: 'postgres',
    url: config.getOrThrow<string>('DATABASE_URL'),
    autoLoadEntities: true,
    synchronize: false,
    migrationsRun: true,
    migrations: [join(__dirname, 'migrations', '*.js')],
  }),
});
```

```typescript
export class AddFeatureOwnerIndex1700000000000 implements MigrationInterface {
  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query('CREATE INDEX "IDX_feature_owner_id" ON "feature" ("owner_id")');
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query('DROP INDEX "IDX_feature_owner_id"');
  }
}
```

Gere a migration com a CLI do TypeORM e revise o SQL antes de commitar. Em tabela grande, índice novo em produção pede `CREATE INDEX CONCURRENTLY` (e `transaction = false` na migration).

## 8. QueryBuilder parametrizado e identificadores por allowlist

**Regra:** valores entram sempre como parâmetro (`:name`); nome de coluna e direção de ordenação vêm de allowlist, nunca direto do input.
**Motivo:** parâmetros só protegem valores; um identificador interpolado continua sendo SQL injection.

```typescript
// errado
qb.where(`f.name = '${name}'`).orderBy(`f.${sortBy}`, direction);

// certo
const SORTABLE = ['name', 'createdAt'] as const;
type SortableField = (typeof SORTABLE)[number];

const field: SortableField = SORTABLE.find((item) => item === sortBy) ?? 'createdAt';
const order = direction === 'ASC' ? 'ASC' : 'DESC';

qb.where('f.name = :name', { name }).orderBy(`f.${field}`, order);
```

O template string no `orderBy` acima é seguro porque `field` só pode ser um item da allowlist. Prefira também validar `sortBy` no DTO com `@IsIn(SORTABLE)`.

## Fora do escopo

Tuning de queries e de configuração do PostgreSQL, replicação, WAL, particionamento e backup são assunto de quem cuida do banco. Se a tarefa pedir isso, avise o usuário e peça apoio dessa pessoa.
