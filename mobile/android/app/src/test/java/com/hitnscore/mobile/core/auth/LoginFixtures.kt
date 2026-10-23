package com.hitnscore.mobile.core.auth

/** Anonymised login payloads in the shape `backend/functions/login/handler.py` returns. */
object LoginFixtures {
    const val FUTURE_EXPIRY = "2030-01-01T12:00:00.123456+00:00"

    private const val PERSONAL = """
        {"id":11,"username":"player@example.com","role":"admin","organization_id":50011,
         "organization_name":"Pat Player","organization_type":"personal","plan":"personal_plus",
         "enabled_sports":["squash","tennis"],"first_name":"Pat","surname":"Player"}
    """

    private const val CLUB = """
        {"id":12,"username":"player@example.com","role":"user","organization_id":42,
         "organization_name":"Demo Racket Club","organization_type":"club","plan":"club_pro"}
    """

    val identityFirstSession = """
        {"success":true,"error":null,"meta":{},"data":{"session":{
          "id":11,"username":"player@example.com","role":"admin","organization_id":50011,
          "organization_name":"Pat Player","organization_type":"personal","plan":"personal_plus",
          "first_name":"Pat","surname":"Player","full_name":"Pat Player",
          "session_token":"token-abc","session_expires_at":"$FUTURE_EXPIRY",
          "available_memberships":[$PERSONAL,$CLUB]}}}
    """.trimIndent()

    val organizationSelection = """
        {"success":true,"data":{"organizationSelection":{
          "username":"player@example.com","memberships":[$PERSONAL,$CLUB],
          "session_token":"token-xyz","session_expires_at":"$FUTURE_EXPIRY"}}}
    """.trimIndent()

    val activeSessionConflict = """
        {"success":false,"data":null,"error":{"code":"ACTIVE_SESSION_EXISTS",
          "message":"This account is already signed in on the mobile app. Do you want to sign out there and continue here?",
          "details":{"client_type":"mobile_app","client_label":"mobile app","last_seen_at":null}}}
    """.trimIndent()
}
