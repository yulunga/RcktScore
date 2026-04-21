import React, { useEffect, useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";

import AppFooter from "../components/AppFooter";
import RootAdminSessionBar from "../components/RootAdminSessionBar";
import { useRootAdmin } from "../hooks/useRootAdmin";
import {
  createRootAdminOrganization,
  getRootAdminDashboard,
  searchRootAdminOrganizations,
} from "../services/api";

const emptyOrganizationForm = {
  organization_name: "",
  org_address: "",
  org_postcode: "",
  org_contact: "",
  org_telephone: "",
  org_email: "",
  org_webaddress: "",
};

const WEBSITE_PREFIX = "http://";

function stripWebsitePrefix(value) {
  return value.replace(/^https?:\/\//i, "");
}

function formatWebsiteForSave(value) {
  const trimmedValue = value.trim();
  if (!trimmedValue) {
    return "";
  }

  return `${WEBSITE_PREFIX}${stripWebsitePrefix(trimmedValue)}`;
}

export default function RootAdminDashboardPage() {
  const navigate = useNavigate();
  useRootAdmin();
  const [dashboard, setDashboard] = useState(null);
  const [organizationForm, setOrganizationForm] = useState(emptyOrganizationForm);
  const [searchTerm, setSearchTerm] = useState("");
  const [searchResults, setSearchResults] = useState([]);
  const [searching, setSearching] = useState(false);
  const [showCreateOverlay, setShowCreateOverlay] = useState(false);
  const [loading, setLoading] = useState(true);
  const [savingSection, setSavingSection] = useState("");
  const [message, setMessage] = useState("");
  const [error, setError] = useState("");

  async function loadDashboard() {
    setLoading(true);
    setError("");
    try {
      const response = await getRootAdminDashboard();
      setDashboard(response.rootAdminDashboard || null);
    } catch (requestError) {
      setError(requestError.message || "Failed to load root admin dashboard.");
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    loadDashboard();
  }, []);

  useEffect(() => {
    const trimmedSearch = searchTerm.trim();
    if (!trimmedSearch) {
      setSearchResults([]);
      setSearching(false);
      return undefined;
    }

    const timeoutId = window.setTimeout(async () => {
      setSearching(true);
      try {
        const response = await searchRootAdminOrganizations(trimmedSearch);
        setSearchResults(response.organizations || []);
      } catch (requestError) {
        setError(requestError.message || "Failed to search clubs.");
      } finally {
        setSearching(false);
      }
    }, 220);

    return () => window.clearTimeout(timeoutId);
  }, [searchTerm]);

  async function runMutation(section, task, successMessage) {
    setSavingSection(section);
    setMessage("");
    setError("");
    try {
      await task();
      await loadDashboard();
      setMessage(successMessage);
    } catch (requestError) {
      setError(requestError.message || "Request failed.");
    } finally {
      setSavingSection("");
    }
  }

  async function handleCreateOrganization(event) {
    event.preventDefault();
    const payload = {
      ...organizationForm,
      org_webaddress: formatWebsiteForSave(organizationForm.org_webaddress),
    };

    await runMutation(
      "create-organization",
      () => createRootAdminOrganization(payload),
      "Organisation created.",
    );
    setOrganizationForm(emptyOrganizationForm);
    setShowCreateOverlay(false);
  }

  const organizations = useMemo(
    () =>
      [...(dashboard?.organizations || [])].sort((left, right) =>
        (left.organization_name || "").localeCompare(right.organization_name || "", undefined, {
          sensitivity: "base",
        }),
      ),
    [dashboard?.organizations],
  );
  const summary = dashboard?.summary || {};
  const visibleClubs = searchTerm.trim() ? searchResults : organizations;

  return (
    <main className="page-shell stack">
      <RootAdminSessionBar />

      <section className="hero-card stack compact">
        <h1>Platform Control Centre</h1>
        <p className="helper-text">
          Manage tenant organisations and their users from one top-level administration portal.
        </p>
        <div className="meta-grid">
          <div className="meta-item">
            <strong>Organisations</strong>
            <div>{summary.organization_count ?? 0}</div>
          </div>
          <div className="meta-item">
            <strong>Org Users</strong>
            <div>{summary.user_count ?? 0}</div>
          </div>
          <div className="meta-item">
            <strong>Top Level Admin</strong>
            <div>{summary.admin_count ?? 0}</div>
          </div>
          <div className="meta-item">
            <strong>Interested Users</strong>
            <button
              className="root-admin-summary-count"
              type="button"
              onClick={() => navigate("/rckscoreAdmin/interests")}
            >
              {summary.interest_count ?? 0}
            </button>
            <span className="root-admin-summary-note">
              Pending {summary.pending_interest_count ?? 0}
            </span>
          </div>
        </div>
      </section>

      {loading ? <div className="notice">Loading root admin dashboard...</div> : null}
      {message ? <div className="notice settings-success">{message}</div> : null}
      {error ? <div className="notice error">{error}</div> : null}

      <section className="panel stack">
        <div className="root-admin-section-header">
          <h2>Club Directory</h2>
          <div className="button-row root-admin-actions">
            <button type="button" onClick={() => setShowCreateOverlay(true)}>
              New Club
            </button>
          </div>
        </div>

        <div className="root-admin-search root-admin-search-wide">
          <input
            aria-label="Search by Club Name"
            id="root_admin_search"
            placeholder="Search by Club Name"
            value={searchTerm}
            onChange={(event) => {
              setSearchTerm(event.target.value);
              if (error) {
                setError("");
              }
            }}
          />

          {searchTerm.trim() ? (
            <div className="root-admin-search-results">
              {searching ? (
                <div className="root-admin-search-item helper-text">Searching...</div>
              ) : visibleClubs.length === 0 ? (
                <div className="root-admin-search-item helper-text">No matching clubs found.</div>
              ) : (
                visibleClubs.map((organization) => (
                  <button
                    key={organization.id}
                    className="root-admin-search-item"
                    type="button"
                    onClick={() => navigate(`/rckscoreAdmin/clubs/${organization.id}`)}
                  >
                    <strong>{organization.organization_name || `Organisation ${organization.id}`}</strong>
                    <span>{organization.org_email || organization.org_contact || `Tenant ${organization.id}`}</span>
                  </button>
                ))
              )}
            </div>
          ) : null}
        </div>

        <div className="root-admin-club-list">
          {organizations.length === 0 ? (
            <div className="dashboard-empty">No organisations have been created yet.</div>
          ) : (
            organizations.map((organization) => (
              <button
                key={organization.id}
                className="root-admin-club-row"
                type="button"
                onClick={() => navigate(`/rckscoreAdmin/clubs/${organization.id}`)}
              >
                <div>
                  <strong>{organization.organization_name || `Organisation ${organization.id}`}</strong>
                  <span>{organization.org_email || organization.org_contact || "No primary contact set"}</span>
                </div>
                <div className="root-admin-club-meta">
                  <span>Users {organization.user_count ?? 0}</span>
                  <span>Courts {organization.court_count ?? 0}</span>
                  <span>Admins {organization.admin_count ?? 0}</span>
                </div>
              </button>
            ))
          )}
        </div>
      </section>

      {showCreateOverlay ? (
        <div className="overlay-backdrop" role="presentation" onClick={() => setShowCreateOverlay(false)}>
          <section
            className="overlay-panel stack"
            role="dialog"
            aria-modal="true"
            aria-labelledby="new-club-title"
            onClick={(event) => event.stopPropagation()}
          >
            <div className="panel-heading">
              <h2 id="new-club-title">New Club</h2>
              <p className="helper-text">Create a new tenant organisation for the platform.</p>
            </div>

            <form className="stack" onSubmit={handleCreateOrganization}>
              <div className="field-grid">
                <div className="field">
                  <label htmlFor="root_org_name">Club Name</label>
                  <input
                    id="root_org_name"
                    required
                    value={organizationForm.organization_name}
                    onChange={(event) =>
                      setOrganizationForm((current) => ({
                        ...current,
                        organization_name: event.target.value,
                      }))}
                  />
                </div>
                <div className="field">
                  <label htmlFor="root_org_contact">Primary Contact</label>
                  <input
                    id="root_org_contact"
                    value={organizationForm.org_contact}
                    onChange={(event) =>
                      setOrganizationForm((current) => ({ ...current, org_contact: event.target.value }))}
                  />
                </div>
                <div className="field">
                  <label htmlFor="root_org_telephone">Telephone</label>
                  <input
                    id="root_org_telephone"
                    value={organizationForm.org_telephone}
                    onChange={(event) =>
                      setOrganizationForm((current) => ({ ...current, org_telephone: event.target.value }))}
                  />
                </div>
                <div className="field">
                  <label htmlFor="root_org_email">Email</label>
                  <input
                    id="root_org_email"
                    type="email"
                    value={organizationForm.org_email}
                    onChange={(event) =>
                      setOrganizationForm((current) => ({ ...current, org_email: event.target.value }))}
                  />
                </div>
                <div className="field settings-field-wide">
                  <label htmlFor="root_org_web">Website</label>
                  <div className="prefixed-input">
                    <span className="prefixed-input__label">{WEBSITE_PREFIX}</span>
                    <input
                      id="root_org_web"
                      type="text"
                      value={organizationForm.org_webaddress}
                      onChange={(event) =>
                        setOrganizationForm((current) => ({
                          ...current,
                          org_webaddress: stripWebsitePrefix(event.target.value),
                        }))}
                    />
                  </div>
                </div>
                <div className="field settings-field-wide">
                  <label htmlFor="root_org_address">Address</label>
                  <input
                    id="root_org_address"
                    value={organizationForm.org_address}
                    onChange={(event) =>
                      setOrganizationForm((current) => ({ ...current, org_address: event.target.value }))}
                  />
                </div>
                <div className="field">
                  <label htmlFor="root_org_postcode">Postcode</label>
                  <input
                    id="root_org_postcode"
                    value={organizationForm.org_postcode}
                    onChange={(event) =>
                      setOrganizationForm((current) => ({ ...current, org_postcode: event.target.value }))}
                  />
                </div>
              </div>

              <div className="button-row">
                <button disabled={savingSection === "create-organization"} type="submit">
                  {savingSection === "create-organization" ? "Creating..." : "Create Club"}
                </button>
                <button
                  className="secondary"
                  type="button"
                  onClick={() => {
                    setShowCreateOverlay(false);
                    setOrganizationForm(emptyOrganizationForm);
                  }}
                >
                  Cancel
                </button>
              </div>
            </form>
          </section>
        </div>
      ) : null}

      <AppFooter />
    </main>
  );
}
