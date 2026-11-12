CREATE TABLE public_registration_settings (
    id text PRIMARY KEY CHECK (id = 'default'),
    public_registration_enabled boolean NOT NULL DEFAULT true,
    public_registration_message text NOT NULL DEFAULT
        'We are not taking on new users at the moment. Please register your interest and we’ll be in touch.',
    registration_challenge_key uuid NOT NULL DEFAULT gen_random_uuid()
);

INSERT INTO public_registration_settings (id) VALUES ('default');

CREATE TABLE public_registration_interest (
    email text NOT NULL,
    use_type text NOT NULL CHECK (use_type IN ('personal', 'club')),
    first_name text NOT NULL,
    surname text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (email, use_type)
);

CREATE TABLE public_registration_challenges (
    token_hash text PRIMARY KEY,
    expires_at timestamptz NOT NULL
);

ALTER TABLE public_registration_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public_registration_interest ENABLE ROW LEVEL SECURITY;
ALTER TABLE public_registration_challenges ENABLE ROW LEVEL SECURITY;
