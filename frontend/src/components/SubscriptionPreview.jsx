import React, { useMemo, useState } from "react";

const PLAN_DETAILS = [
  {
    id: "club_essentials",
    name: "Club Essentials",
    eyebrow: "Club scoring",
    description: "The core workspace for clubs running matches across members and courts.",
    features: [
      "Multi-user club workspace",
      "Court and user administration",
      "Active and scheduled matches",
      "Club match history and display access",
    ],
  },
  {
    id: "club_pro",
    name: "Club Pro",
    eyebrow: "Growing clubs",
    description: "A preview of the higher club tier while its final package is being defined.",
    features: [
      "Everything in Club Essentials",
      "Designed for expanded club operations",
      "Additional limits and features to be confirmed",
      "Priority onboarding options to be confirmed",
    ],
  },
];

function planName(plan) {
  if (plan === "club_pro") return "Club Pro";
  if (plan === "personal_plus") return "Personal+";
  if (plan === "personal_free") return "Personal Free";
  return "Club Essentials";
}

function PaymentIcon() {
  return (
    <svg aria-hidden="true" viewBox="0 0 24 24">
      <rect x="2.5" y="5" width="19" height="14" rx="3" />
      <path d="M3 9.5h18M6.5 15.5h4" />
    </svg>
  );
}

export default function SubscriptionPreview({ currentPlan = "club_essentials", accountEmail = "" }) {
  const [billingPeriod, setBillingPeriod] = useState("annual");
  const [selectedPlan, setSelectedPlan] = useState(null);
  const currentPlanLabel = planName(currentPlan);
  const selectedPlanDetails = useMemo(
    () => PLAN_DETAILS.find((plan) => plan.id === selectedPlan) || null,
    [selectedPlan],
  );

  return (
    <section className="subscription-preview stack">
      <div className="subscription-preview__notice" role="note">
        <span>UI preview</span>
        <p>No payment will be taken. Stripe and subscription updates are not connected yet.</p>
      </div>

      <section className="subscription-current-card">
        <div className="subscription-current-card__icon"><PaymentIcon /></div>
        <div className="subscription-current-card__copy">
          <span className="subscription-kicker">Current subscription</span>
          <h2>{currentPlanLabel}</h2>
          <p>Your club currently has access through its assigned HitnScore plan.</p>
        </div>
        <div className="subscription-current-card__status">
          <span className="status-pill active">Active</span>
          <small>Billing not connected</small>
        </div>
      </section>

      <div className="subscription-heading-row">
        <div>
          <span className="subscription-kicker">Choose your plan</span>
          <h2>Simple billing for your club</h2>
          <p>Compare the proposed subscription experience before pricing and Stripe payments are enabled.</p>
        </div>
        <div className="subscription-billing-switch" aria-label="Billing frequency" role="group">
          <button
            aria-pressed={billingPeriod === "monthly"}
            className={billingPeriod === "monthly" ? "active" : ""}
            type="button"
            onClick={() => setBillingPeriod("monthly")}
          >
            Monthly
          </button>
          <button
            aria-pressed={billingPeriod === "annual"}
            className={billingPeriod === "annual" ? "active" : ""}
            type="button"
            onClick={() => setBillingPeriod("annual")}
          >
            Annual
          </button>
        </div>
      </div>

      <div className="subscription-plan-grid">
        {PLAN_DETAILS.map((plan) => {
          const isCurrent = plan.id === currentPlan;
          const isPro = plan.id === "club_pro";
          return (
            <article className={`subscription-plan-card${isPro ? " subscription-plan-card--featured" : ""}`} key={plan.id}>
              {isPro ? <span className="subscription-plan-card__flag">Preview tier</span> : null}
              <span className="subscription-kicker">{plan.eyebrow}</span>
              <h3>{plan.name}</h3>
              <div className="subscription-plan-card__price">
                <strong>Pricing to be confirmed</strong>
                <span>{billingPeriod === "annual" ? "billed annually" : "billed monthly"}</span>
              </div>
              <p>{plan.description}</p>
              <ul>
                {plan.features.map((feature) => <li key={feature}>{feature}</li>)}
              </ul>
              <button
                className={isCurrent ? "secondary" : ""}
                type="button"
                onClick={() => setSelectedPlan(plan.id)}
              >
                {isCurrent ? "Review current plan" : `Choose ${plan.name}`}
              </button>
            </article>
          );
        })}
      </div>

      <section className="subscription-confidence-row" aria-label="Subscription benefits">
        <div><strong>Secure checkout</strong><span>Payment details would be handled by Stripe.</span></div>
        <div><strong>Automatic renewal</strong><span>Renewal terms would be shown before purchase.</span></div>
        <div><strong>Manage online</strong><span>Invoices, payment methods and cancellation in one place.</span></div>
      </section>

      {selectedPlanDetails ? (
        <div className="subscription-checkout-backdrop" role="presentation" onMouseDown={() => setSelectedPlan(null)}>
          <section
            aria-labelledby="subscription-checkout-title"
            aria-modal="true"
            className="subscription-checkout"
            role="dialog"
            onMouseDown={(event) => event.stopPropagation()}
          >
            <button
              aria-label="Close subscription review"
              className="subscription-checkout__close"
              type="button"
              onClick={() => setSelectedPlan(null)}
            >
              ×
            </button>
            <span className="subscription-kicker">Checkout preview</span>
            <h2 id="subscription-checkout-title">Review your subscription</h2>
            <p className="subscription-checkout__intro">
              This is the screen a club administrator would see before continuing to Stripe.
            </p>

            <div className="subscription-checkout__summary">
              <div><span>Plan</span><strong>{selectedPlanDetails.name}</strong></div>
              <div><span>Billing</span><strong>{billingPeriod === "annual" ? "Annual" : "Monthly"}</strong></div>
              <div><span>Price</span><strong>To be confirmed</strong></div>
            </div>

            <div className="field subscription-checkout__email">
              <label htmlFor="subscription-billing-email">Billing email</label>
              <input id="subscription-billing-email" readOnly value={accountEmail || "Club account email"} />
              <small>Receipts and renewal notices would be sent here.</small>
            </div>

            <label className="subscription-checkout__agreement">
              <input disabled type="checkbox" />
              <span>
                I understand this subscription would renew automatically until cancelled. Final price and renewal terms will appear here before payments go live.
              </span>
            </label>

            <button className="subscription-checkout__stripe" disabled type="button">
              Continue to secure payment
            </button>
            <p className="subscription-checkout__disabled-note">Disabled in this frontend-only preview.</p>
          </section>
        </div>
      ) : null}
    </section>
  );
}
