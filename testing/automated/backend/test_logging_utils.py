from common.logging_utils import mask_email_for_log


def test_email_is_masked_without_losing_operational_domain_context():
    assert mask_email_for_log("Sarah.Example@Example.COM") == "s***@example.com"


def test_non_email_and_empty_identifiers_are_safe():
    assert mask_email_for_log("Administrator") == "a***"
    assert mask_email_for_log("") == "unknown"
    assert mask_email_for_log(None) == "unknown"
