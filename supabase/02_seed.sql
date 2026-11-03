-- Test shop. Replace YOUR_TEST_BOT_USERNAME (no @) and PASTE_TEST_BOT_TOKEN, then run once.
with s as (
  insert into shops (name, slug, status, description)
  values ('Test Shop', 'test', 'active', 'My first test shop') returning id
), b as (
  insert into shop_bots (shop_id, bot_username, token)
  select id, 'YOUR_TEST_BOT_USERNAME', 'PASTE_TEST_BOT_TOKEN' from s
), t as (
  insert into shop_themes (shop_id) select id from s
)
insert into products (shop_id, title, description, price, status, stock_qty)
select s.id, x.title, x.descr, x.price, x.status, x.stock
from s, (values
  ('Cloud runner', 'Lightweight everyday sneaker', 3200, 'active', 3),
  ('Field tote', 'Roomy everyday tote', 1850, 'active', 12),
  ('Court low', 'Classic low court shoe', 2400, 'sold_out', 0),
  ('Chrono 40', '40 mm steel watch', 6400, 'active', 5)
) as x(title, descr, price, status, stock);
