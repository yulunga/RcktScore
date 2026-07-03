CREATE TABLE IF NOT EXISTS platform_settings (
    id text PRIMARY KEY,
    enabled_sports jsonb NOT NULL DEFAULT '["squash","racketball","tennis"]'::jsonb,
    updated_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO platform_settings (id, enabled_sports, updated_at)
VALUES ('default', '["squash","racketball","tennis"]'::jsonb, now())
ON CONFLICT (id) DO NOTHING;
