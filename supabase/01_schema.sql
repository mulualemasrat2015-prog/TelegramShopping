-- Phase 1 tables (foundation). Run once in the Supabase SQL editor.
create extension if not exists pgcrypto;

create table users (
  id uuid primary key default gen_random_uuid(),
  telegram_id bigint unique not null,
  first_name text, username text, language text,
  created_at timestamptz default now()
);

create table shops (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid references users(id),
  name text not null,
  slug text unique not null,
  logo_url text, description text,
  status text not null default 'trial' check (status in ('trial','active','paused','suspended')),
  default_language text default 'en',
  currency text default 'ETB',
  verified boolean default false,
  created_at timestamptz default now()
);

-- Development only: the token is stored as plain text here.
-- Before launch, encrypt it (Supabase Vault or app-level encryption).
create table shop_bots (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid unique not null references shops(id) on delete cascade,
  telegram_bot_id bigint, bot_username text,
  token text not null,
  created_via text default 'manual',
  status text default 'active'
);

create table shop_themes (
  shop_id uuid primary key references shops(id) on delete cascade,
  preset text default 'clean',
  primary_color text default '#1F6F54',
  font text default 'modern',
  corner_radius text default 'soft',
  layout text default 'grid',
  banner_url text,
  home_blocks jsonb default '[]'
);

create table customers (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references shops(id) on delete cascade,
  user_id uuid not null references users(id) on delete cascade,
  phone text,
  marketing_opt_in boolean default false,
  blocked boolean default false,
  created_at timestamptz default now(),
  unique (shop_id, user_id)
);

create table categories (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references shops(id) on delete cascade,
  name text not null, sort_order int default 0
);

create table products (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references shops(id) on delete cascade,
  category_id uuid references categories(id) on delete set null,
  title text not null, description text,
  price numeric(12,2) not null,
  compare_at_price numeric(12,2),
  status text not null default 'draft' check (status in ('draft','active','sold_out')),
  track_stock boolean default true,
  stock_qty int default 0,
  source text default 'dashboard',
  created_at timestamptz default now()
);
create index products_shop_idx on products(shop_id);

create table product_media (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references products(id) on delete cascade,
  url text not null, type text default 'image', sort_order int default 0
);

-- Row-level security on, with no public policies: only the server (secret key) can read or write.
alter table users enable row level security;
alter table shops enable row level security;
alter table shop_bots enable row level security;
alter table shop_themes enable row level security;
alter table customers enable row level security;
alter table categories enable row level security;
alter table products enable row level security;
alter table product_media enable row level security;

-- ===== Remaining tables =====


create table shop_channels (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references shops(id) on delete cascade,
  telegram_channel_id bigint, title text,
  bot_is_admin boolean default false
);

create table product_options (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references products(id) on delete cascade,
  name text not null,
  choices jsonb not null default '[]'
);

create table product_variants (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references products(id) on delete cascade,
  option_values jsonb not null default '{}',
  price_override numeric(12,2),
  stock_qty int default 0
);

create table channel_posts (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references products(id) on delete cascade,
  channel_id uuid not null references shop_channels(id) on delete cascade,
  message_id bigint, posted_at timestamptz default now()
);

create table wishlists (
  customer_id uuid not null references customers(id) on delete cascade,
  product_id uuid not null references products(id) on delete cascade,
  notify_when_back boolean default false,
  primary key (customer_id, product_id)
);

create table discount_codes (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references shops(id) on delete cascade,
  code text not null,
  type text not null check (type in ('percent','fixed')),
  value numeric(12,2) not null,
  min_total numeric(12,2) default 0,
  max_uses int, used_count int default 0,
  expires_at timestamptz,
  active boolean default true,
  unique (shop_id, code)
);

create table shop_payment_methods (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references shops(id) on delete cascade,
  type text not null check (type in ('bank','mobile_money','cod')),
  label text, account_name text, account_number text, instructions text,
  active boolean default true
);

create table shop_checkout_settings (
  shop_id uuid primary key references shops(id) on delete cascade,
  delivery_enabled boolean default true,
  pickup_enabled boolean default false,
  pickup_address text,
  require_location boolean default true,
  require_receipt boolean default true,
  custom_questions jsonb default '[]',
  stock_hold_minutes int default 180,
  deposit_mode text default 'none' check (deposit_mode in ('none','percent','fixed')),
  deposit_value numeric(12,2) default 0,
  deposit_applies text default 'cod_only' check (deposit_applies in ('always','cod_only','above_total')),
  deposit_threshold numeric(12,2),
  waive_for_returning_buyers boolean default false,
  refund_terms text
);

create table delivery_zones (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references shops(id) on delete cascade,
  name text not null, fee numeric(12,2) default 0
);

create table orders (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references shops(id) on delete cascade,
  customer_id uuid not null references customers(id),
  order_number bigint generated always as identity,
  status text not null default 'placed' check (status in ('placed','awaiting_payment','receipt_uploaded','payment_confirmed','preparing','out_for_delivery','ready_for_pickup','completed','cancelled','rejected','expired')),
  delivery_type text check (delivery_type in ('delivery','pickup')),
  phone text, address_text text,
  lat double precision, lng double precision,
  note text, custom_answers jsonb default '{}',
  subtotal numeric(12,2) not null default 0,
  discount numeric(12,2) default 0,
  delivery_fee numeric(12,2) default 0,
  total numeric(12,2) not null default 0,
  deposit_required numeric(12,2) default 0,
  deposit_paid numeric(12,2) default 0,
  balance_due numeric(12,2) default 0,
  payment_method_id uuid references shop_payment_methods(id) on delete set null,
  hold_expires_at timestamptz,
  cancel_reason text,
  created_at timestamptz default now()
);
create index orders_shop_idx on orders(shop_id, created_at desc);

create table order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references orders(id) on delete cascade,
  product_id uuid references products(id) on delete set null,
  variant_id uuid references product_variants(id) on delete set null,
  title_snapshot text not null,
  price_snapshot numeric(12,2) not null,
  qty int not null default 1 check (qty > 0)
);

create table order_status_history (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references orders(id) on delete cascade,
  status text not null,
  changed_by uuid references users(id),
  changed_at timestamptz default now()
);

create table payments (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references orders(id) on delete cascade,
  kind text not null check (kind in ('deposit','full','balance')),
  amount numeric(12,2) not null,
  status text not null default 'pending' check (status in ('pending','confirmed','rejected')),
  receipt_url text, reference_number text,
  flag text default 'none' check (flag in ('none','duplicate_reference','amount_mismatch')),
  submitted_at timestamptz default now(),
  reviewed_at timestamptz
);
create index payments_order_idx on payments(order_id);
create index payments_reference_idx on payments(reference_number);

create table conversations (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references shops(id) on delete cascade,
  customer_id uuid not null references customers(id) on delete cascade,
  order_id uuid references orders(id) on delete set null,
  type text not null check (type in ('order','product_question')),
  created_at timestamptz default now()
);

create table messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references conversations(id) on delete cascade,
  sender_role text not null check (sender_role in ('buyer','seller')),
  text text, media_url text,
  created_at timestamptz default now(),
  read_at timestamptz
);
create index messages_conv_idx on messages(conversation_id, created_at);

create table reviews (
  id uuid primary key default gen_random_uuid(),
  order_id uuid unique not null references orders(id) on delete cascade,
  shop_id uuid not null references shops(id) on delete cascade,
  rating int not null check (rating between 1 and 5),
  comment text,
  status text default 'published' check (status in ('published','hidden')),
  created_at timestamptz default now()
);

create table reports (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references shops(id) on delete cascade,
  reporter_user_id uuid references users(id),
  reason text not null, details text,
  status text default 'new' check (status in ('new','dismissed','warned','suspended')),
  created_at timestamptz default now()
);

create table plans (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  price numeric(12,2) not null,
  product_limit int,
  features jsonb default '{}',
  active boolean default true
);

create table subscriptions (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid unique not null references shops(id) on delete cascade,
  plan_id uuid references plans(id),
  status text not null default 'trial' check (status in ('trial','active','grace','expired')),
  trial_ends_at timestamptz, period_start timestamptz, period_end timestamptz
);

create table subscription_payments (
  id uuid primary key default gen_random_uuid(),
  subscription_id uuid not null references subscriptions(id) on delete cascade,
  amount numeric(12,2) not null,
  receipt_url text, reference_number text,
  status text not null default 'pending' check (status in ('pending','confirmed','rejected')),
  reviewed_by uuid references users(id),
  created_at timestamptz default now()
);

create table admin_users (
  user_id uuid primary key references users(id) on delete cascade,
  role text not null default 'admin'
);

create table audit_log (
  id uuid primary key default gen_random_uuid(),
  actor_user_id uuid references users(id),
  action text not null, entity text, entity_id uuid,
  created_at timestamptz default now()
);

-- One plan for now (price is a placeholder: decide 500 or 1000).
insert into plans (name, price) values ('Shop plan', 1000);

-- Row-level security on for every table above; no public policies, so only the server can access them.
do $$
declare t text;
begin
  for t in select unnest(array[
    'shop_channels','product_options','product_variants','channel_posts','wishlists','discount_codes',
    'shop_payment_methods','shop_checkout_settings','delivery_zones','orders','order_items',
    'order_status_history','payments','conversations','messages','reviews','reports','plans',
    'subscriptions','subscription_payments','admin_users','audit_log'
  ]) loop
    execute format('alter table %I enable row level security', t);
  end loop;
end $$;
