# ER-диаграмма базы данных

## Описание схемы

База данных состоит из следующих основных сущностей:

### Пользователи и клиенты

- **users** - Пользователи системы (администраторы, менеджеры, специалисты, клиенты)
- **clients** - Клиенты (компании, для которых формируются требования)
- **categories** - Категории НВОС (I, II, III, IV)

### Основные сущности

- **requirements** - Экологические требования (формируются автоматически на основе категории клиента)
- **documents** - Документы клиентов (разрешения, отчёты, паспорта и т.д.)
- **contracts** - Договоры и акты
- **events** - События календаря отчётности
- **risks** - Риски по КоАП для требований

### Аудит

- **audit_log** - Лог действий пользователей для аудита

## Связи

```
users (1) ──< (N) clients
clients (1) ──< (N) requirements
clients (1) ──< (N) documents
clients (1) ──< (N) contracts
clients (1) ──< (N) events
requirements (1) ──< (N) risks
categories (1) ──< (N) clients
users (1) ──< (N) audit_log
```

## Таблицы

### users
- id (PK)
- name
- email (UNIQUE)
- password_hash
- role (admin, manager, specialist, client)
- client_id (FK -> clients.id)
- auth_key
- created_at
- updated_at

### categories
- id (PK)
- title
- description

### clients
- id (PK)
- name
- category_id (FK -> categories.id)
- has_well (boolean)
- has_river (boolean)
- has_byproduct (boolean)
- created_at
- updated_at

### requirements
- id (PK)
- client_id (FK -> clients.id)
- title
- status (pending, in_progress, completed, not_completed)
- deadline (date)
- created_at
- updated_at

### documents
- id (PK)
- client_id (FK -> clients.id)
- file_path
- type
- status (pending, approved, rejected)
- created_at
- updated_at

### contracts
- id (PK)
- client_id (FK -> clients.id)
- number
- status (draft, active, completed, cancelled)
- date
- created_at
- updated_at

### events
- id (PK)
- client_id (FK -> clients.id)
- title
- date
- completed (boolean)
- created_at
- updated_at

### risks
- id (PK)
- requirement_id (FK -> requirements.id)
- article (статья КоАП)
- fine_min
- fine_max

### audit_log
- id (PK)
- user_id (FK -> users.id)
- entity_type
- entity_id
- action
- timestamp

## Индексы

- users.email (UNIQUE)
- users.client_id
- clients.category_id
- requirements.client_id
- documents.client_id
- contracts.client_id
- events.client_id, events.date
- risks.requirement_id
- audit_log.user_id
- audit_log.entity_type, audit_log.entity_id

