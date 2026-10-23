package com.hitnscore.mobile.data

/** Anonymised payloads in the shape `backend/common/dashboard_logic.py` and `match_logic.py` return. */
object DashboardFixtures {
    val dashboard = """
        {"success":true,"error":null,"meta":{},"data":{"dashboard":{
          "organization":{"id":50011,"name":"Pat Player","type":"personal","plan":"personal_free",
            "history_limit":10,"completed_match_count":12,"locked_history_count":2,
            "entitlements":{"history_limit":10,"performance_enabled":false},
            "available_plan_entitlements":null,"court_count":0,"user_count":1,"roles":["admin"]},
          "active_matches":[{"id":"m-live","player1_name":"Pat","player1_surname":"Player",
            "player2_name":"Sam","player2_surname":null,"court_name":"Court 1","sport":"squash",
            "status":"in_progress","best_of":5,"score_type":11,
            "state":{"player1_games_won":2,"player2_games_won":1,"player1_score":5,"player2_score":3}}],
          "scheduled_matches":[],
          "recent_matches":[
            {"id":"m-done","player1_name":"Pat","player2_name":"Sam","sport":"racketball","status":"completed",
             "completed_at":"2026-10-20T18:30:00.000000+00:00","best_of":null,"winner_name":"Sam",
             "state":{"player1_games_won":1,"player2_games_won":3,"game_history":[
               {"game_number":1,"player1_score":11,"player2_score":7}]}},
            {"id":"locked-history-preview","status":"locked","sport":"squash","player1_name":"Locked",
             "player1_surname":null,"player2_name":"Match","player2_surname":null,"court_name":null,
             "best_of":null,"score_type":null,"match_duration_seconds":null,"winner_name":null,"state":null,
             "updated_at":"2026-09-01T10:00:00+00:00","completed_at":"2026-09-01T10:00:00+00:00","locked":true}],
          "viewed_matches":[],
          "app_analytics":{"completed_match_rate":50.0},
          "player_analytics":null,"club_analytics":null,"performance":null}}}
    """.trimIndent()

    val squashMatch = """
        {"success":true,"data":{"match":{
          "id":"m-done","sport":"squash","player1_name":"Pat","player1_surname":"Player","player2_name":"Sam",
          "score_type":11,"best_of":3,"status":"completed","created_at":"2026-10-20T18:00:00+00:00",
          "match_duration_seconds":30,
          "state":{"player1_games_won":2,"player2_games_won":0,"best_of":3,"score_type":11,
            "game_history":[{"game_number":1,"player1_score":11,"player2_score":9},
                            {"game_number":2,"player1_score":11,"player2_score":4}],
            "events":[
              {"id":"e1","event_type":"match_started","created_at":"2026-10-20T18:00:00+00:00"},
              {"id":"e2","event_type":"score_point","created_at":"2026-10-20T18:01:00+00:00",
               "payload":{"scorer":"player1","game_number":1,"player1_score":1,"player2_score":0,
                          "current_server_side":"player1","service_side":"right"}},
              {"id":"e3","event_type":"score_point","created_at":"2026-10-20T18:11:00+00:00",
               "payload":{"scorer":"player1","game_number":1,"player1_score":11,"player2_score":9,
                          "game_completed":true}},
              {"id":"e4","event_type":"let","created_at":"2026-10-20T18:12:00+00:00",
               "payload":{"player_side":"player2","game_number":2}},
              {"id":"e5","event_type":"score_point","created_at":"2026-10-20T18:20:00+00:00",
               "payload":{"scorer":"player1","game_number":2,"player1_score":11,"player2_score":4,"match_completed":true}}
            ]}}}}
    """.trimIndent()
}
