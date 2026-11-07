from functions.configure_log_retention import handler


class FakeLogsClient:
    def __init__(self):
        self.created = []
        self.retention = []

    def create_log_group(self, *, logGroupName):
        self.created.append(logGroupName)

    def put_retention_policy(self, *, logGroupName, retentionInDays):
        self.retention.append((logGroupName, retentionInDays))


def test_custom_resource_creates_groups_and_sets_sixty_day_retention(monkeypatch):
    client = FakeLogsClient()
    responses = []
    monkeypatch.setattr(handler.boto3, "client", lambda service: client)
    monkeypatch.setattr(
        handler,
        "_send_cloudformation_response",
        lambda event, context, status, reason=None: responses.append((status, reason)),
    )

    result = handler.lambda_handler(
        {
            "ResponseURL": "https://example.invalid/response",
            "RequestType": "Create",
            "ResourceProperties": {
                "RetentionInDays": 60,
                "FunctionNames": ["stack-LoginFunction-ABC", "stack-HealthFunction-XYZ"],
            },
        },
        None,
    )

    assert result == {"retention_days": 60, "configured_group_count": 2}
    assert client.created == [
        "/aws/lambda/stack-HealthFunction-XYZ",
        "/aws/lambda/stack-LoginFunction-ABC",
    ]
    assert client.retention == [
        ("/aws/lambda/stack-HealthFunction-XYZ", 60),
        ("/aws/lambda/stack-LoginFunction-ABC", 60),
    ]
    assert responses == [("SUCCESS", None)]
