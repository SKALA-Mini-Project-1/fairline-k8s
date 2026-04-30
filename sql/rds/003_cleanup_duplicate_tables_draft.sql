-- Draft only. Review row counts, dependencies, and service usage before executing.
-- Canonical tables to keep:
--   auth.users
--   concert.artist
--   concert.concerts
--   concert.schedules
--   concert.seats
--   ticketing.bookings
--   ticketing.booking_items
--   payment.payments
--   payment.refunds
--   payment.payment_events
--   queue.user_artist_fan_scores

-- 1. Inspect duplicate table distribution.
SELECT table_name,
       string_agg(table_schema, ', ' ORDER BY table_schema) AS schemas,
       count(*) AS schema_count
FROM information_schema.tables
WHERE table_schema IN ('auth', 'concert', 'ticketing', 'payment', 'queue', 'public')
GROUP BY table_name
HAVING count(*) > 1
ORDER BY table_name;

-- 2. Inspect row counts before cleanup.
SELECT 'auth.users' AS table_name, count(*) AS row_count FROM auth.users
UNION ALL
SELECT 'concert.artist', count(*) FROM concert.artist
UNION ALL
SELECT 'concert.concerts', count(*) FROM concert.concerts
UNION ALL
SELECT 'concert.schedules', count(*) FROM concert.schedules
UNION ALL
SELECT 'concert.seats', count(*) FROM concert.seats
UNION ALL
SELECT 'ticketing.bookings', count(*) FROM ticketing.bookings
UNION ALL
SELECT 'ticketing.booking_items', count(*) FROM ticketing.booking_items
UNION ALL
SELECT 'payment.payments', count(*) FROM payment.payments
UNION ALL
SELECT 'payment.refunds', count(*) FROM payment.refunds
UNION ALL
SELECT 'payment.payment_events', count(*) FROM payment.payment_events
UNION ALL
SELECT 'queue.user_artist_fan_scores', count(*) FROM queue.user_artist_fan_scores
ORDER BY table_name;

-- 3. Inspect non-canonical duplicates and compare row counts.
SELECT 'auth.booking_items' AS table_name, count(*) AS row_count FROM auth.booking_items
UNION ALL
SELECT 'auth.bookings', count(*) FROM auth.bookings
UNION ALL
SELECT 'auth.seats', count(*) FROM auth.seats
UNION ALL
SELECT 'auth.user_artist_fan_scores', count(*) FROM auth.user_artist_fan_scores
UNION ALL
SELECT 'concert.booking_items', count(*) FROM concert.booking_items
UNION ALL
SELECT 'concert.bookings', count(*) FROM concert.bookings
UNION ALL
SELECT 'concert.user_artist_fan_scores', count(*) FROM concert.user_artist_fan_scores
UNION ALL
SELECT 'concert.users', count(*) FROM concert.users
UNION ALL
SELECT 'payment.booking_items', count(*) FROM payment.booking_items
UNION ALL
SELECT 'payment.bookings', count(*) FROM payment.bookings
UNION ALL
SELECT 'payment.seats', count(*) FROM payment.seats
UNION ALL
SELECT 'payment.user_artist_fan_scores', count(*) FROM payment.user_artist_fan_scores
UNION ALL
SELECT 'payment.users', count(*) FROM payment.users
UNION ALL
SELECT 'public.artist', count(*) FROM public.artist
UNION ALL
SELECT 'public.booking_items', count(*) FROM public.booking_items
UNION ALL
SELECT 'public.bookings', count(*) FROM public.bookings
UNION ALL
SELECT 'public.concerts', count(*) FROM public.concerts
UNION ALL
SELECT 'public.payment_events', count(*) FROM public.payment_events
UNION ALL
SELECT 'public.payments', count(*) FROM public.payments
UNION ALL
SELECT 'public.refunds', count(*) FROM public.refunds
UNION ALL
SELECT 'public.schedules', count(*) FROM public.schedules
UNION ALL
SELECT 'public.seats', count(*) FROM public.seats
UNION ALL
SELECT 'public.user_artist_fan_scores', count(*) FROM public.user_artist_fan_scores
UNION ALL
SELECT 'public.users', count(*) FROM public.users
UNION ALL
SELECT 'queue.booking_items', count(*) FROM queue.booking_items
UNION ALL
SELECT 'queue.bookings', count(*) FROM queue.bookings
UNION ALL
SELECT 'queue.seats', count(*) FROM queue.seats
UNION ALL
SELECT 'queue.users', count(*) FROM queue.users
UNION ALL
SELECT 'ticketing.seats', count(*) FROM ticketing.seats
UNION ALL
SELECT 'ticketing.user_artist_fan_scores', count(*) FROM ticketing.user_artist_fan_scores
UNION ALL
SELECT 'ticketing.users', count(*) FROM ticketing.users
ORDER BY table_name;

-- 4. Inspect foreign keys referencing duplicate tables.
SELECT tc.table_schema,
       tc.table_name,
       kcu.column_name,
       ccu.table_schema AS foreign_table_schema,
       ccu.table_name AS foreign_table_name,
       ccu.column_name AS foreign_column_name,
       tc.constraint_name
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
  ON tc.constraint_name = kcu.constraint_name
 AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage ccu
  ON ccu.constraint_name = tc.constraint_name
 AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND (
    tc.table_schema IN ('auth', 'concert', 'ticketing', 'payment', 'queue', 'public')
    OR ccu.table_schema IN ('auth', 'concert', 'ticketing', 'payment', 'queue', 'public')
  )
ORDER BY tc.table_schema, tc.table_name, tc.constraint_name;

-- 5. Cleanup draft.
-- Execute only after validating:
--   - all services read/write canonical tables only
--   - duplicate tables are unused or fully migrated
--   - a backup/snapshot exists

-- BEGIN;

-- DROP TABLE IF EXISTS auth.booking_items;
-- DROP TABLE IF EXISTS auth.bookings;
-- DROP TABLE IF EXISTS auth.seats;
-- DROP TABLE IF EXISTS auth.user_artist_fan_scores;

-- DROP TABLE IF EXISTS concert.booking_items;
-- DROP TABLE IF EXISTS concert.bookings;
-- DROP TABLE IF EXISTS concert.user_artist_fan_scores;
-- DROP TABLE IF EXISTS concert.users;

-- DROP TABLE IF EXISTS payment.booking_items;
-- DROP TABLE IF EXISTS payment.bookings;
-- DROP TABLE IF EXISTS payment.seats;
-- DROP TABLE IF EXISTS payment.user_artist_fan_scores;
-- DROP TABLE IF EXISTS payment.users;

-- DROP TABLE IF EXISTS queue.booking_items;
-- DROP TABLE IF EXISTS queue.bookings;
-- DROP TABLE IF EXISTS queue.seats;
-- DROP TABLE IF EXISTS queue.users;

-- DROP TABLE IF EXISTS ticketing.seats;
-- DROP TABLE IF EXISTS ticketing.user_artist_fan_scores;
-- DROP TABLE IF EXISTS ticketing.users;

-- DROP TABLE IF EXISTS public.payment_events;
-- DROP TABLE IF EXISTS public.refunds;
-- DROP TABLE IF EXISTS public.payments;
-- DROP TABLE IF EXISTS public.booking_items;
-- DROP TABLE IF EXISTS public.bookings;
-- DROP TABLE IF EXISTS public.seats;
-- DROP TABLE IF EXISTS public.schedules;
-- DROP TABLE IF EXISTS public.concerts;
-- DROP TABLE IF EXISTS public.artist;
-- DROP TABLE IF EXISTS public.user_artist_fan_scores;
-- DROP TABLE IF EXISTS public.users;

-- COMMIT;
