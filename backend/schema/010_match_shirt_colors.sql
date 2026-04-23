ALTER TABLE matches
    ADD COLUMN IF NOT EXISTS player1_shirt_color text NOT NULL DEFAULT 'navy',
    ADD COLUMN IF NOT EXISTS player2_shirt_color text NOT NULL DEFAULT 'white';

UPDATE matches
SET player1_shirt_color = 'navy'
WHERE player1_shirt_color IS NULL;

UPDATE matches
SET player2_shirt_color = 'white'
WHERE player2_shirt_color IS NULL;

ALTER TABLE matches
    DROP CONSTRAINT IF EXISTS matches_player1_shirt_color_check,
    DROP CONSTRAINT IF EXISTS matches_player2_shirt_color_check;

ALTER TABLE matches
    ADD CONSTRAINT matches_player1_shirt_color_check
    CHECK (player1_shirt_color IN ('navy', 'blue', 'red', 'green', 'black', 'white', 'yellow', 'orange', 'purple', 'pink')),
    ADD CONSTRAINT matches_player2_shirt_color_check
    CHECK (player2_shirt_color IN ('navy', 'blue', 'red', 'green', 'black', 'white', 'yellow', 'orange', 'purple', 'pink'));
