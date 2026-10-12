-- Starting content, copied from what is built into the app today.
-- Paste into Supabase AFTER schema.sql: SQL Editor -> New query -> Run.
-- Safe to run more than once: it never overwrites edits made later.

-- Ministry partners
insert into public.partners (id, name, tagline, about, key_facts, faith_note, website_url, donate_url, sort_order) values ('water-mission', 'Water Mission', 'Christian engineering nonprofit bringing safe water to the world.', 'Founded in 2001 by George and Molly Greene and based in North Charleston, South Carolina, Water Mission designs and builds safe-water, sanitation, and hygiene solutions for communities, refugee camps, and disaster zones.', array['8M+ people served in 60+ countries since 2001', 'Permanent programs in Honduras, Indonesia, Kenya, Malawi, Mexico, Peru, and Tanzania', 'Refugee and disaster response worldwide', 'Top Charity Navigator rating 19 years running']::text[], 'Water Mission serves as a Christian engineering ministry, bringing safe water as an expression of God''s love.', 'https://watermission.org', 'https://watermission.org', 0) on conflict (id) do nothing;
insert into public.partners (id, name, tagline, about, key_facts, faith_note, website_url, donate_url, sort_order) values ('water-for-good', 'Water for Good', 'Lasting clean water, partnering with local churches.', 'Founded in 2004 in the Central African Republic and merged with Lifewater International in 2024, Water for Good works alongside local churches through its three-year "Vision of a Healthy Village" model.', array['Works in Cambodia, Central African Republic, Ethiopia, Uganda, and Tanzania', 'Reliable water for 1.3M+ people every year', '90% of its water points stay working', 'Completed villages see a median 90% drop in childhood diarrhea']::text[], 'Water for Good works alongside local churches so that whole villages can be healthy, in body and in spirit.', 'https://waterforgood.org', 'https://waterforgood.org', 1) on conflict (id) do nothing;
insert into public.partners (id, name, tagline, about, key_facts, faith_note, website_url, donate_url, sort_order) values ('convoy-of-hope', 'Convoy of Hope', 'Faith-based relief bringing water where it''s needed most.', 'Founded in 1994 and based in Springfield, Missouri, Convoy of Hope serves people around the world through relief, food, and community programs, including clean water.', array['350M+ people served across all programs', 'Wells in Tanzania and Niger', 'Water filters in Ukraine and Indonesia', 'Bottled water for U.S. disaster relief']::text[], 'Convoy of Hope is a faith-based organization driven to bring help and hope to those who are impoverished, hungry, and hurting.', 'https://convoyofhope.org', 'https://convoyofhope.org/donate/water/', 2) on conflict (id) do nothing;

-- Home page verses (only added if there are none yet)
insert into public.home_messages (kind, text, reference, sort_order)
select * from (values
  ('scripture', 'Whosoever drinketh of the water that I shall give him shall never thirst.', 'John 4:14 (KJV)', 0),
  ('scripture', 'He that believeth on me, as the scripture hath said, out of his belly shall flow rivers of living water.', 'John 7:38 (KJV)', 1),
  ('scripture', 'Therefore with joy shall ye draw water out of the wells of salvation.', 'Isaiah 12:3 (KJV)', 2),
  ('scripture', 'Let him that is athirst come. And whosoever will, let him take the water of life freely.', 'Revelation 22:17 (KJV)', 3)
) as v(kind, text, reference, sort_order)
where not exists (select 1 from public.home_messages);

-- Editable text
insert into public.content_blocks (key, text) values ('shop_intro', 'Every purchase helps bring clean water to communities in need.') on conflict (key) do nothing;
insert into public.content_blocks (key, text) values ('donate_intro', 'Every one of our partners is putting clean water in the hands of people who need it. Give directly to the ministry that moves you.') on conflict (key) do nothing;
insert into public.content_blocks (key, text) values ('community_intro', 'Stories from the people we serve.') on conflict (key) do nothing;

-- SAMPLE products, hidden from customers (is_active = false) until replaced with real ones.
insert into public.products (name, description, price_cents, badge, is_active, sort_order)
select * from (values
  ('Sample product one', 'SAMPLE. Replace with a real product.', 2499, '', false, 0),
  ('Sample product two', 'SAMPLE. Replace with a real product.', 3499, 'New', false, 1),
  ('Sample product three', 'SAMPLE. Replace with a real product.', 1999, '', false, 2)
) as v(name, description, price_cents, badge, is_active, sort_order)
where not exists (select 1 from public.products);
