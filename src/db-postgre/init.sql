SELECT 'CREATE DATABASE ksink'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'ksink')\gexec

\c ksink

CREATE TABLE IF NOT EXISTS public.test2(
    id uuid NOT NULL,
    f1 text NULL,
    CONSTRAINT test2_pkey PRIMARY KEY (id)
);