-- Correct a primary player's name while a match is in progress.
--
-- Run this entire file in the target Supabase SQL Editor as an authorised
-- database operator. Replace the six values at the top of the DO block.
-- The operation is atomic and deliberately refuses to edit a non-active match,
-- the wrong tenant, or a player whose current first name is not the expected
-- value.
--
-- This changes only the selected match. It does not rename the user's account,
-- club membership, or any other match. Player 1 and Player 2 mean the primary
-- participants shown in the two score cards. Do not use this script for the
-- second participant on either side of a tennis/padel doubles match.
--
-- Find the match and tenant first, for example:
-- SELECT id, tenant_id, sport, status,
--        player1_name, player1_surname, player2_name, player2_surname
-- FROM public.matches
-- WHERE status = 'active'
-- ORDER BY updated_at DESC;

DO $change_active_match_player_name$
DECLARE
    -- Required inputs.
    target_match_id uuid := '00000000-0000-0000-0000-000000000000';
    expected_tenant_id bigint := 0;
    player_side text := 'player1'; -- player1 or player2
    expected_current_first_name text := 'REPLACE_WITH_CURRENT_FIRST_NAME';
    new_first_name text := 'REPLACE_WITH_NEW_FIRST_NAME';
    new_surname text := 'REPLACE_WITH_NEW_SURNAME'; -- use '' to clear surname

    match_tenant_id bigint;
    match_status text;
    match_sport text;
    old_first_name text;
    old_surname text;
    old_display_name text;
    new_display_name text;
    primary_participant_id text;
    event_row record;
    revised_payload jsonb;
    team_payload jsonb;
    json_surname jsonb;
    changed_event_count integer := 0;
BEGIN
    player_side := lower(btrim(player_side));
    expected_current_first_name := btrim(expected_current_first_name);
    new_first_name := btrim(new_first_name);
    new_surname := nullif(btrim(new_surname), '');

    IF target_match_id = '00000000-0000-0000-0000-000000000000'::uuid THEN
        RAISE EXCEPTION 'Replace target_match_id with the active match UUID';
    END IF;

    IF expected_tenant_id <= 0 THEN
        RAISE EXCEPTION 'Replace expected_tenant_id with the match tenant_id';
    END IF;

    IF player_side NOT IN ('player1', 'player2') THEN
        RAISE EXCEPTION 'player_side must be player1 or player2';
    END IF;

    IF expected_current_first_name = ''
       OR expected_current_first_name = 'REPLACE_WITH_CURRENT_FIRST_NAME' THEN
        RAISE EXCEPTION 'Set expected_current_first_name to the name currently stored on the match';
    END IF;

    IF new_first_name = '' OR new_first_name = 'REPLACE_WITH_NEW_FIRST_NAME' THEN
        RAISE EXCEPTION 'Set new_first_name';
    END IF;

    IF new_surname = 'REPLACE_WITH_NEW_SURNAME' THEN
        RAISE EXCEPTION 'Set new_surname, or use an empty string to clear it';
    END IF;

    SELECT
        tenant_id,
        status,
        sport,
        CASE WHEN player_side = 'player1' THEN player1_name ELSE player2_name END,
        CASE WHEN player_side = 'player1' THEN player1_surname ELSE player2_surname END
    INTO
        match_tenant_id,
        match_status,
        match_sport,
        old_first_name,
        old_surname
    FROM public.matches
    WHERE id = target_match_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Match % was not found', target_match_id;
    END IF;

    IF match_tenant_id <> expected_tenant_id THEN
        RAISE EXCEPTION 'Tenant check failed: match belongs to tenant %, not %',
            match_tenant_id, expected_tenant_id;
    END IF;

    IF match_status <> 'active' THEN
        RAISE EXCEPTION 'Match % has status %, not active', target_match_id, match_status;
    END IF;

    IF lower(btrim(old_first_name)) <> lower(expected_current_first_name) THEN
        RAISE EXCEPTION 'Current-name check failed: % is stored as %, not %',
            player_side, old_first_name, expected_current_first_name;
    END IF;

    old_display_name := concat_ws(' ', old_first_name, nullif(btrim(old_surname), ''));
    new_display_name := concat_ws(' ', new_first_name, new_surname);
    primary_participant_id := CASE
        WHEN player_side = 'player1' THEN 'team1_player1'
        ELSE 'team2_player1'
    END;
    json_surname := CASE
        WHEN new_surname IS NULL THEN 'null'::jsonb
        ELSE to_jsonb(new_surname)
    END;

    UPDATE public.matches
    SET
        player1_name = CASE WHEN player_side = 'player1' THEN new_first_name ELSE player1_name END,
        player1_surname = CASE WHEN player_side = 'player1' THEN new_surname ELSE player1_surname END,
        player2_name = CASE WHEN player_side = 'player2' THEN new_first_name ELSE player2_name END,
        player2_surname = CASE WHEN player_side = 'player2' THEN new_surname ELSE player2_surname END,
        winner_name = CASE
            WHEN winner_side = player_side THEN new_first_name
            ELSE winner_name
        END,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = target_match_id;

    -- Tennis/padel persist participant names in match_started metadata, and all
    -- engines may persist server/receiver/winner display names in event payloads.
    -- Rewrite those denormalised copies so replay cannot restore the old name.
    FOR event_row IN
        SELECT id, payload
        FROM public.match_events
        WHERE match_id = target_match_id
        FOR UPDATE
    LOOP
        revised_payload := event_row.payload;
        team_payload := revised_payload #> ARRAY['tennis_teams', player_side];

        IF jsonb_typeof(team_payload) = 'array'
           AND jsonb_array_length(team_payload) > 0
           AND coalesce(team_payload #>> ARRAY['0', 'id'], primary_participant_id) = primary_participant_id THEN
            revised_payload := jsonb_set(
                revised_payload,
                ARRAY['tennis_teams', player_side, '0', 'first_name'],
                to_jsonb(new_first_name),
                true
            );
            revised_payload := jsonb_set(
                revised_payload,
                ARRAY['tennis_teams', player_side, '0', 'surname'],
                json_surname,
                true
            );
            revised_payload := jsonb_set(
                revised_payload,
                ARRAY['tennis_teams', player_side, '0', 'display_name'],
                to_jsonb(new_display_name),
                true
            );
        END IF;

        IF (
            revised_payload->>'current_server_participant_id' = primary_participant_id
            OR (
                NOT (revised_payload ? 'current_server_participant_id')
                AND revised_payload->>'current_server_side' = player_side
                AND revised_payload->>'current_server' IN (old_first_name, old_display_name)
            )
        ) THEN
            revised_payload := jsonb_set(
                revised_payload,
                '{current_server}',
                to_jsonb(CASE
                    WHEN revised_payload ? 'current_server_participant_id' THEN new_display_name
                    ELSE new_first_name
                END),
                true
            );
        END IF;

        IF (
            revised_payload->>'current_receiver_participant_id' = primary_participant_id
            OR (
                NOT (revised_payload ? 'current_receiver_participant_id')
                AND revised_payload->>'current_receiver_side' = player_side
                AND revised_payload->>'current_receiver' IN (old_first_name, old_display_name)
            )
        ) THEN
            revised_payload := jsonb_set(
                revised_payload,
                '{current_receiver}',
                to_jsonb(CASE
                    WHEN revised_payload ? 'current_receiver_participant_id' THEN new_display_name
                    ELSE new_first_name
                END),
                true
            );
        END IF;

        IF revised_payload->>'winner_side' = player_side
           AND revised_payload ? 'winner_name' THEN
            revised_payload := jsonb_set(
                revised_payload,
                '{winner_name}',
                to_jsonb(new_first_name),
                true
            );
        END IF;

        IF jsonb_typeof(revised_payload->'game_result') = 'object'
           AND revised_payload #>> '{game_result,winner_side}' = player_side
           AND (revised_payload->'game_result') ? 'winner_name' THEN
            revised_payload := jsonb_set(
                revised_payload,
                '{game_result,winner_name}',
                to_jsonb(new_first_name),
                true
            );
        END IF;

        IF revised_payload IS DISTINCT FROM event_row.payload THEN
            UPDATE public.match_events
            SET payload = revised_payload
            WHERE id = event_row.id;
            changed_event_count := changed_event_count + 1;
        END IF;
    END LOOP;

    RAISE NOTICE 'Updated % % from "%" to "%" on active % match %; rewrote % event payload(s)',
        player_side,
        CASE WHEN old_surname IS NULL THEN '' ELSE '(' || old_surname || ')' END,
        old_display_name,
        new_display_name,
        match_sport,
        target_match_id,
        changed_event_count;
END;
$change_active_match_player_name$;

-- Verify after the notice reports success:
-- SELECT id, tenant_id, sport, status,
--        player1_name, player1_surname, player2_name, player2_surname, updated_at
-- FROM public.matches
-- WHERE id = 'REPLACE_WITH_THE_SAME_MATCH_UUID';
