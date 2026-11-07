import json

from functions.create_org_user import handler as create_handler
from functions.update_org_user import handler as update_handler


def test_club_admin_create_rejects_password_field():
    response = create_handler.lambda_handler(
        {
            "body": json.dumps(
                {
                    "organization_id": 42,
                    "username": "player@example.com",
                    "password": "AdminChosen!9",
                    "role": "scorer",
                }
            )
        },
        None,
    )

    assert response["statusCode"] == 400
    assert '"code": "INVALID_INPUT"' in response["body"]


def test_club_admin_update_rejects_password_field():
    response = update_handler.lambda_handler(
        {
            "pathParameters": {"user_id": "7"},
            "body": json.dumps(
                {
                    "organization_id": 42,
                    "password": "AdminChosen!9",
                }
            ),
        },
        None,
    )

    assert response["statusCode"] == 400
    assert '"code": "INVALID_INPUT"' in response["body"]
