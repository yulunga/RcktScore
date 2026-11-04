# HitnScore service relationships

Current pre-launch architecture based on repository code, deployment templates and runbooks. Live provider settings were not checked. Arrows show who initiates the call or transfer.

## Application data flow

```mermaid
flowchart TD
    Visitor["Website visitor"] -->|Opens public website| Landing["Public site · CloudFront + S3"]
    Landing -->|Links to scoring, draws and displays| Web["React (AWS Amplify)"]
    GitHub["GitHub"] -->|Source branch for build| Web
    TestFlight["Apple TestFlight"] -->|Distributes beta builds| iOS["Native iOS app"]

    Web -->|HTTPS · read, score or poll| API["AWS API Gateway"]
    iOS -->|HTTPS · read, score or replay offline actions| API
    API -->|Routes request| Lambda["Python backend · AWS Lambda"]
    Lambda -->|Reads and writes via Postgres pooler| DB["Supabase Postgres"]
    Lambda -->|Submits transactional email| SES["AWS SES"]
    SES -->|Delivers email| Mail["Recipient mailbox"]
    Mail -->|Account links open web app| Web

    iOS -->|Starts purchase| Apple["Apple StoreKit + App Store Server"]
    Apple -->|Pushes subscription notifications| API
    Lambda -->|Pulls subscription status| Apple
    Web -->|Sends page views after consent| GA["Google Analytics 4"]
```

React runs in the browser after Amplify serves the app bundle. Web and iOS submit scoring actions through the same API. Spectator views pull updates through that API, and court displays poll every five seconds by default.

## Hosting, deployment and operations

```mermaid
flowchart TD
    GitHub["GitHub"] -->|Source for web build| Web["React (AWS Amplify)"]
    GitHub -->|Source for backend release| SAM["AWS SAM + CloudFormation"]
    SAM -->|Deploys backend stack| Backend["API Gateway + Lambda"]
    GitHub -->|Versioned SQL applied separately| DB["Supabase Postgres"]
    GitHub -->|Landing site deployment| S3["Private S3 bucket"]
    CDN["CloudFront"] -->|Fetches site files| S3
    DNS["GoDaddy DNS + forwarding"] -->|Routes public domain| CDN
    ACM["AWS Certificate Manager"] -->|Provides HTTPS certificate| CDN

    Scheduler["EventBridge Scheduler"] -->|Triggers health checks and Apple reconciliation| Backend
    Backend -->|IAM-authorised credential read| Secrets["AWS Secrets Manager"]
    Backend -->|Emits metrics and logs| CW["AWS CloudWatch"]
    CW -->|Publishes alarms| SNS["AWS SNS · KMS encryption"]
    SNS -->|Emails alerts| Ops["Confirmed subscribers"]
```

## Service inventory

| Component or supplier | Role in HitnScore | Who calls what and how data moves |
| --- | --- | --- |
| React/Vite web app · AWS Amplify Hosting | Serves the scoring app at `app.hitnscore.com`, including admin, public draws and spectator views. | Browser pulls the app bundle from Amplify. The loaded app calls API Gateway over HTTPS to fetch data or submit changes. `VITE_API_BASE_URL` supplies the API address at build time. |
| Apple iOS app · App Store Connect/TestFlight | Native scoring client and beta distribution. The Android/Compose foundation has no implemented product flows yet. | TestFlight distributes builds to testers. The installed iOS app calls the same HTTPS API as web. Offline scoring queues actions for one previously loaded match and replays them in order after reconnect. The backend deduplicates retries using action IDs. |
| AWS API Gateway HTTP API | Public HTTPS entry point for app requests, display reads and Apple callbacks. | Browser, iOS or Apple → API Gateway → route-specific Lambda → HTTP response. Protected routes enforce backend sessions and applicable membership, role or entitlement checks. |
| AWS Lambda · Python backend | Owns authentication, scoring rules, matches, accounts, tournaments, reporting and entitlements. | Reads and writes Supabase Postgres, sends email through SES, and verifies or reconciles Apple purchases. Returns results to the caller. |
| Supabase Postgres · connection pooler | Authoritative store for identities, sessions, clubs, courts, matches and events, notifications, subscriptions and audit data. | Lambda connects through the Postgres pooler and executes SQL. Web and iOS pull data through the API. In-app notification read state is shared through Postgres and fetched by clients. |
| AWS SES | Sends transactional email for account setup, password resets, club invitations and enquiries, and feedback. | Lambda → SES → recipient's mail provider. Account links open the web flow, which calls the API to complete the action. |
| AWS S3 and CloudFront | Host and deliver the separate public landing site at `www.hitnscore.com`. | Deployment script pushes `weblanding/` to private S3 and invalidates CloudFront. Browser pulls from CloudFront, which fetches files from S3 when needed. Links open the app for scoring, help, public draws or displays. |
| GoDaddy DNS and forwarding · AWS Certificate Manager | Connect the public domain to hosting and provide HTTPS for the landing site. | GoDaddy DNS resolves `www.hitnscore.com` to CloudFront. The documented GoDaddy forwarding sends the bare domain to `www`. CloudFront presents the ACM certificate, with domain validation through DNS. |
| Apple StoreKit and App Store Server services | Handle iOS Personal Plus purchases and subscription lifecycle. Purchase acceptance is deployment-gated. | iOS → StoreKit → signed purchase data → HitnScore API. Apple pushes signed lifecycle notifications to API Gateway. Reconciliation Lambda pulls subscription status from Apple's Server API and updates Postgres entitlements. Clients pull the resulting plan from HitnScore. |
| AWS Secrets Manager and IAM | Supply Apple API signing credentials when configured and grant service permissions. | Reconciliation Lambda reads the configured secret using its IAM role. Stack policies grant functions the AWS access they need, including SES sending. |
| AWS EventBridge Scheduler | Triggers backend checks without a client request. | Scheduler → health Lambda every five minutes → Postgres connectivity check. Scheduler → Apple reconciliation Lambda hourly when configured and enabled. |
| AWS CloudWatch, SNS and KMS | Monitor backend health and deliver operational alerts. | API Gateway and Lambda emit metrics and logs to CloudWatch. Alarms publish to an SNS topic encrypted with the AWS-managed KMS key. SNS emails confirmed subscribers. |
| Google Analytics 4 | Measures consented web usage. | The browser loads Google's tag after analytics consent. The React app sends sanitised page-view events to Google. |
| GitHub · AWS SAM and CloudFormation | GitHub holds source and change history. SAM and CloudFormation deploy the backend stack. | Developers push commits to GitHub. Amplify pulls the configured source branch to build the web app. The backend release process deploys the selected code through SAM/CloudFormation and applies versioned SQL to Supabase as a separate step. |

**Live score sync.** The scorer pushes a scoring action to the HTTP API. Lambda records it in Postgres. Spectator views pull updates over HTTPS. Court displays poll every five seconds by default. WebSocket broadcasting is scaffolded. Stripe checkout and Apple Push Notification service delivery are outside the current implementation.

Repository references: [backend stack](../backend/template.yaml), [web build](../amplify.yml), [landing deployment](weblanding-aws-godaddy-deployment.md), [request flows](technical-walkthrough.md), [scoreboard polling](scoreboard-v1-implementation.md), and [release process](promotion-runbook.md).
