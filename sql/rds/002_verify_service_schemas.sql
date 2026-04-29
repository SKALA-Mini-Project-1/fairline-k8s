SELECT schema_name
FROM information_schema.schemata
WHERE schema_name IN ('auth', 'concert', 'ticketing', 'payment', 'queue')
ORDER BY schema_name;

SELECT table_schema, table_name
FROM information_schema.tables
WHERE table_schema IN ('auth', 'concert', 'ticketing', 'payment', 'queue')
  AND table_type = 'BASE TABLE'
ORDER BY table_schema, table_name;
