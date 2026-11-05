# Mobile API Contracts

**Naming:** HitnScore is the customer-facing application. `RcktScore` is the internal project and repository code name.

This directory holds mobile-facing API references derived from the existing v2
backend contract.

Recommended future contents:

- `login.json`
- `dashboard.json`
- `match.json`
- `score-point.json`
- `event-action.json`
- `end-match.json`

These should mirror the live response envelope:

```json
{
  "success": true,
  "data": {},
  "error": null,
  "meta": {}
}
```

and

```json
{
  "success": false,
  "data": null,
  "error": {
    "code": "ERROR_CODE",
    "message": "Human readable message"
  },
  "meta": {}
}
```

