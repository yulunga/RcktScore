import React, { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { useNavigate, useSearchParams } from "react-router-dom";

import AppFooter from "../components/AppFooter";
import ClubPageHeader from "../components/ClubPageHeader";
import SubscriptionPreview from "../components/SubscriptionPreview";
import { COUNTRIES } from "../constants/countries";
import { MATCH_SPORT_OPTIONS, getMatchSportOption, normalizeEnabledSports } from "../constants/matchSports";
import { useAuth } from "../hooks/useAuth";
import {
  createOrganizationCourt,
  createOrganizationCourtDisplayCode,
  createOrganizationUser,
  deleteOrganizationCourt,
  getOrganizationSettings,
  requestPasswordReset,
  updatePersonalProfile,
  updateOrganizationCourt,
  updateOrganizationDetails,
} from "../services/api";

const emptyOrganizationForm = {
  organization_name: "",
  org_address: "",
  org_contact: "",
  org_telephone: "",
  org_email: "",
  org_webaddress: "",
};

const emptyUserForm = {
  first_name: "",
  surname: "",
  username: "",
  password: "",
  role: "user",
};

const emptyCourtForm = {
  court_name: "",
  court_alias: "",
  sport: "squash",
};
const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const EMPTY_TIMED_BREAK_DEFAULTS = {
  squash: false,
  racketball: false,
  tennis: false,
  padel: false,
};
const SETTINGS_TABS = [
  { id: "organisation", label: "Organisation" },
  { id: "courts", label: "Courts" },
  { id: "users", label: "Users" },
  { id: "game-social", label: "Game Settings" },
  { id: "subscriptions", label: "Subscriptions" },
  { id: "tournament-manager", label: "Tournament Manager", requiresTournament: true },
];
const ADD_FORM_INACTIVITY_MS = 60 * 1000;

function formatDate(value) {
  if (!value) {
    return "Unknown";
  }

  return new Intl.DateTimeFormat("en-GB", {
    dateStyle: "medium",
    timeStyle: "short",
  }).format(new Date(value));
}

function formatUserDisplayName(user) {
  return [user?.first_name, user?.surname].filter(Boolean).join(" ").trim() || "";
}

function primaryContactValue(user) {
  return formatUserDisplayName(user) || user?.username || "";
}

function getMatchSportLabel(value) {
  return getMatchSportOption(value)?.label || (value ? String(value) : "All sports");
}

export default function OrganisationSettingsPage() {
  const navigate = useNavigate();
  const [searchParams, setSearchParams] = useSearchParams();
  const { session } = useAuth();
  const [settings, setSettings] = useState(null);
  const [organizationForm, setOrganizationForm] = useState(emptyOrganizationForm);
  const [personalProfileForm, setPersonalProfileForm] = useState({
    first_name: "",
    surname: "",
    country: "",
    city_location: "",
  });
  const [userForm, setUserForm] = useState(emptyUserForm);
  const [courtForm, setCourtForm] = useState(emptyCourtForm);
  const [courtDrafts, setCourtDrafts] = useState({});
  const [enabledSports, setEnabledSports] = useState(() => normalizeEnabledSports());
  const [timedBreakDefaults, setTimedBreakDefaults] = useState(EMPTY_TIMED_BREAK_DEFAULTS);
  const [loading, setLoading] = useState(true);
  const [savingSection, setSavingSection] = useState("");
  const [message, setMessage] = useState("");
  const [error, setError] = useState("");
  const [countryQuery, setCountryQuery] = useState("");
  const [showCountrySuggestions, setShowCountrySuggestions] = useState(false);
  const [activeCountryIndex, setActiveCountryIndex] = useState(-1);
  const [primaryContactQuery, setPrimaryContactQuery] = useState("");
  const [primaryContactUserId, setPrimaryContactUserId] = useState(null);
  const [showPrimaryContactSuggestions, setShowPrimaryContactSuggestions] = useState(false);
  const [addUserOpen, setAddUserOpen] = useState(false);
  const [addUserActivity, setAddUserActivity] = useState(0);
  const [userSearchQuery, setUserSearchQuery] = useState("");
  const [addCourtOpen, setAddCourtOpen] = useState(false);
  const [addCourtActivity, setAddCourtActivity] = useState(0);
  const [editingCourtId, setEditingCourtId] = useState(null);
  const [courtSportFilter, setCourtSportFilter] = useState("");
  const [activeGameSettingsTile, setActiveGameSettingsTile] = useState("");
  const settingsTabRefs = useRef({});
  const initialTab = searchParams.get("tab");
  const [activeTab, setActiveTab] = useState(
    SETTINGS_TABS.some((tab) => tab.id === initialTab) ? initialTab : "organisation",
  );

  const organizationId = session?.organization_id;
  const isAdmin = session?.role === "admin";
  const isPersonalSession = session?.organization_type === "personal";
  const isPersonalAccount = isPersonalSession || settings?.organization?.org_type === "personal";
  const users = settings?.users || [];
  const tournamentManagerEnabled = !isPersonalAccount
    && Boolean(settings?.organization?.features?.tournament_manager?.web_enabled);
  const visibleAdminTabs = useMemo(
    () => SETTINGS_TABS.filter((tab) => !tab.requiresTournament || tournamentManagerEnabled),
    [tournamentManagerEnabled],
  );
  const scoreboardUrl = useMemo(() => {
    if (typeof window === "undefined") {
      return "/scoreboard";
    }

    return `${window.location.origin}/scoreboard`;
  }, []);

  useEffect(() => {
    if (organizationId && !isAdmin && !isPersonalSession) {
      navigate("/dashboard", { replace: true });
    }
  }, [isAdmin, isPersonalSession, navigate, organizationId]);

  const mapUrl = useMemo(() => {
    const address = organizationForm.org_address || settings?.organization?.org_address;
    if (!address) {
      return "";
    }

    return `https://www.google.com/maps?q=${encodeURIComponent(address)}&output=embed`;
  }, [organizationForm.org_address, settings?.organization?.org_address]);
  const filteredCountries = useMemo(() => {
    const query = countryQuery.trim().toLowerCase();
    if (!query) {
      return COUNTRIES.slice(0, 8);
    }

    return COUNTRIES.filter((country) => country.toLowerCase().includes(query)).slice(0, 8);
  }, [countryQuery]);
  const primaryContactSuggestions = useMemo(() => {
    const query = primaryContactQuery.trim().toLowerCase();
    if (!query) return [];
    return users
      .filter((user) => (user.status || "approved") === "approved")
      .filter((user) => (
        primaryContactValue(user).toLowerCase().includes(query)
        || String(user.username || "").toLowerCase().includes(query)
      ))
      .slice(0, 8);
  }, [primaryContactQuery, users]);
  const sortedFilteredUsers = useMemo(() => {
    const query = userSearchQuery.trim().toLowerCase();
    return [...users]
      .filter((user) => !query || [user.first_name, user.surname, user.username]
        .some((value) => String(value || "").toLowerCase().includes(query)))
      .sort((left, right) => (
        String(left.surname || "").localeCompare(String(right.surname || ""), undefined, { sensitivity: "base" })
        || String(left.first_name || "").localeCompare(String(right.first_name || ""), undefined, { sensitivity: "base" })
        || String(left.username || "").localeCompare(String(right.username || ""), undefined, { sensitivity: "base" })
      ));
  }, [userSearchQuery, users]);
  const courtSportOptions = useMemo(
    () => MATCH_SPORT_OPTIONS.filter((sport) => sport.implemented && enabledSports.includes(sport.value)),
    [enabledSports],
  );
  const courts = settings?.courts || [];
  const filteredCourts = useMemo(() => courts.filter((court) => (
    !courtSportFilter || court.sport === courtSportFilter || !court.sport
  )).sort((left, right) => (
    String(left.sport || "").localeCompare(String(right.sport || ""))
    || String(left.court_name || "").localeCompare(String(right.court_name || ""), undefined, { sensitivity: "base" })
  )), [courtSportFilter, courts]);
  useEffect(() => {
    if (!addUserOpen) return undefined;
    const timeoutId = window.setTimeout(() => setAddUserOpen(false), ADD_FORM_INACTIVITY_MS);
    return () => window.clearTimeout(timeoutId);
  }, [addUserActivity, addUserOpen]);

  useEffect(() => {
    if (!addCourtOpen) return undefined;
    const timeoutId = window.setTimeout(() => setAddCourtOpen(false), ADD_FORM_INACTIVITY_MS);
    return () => window.clearTimeout(timeoutId);
  }, [addCourtActivity, addCourtOpen]);

  useEffect(() => {
    if (!showCountrySuggestions || filteredCountries.length === 0) {
      setActiveCountryIndex(-1);
      return;
    }

    setActiveCountryIndex(0);
  }, [filteredCountries, showCountrySuggestions]);

  if (organizationId && !isAdmin && !isPersonalSession) {
    return null;
  }

  function handleTabChange(nextTab) {
    setAddUserOpen(false);
    setAddCourtOpen(false);
    setEditingCourtId(null);
    setActiveTab(nextTab);
    setSearchParams({ tab: nextTab }, { replace: true });
  }

  const syncLocalState = useCallback((response) => {
    const nextSettings = response?.organizationSettings || response || null;

    setSettings(nextSettings);
    setOrganizationForm({
      organization_name: nextSettings?.organization?.organization_name || "",
      org_address: nextSettings?.organization?.org_address || "",
      org_contact: nextSettings?.organization?.org_contact || "",
      org_telephone: nextSettings?.organization?.org_telephone || "",
      org_email: nextSettings?.organization?.org_email || "",
      org_webaddress: nextSettings?.organization?.org_webaddress || "",
    });
    const savedContact = nextSettings?.organization?.org_contact || "";
    const matchingContact = (nextSettings?.users || []).find((user) => (
      primaryContactValue(user).toLowerCase() === savedContact.toLowerCase()
      || String(user.username || "").toLowerCase() === savedContact.toLowerCase()
    ));
    setPrimaryContactQuery(savedContact);
    setPrimaryContactUserId(matchingContact?.id || null);
    const nextEnabledSports = normalizeEnabledSports(nextSettings?.organization?.enabled_sports);
    setCourtDrafts(
      Object.fromEntries(
        (nextSettings?.courts || []).map((court) => [
          court.id,
          {
            court_name: court.court_name || "",
            court_alias: court.court_alias || "",
            sport: court.sport || "",
          },
        ]),
      ),
    );
    setEnabledSports(nextEnabledSports);
    setCourtForm((current) => ({
      ...current,
      sport: nextEnabledSports.includes(current.sport) ? current.sport : (nextEnabledSports[0] || "squash"),
    }));
    setTimedBreakDefaults({
      ...EMPTY_TIMED_BREAK_DEFAULTS,
      ...(nextSettings?.organization?.timed_break_defaults || {}),
    });
  }, []);

  const loadSettings = useCallback(async () => {
    if (!organizationId) {
      setLoading(false);
      return;
    }

    setLoading(true);
    setError("");
    try {
      const response = await getOrganizationSettings(organizationId);
      syncLocalState(response);
    } catch (requestError) {
      setError(requestError.message || "Failed to load organisation settings.");
    } finally {
      setLoading(false);
    }
  }, [organizationId, syncLocalState]);

  useEffect(() => {
    loadSettings();
  }, [loadSettings]);

  useEffect(() => {
    if (!settings) {
      return;
    }
    const requestedTab = searchParams.get("tab");
    if (requestedTab && visibleAdminTabs.some((tab) => tab.id === requestedTab) && requestedTab !== activeTab) {
      setActiveTab(requestedTab);
    } else if (requestedTab === "tournament-manager" && !tournamentManagerEnabled) {
      setActiveTab("organisation");
      setSearchParams({ tab: "organisation" }, { replace: true });
    }
  }, [activeTab, searchParams, setSearchParams, settings, tournamentManagerEnabled, visibleAdminTabs]);

  useEffect(() => {
    if (isPersonalAccount) return undefined;
    const frameId = window.requestAnimationFrame(() => {
      settingsTabRefs.current[activeTab]?.scrollIntoView({
        behavior: "smooth",
        block: "nearest",
        inline: "center",
      });
    });
    return () => window.cancelAnimationFrame(frameId);
  }, [activeTab, isPersonalAccount, settings, visibleAdminTabs]);

  async function runMutation(section, task, successMessage) {
    setSavingSection(section);
    setMessage("");
    setError("");
    try {
      await task();
      await loadSettings();
      setMessage(successMessage);
    } catch (requestError) {
      setError(requestError.message || "Request failed.");
    } finally {
      setSavingSection("");
    }
  }

  function toggleEnabledSport(sportValue) {
    setEnabledSports((current) => (
      current.includes(sportValue)
        ? current.filter((value) => value !== sportValue)
        : [...current, sportValue]
    ));
  }

  async function handleEnabledSportsSave() {
    await runMutation(
      "enabled-sports",
      () => updateOrganizationDetails(organizationId, { enabled_sports: enabledSports }),
      "Enabled racket sports updated.",
    );
  }

  function toggleTimedBreakDefault(sportValue) {
    setTimedBreakDefaults((current) => ({
      ...current,
      [sportValue]: !current[sportValue],
    }));
  }

  async function handleTimedBreakDefaultsSave() {
    await runMutation(
      "timed-break-defaults",
      () => updateOrganizationDetails(organizationId, { timed_break_defaults: timedBreakDefaults }),
      "Per-sport timer defaults updated.",
    );
  }

  function renderTimedBreakDefaults() {
    const sports = MATCH_SPORT_OPTIONS.filter((sport) => sport.implemented && enabledSports.includes(sport.value));
    return (
      <>
        <div className="panel-heading">
          <h2>Timer Defaults</h2>
          <p className="helper-text">
            Choose which sports preselect timed warm-ups and breaks when a new match is created. A disabled default can still be enabled for an individual match.
          </p>
        </div>
        <div className="sport-grid">
          {sports.map((sport) => (
            <article className={`sport-option${timedBreakDefaults[sport.value] ? " active" : " disabled"}`} key={`timer-${sport.value}`}>
              <strong>{sport.label}</strong>
              <span>{timedBreakDefaults[sport.value] ? "Timer default on" : "Timer default off"}</span>
              <button
                className={timedBreakDefaults[sport.value] ? "secondary" : ""}
                disabled={(!isAdmin && !isPersonalAccount) || savingSection === "timed-break-defaults"}
                type="button"
                onClick={() => toggleTimedBreakDefault(sport.value)}
              >
                {timedBreakDefaults[sport.value] ? "Default Off" : "Default On"}
              </button>
            </article>
          ))}
        </div>
        {(isAdmin || isPersonalAccount) ? (
          <div className="button-row">
            <button disabled={savingSection === "timed-break-defaults"} type="button" onClick={handleTimedBreakDefaultsSave}>
              {savingSection === "timed-break-defaults" ? "Saving..." : "Save Timer Defaults"}
            </button>
          </div>
        ) : null}
      </>
    );
  }

  async function handleOrganizationSubmit(event) {
    event.preventDefault();
    if (primaryContactQuery.trim() && !primaryContactUserId) {
      setMessage("");
      setError("Choose the primary contact from an approved organisation member.");
      return;
    }
    await runMutation(
      "organization",
      () => updateOrganizationDetails(organizationId, organizationForm),
      "Organisation details updated.",
    );
  }

  async function handleUserSubmit(event) {
    event.preventDefault();
    const normalizedUsername = userForm.username.trim().toLowerCase();

    if (!EMAIL_PATTERN.test(normalizedUsername)) {
      setMessage("");
      setError("Enter a valid email address for the user.");
      return;
    }

    await runMutation(
      "user-create",
      () => createOrganizationUser({
        organization_id: organizationId,
        first_name: userForm.first_name,
        surname: userForm.surname,
        username: normalizedUsername,
        password: userForm.password,
        role: userForm.role,
      }),
      "User added to organisation. Invitation email sent and access is pending approval.",
    );
    setUserForm(emptyUserForm);
    setAddUserOpen(false);
  }

  async function handleCourtCreate(event) {
    event.preventDefault();
    await runMutation(
      "court-create",
      () => createOrganizationCourt({
        organization_id: organizationId,
        court_name: courtForm.court_name,
        court_alias: courtForm.court_alias,
        sport: courtForm.sport,
      }),
      "Court created.",
    );
    setCourtForm({
      ...emptyCourtForm,
      sport: courtSportOptions[0]?.value || "squash",
    });
    setAddCourtOpen(false);
  }

  async function handleCourtSave(courtId) {
    await runMutation(
      `court-save-${courtId}`,
      () => updateOrganizationCourt(courtId, {
        organization_id: organizationId,
        court_name: courtDrafts[courtId]?.court_name || "",
        court_alias: courtDrafts[courtId]?.court_alias || "",
        sport: courtDrafts[courtId]?.sport || "",
      }),
      "Court updated.",
    );
    setEditingCourtId(null);
  }

  async function handleCourtDelete(courtId) {
    await runMutation(
      `court-delete-${courtId}`,
      () => deleteOrganizationCourt(courtId, { organization_id: organizationId }),
      "Court deleted.",
    );
    setEditingCourtId(null);
  }

  async function handleCourtDisplayCode(courtId) {
    await runMutation(
      `court-display-code-${courtId}`,
      () => createOrganizationCourtDisplayCode(courtId, { organization_id: organizationId }),
      "Court display code updated.",
    );
  }

  const currentPersonalUser = users.find(
    (user) => user.username?.toLowerCase() === session?.username?.toLowerCase(),
  ) || {};
  const personalEmail = session?.email || currentPersonalUser.username || session?.username || "";
  const personalPlan = settings?.organization?.plan || session?.plan || "personal_free";
  const personalPlanLabel = personalPlan === "personal_plus" ? "Personal+" : "Personal Free";
  const personalHistoryLimit = settings?.organization?.available_plan_entitlements?.personal_plus?.history_limit
    ?? (personalPlan === "personal_plus" ? settings?.organization?.entitlements?.history_limit : null)
    ?? 100;
  useEffect(() => {
    if (!isPersonalAccount) {
      return;
    }

    setPersonalProfileForm({
      first_name: currentPersonalUser.first_name || session?.first_name || "",
      surname: currentPersonalUser.surname || session?.surname || "",
      country: currentPersonalUser.country || "",
      city_location: currentPersonalUser.city_location || "",
    });
    setCountryQuery(currentPersonalUser.country || "");
    setActiveCountryIndex(-1);
  }, [
    currentPersonalUser.city_location,
    currentPersonalUser.country,
    currentPersonalUser.first_name,
    currentPersonalUser.surname,
    isPersonalAccount,
    session?.first_name,
    session?.surname,
  ]);

  async function handlePersonalProfileSubmit(event) {
    event.preventDefault();
    if (countryQuery.trim() && !personalProfileForm.country) {
      setMessage("");
      setError("Choose a country from the search results.");
      return;
    }

    await runMutation(
      "personal-profile",
      () => updatePersonalProfile(organizationId, {
        username: session?.username,
        first_name: personalProfileForm.first_name,
        surname: personalProfileForm.surname,
        country: personalProfileForm.country,
        city_location: personalProfileForm.city_location,
      }),
      "Profile updated.",
    );
  }

  async function handlePersonalPasswordResetRequest() {
    const resetEmail = String(personalEmail || "").trim().toLowerCase();

    if (!EMAIL_PATTERN.test(resetEmail)) {
      setMessage("");
      setError("A valid account email is required before a password reset can be sent.");
      return;
    }

    setSavingSection("personal-password-reset");
    setMessage("");
    setError("");

    try {
      await requestPasswordReset({ email: resetEmail });
      setMessage("If that email is registered, a password reset link has been sent.");
    } catch (requestError) {
      setError(requestError.message || "Unable to request password reset right now.");
    } finally {
      setSavingSection("");
    }
  }

  function handleCountryInputChange(value) {
    setCountryQuery(value);
    setShowCountrySuggestions(true);
    setActiveCountryIndex(0);
    setPersonalProfileForm((current) => ({
      ...current,
      country: "",
    }));
  }

  function handleCountrySelect(country) {
    setCountryQuery(country);
    setShowCountrySuggestions(false);
    setActiveCountryIndex(-1);
    setPersonalProfileForm((current) => ({
      ...current,
      country,
    }));
  }

  function handleCountryKeyDown(event) {
    if (!showCountrySuggestions && ["ArrowDown", "ArrowUp"].includes(event.key)) {
      if (filteredCountries.length > 0) {
        event.preventDefault();
        setShowCountrySuggestions(true);
        setActiveCountryIndex(0);
      }
      return;
    }

    if (!showCountrySuggestions || filteredCountries.length === 0) {
      if (event.key === "Escape") {
        setShowCountrySuggestions(false);
      }
      return;
    }

    if (event.key === "ArrowDown") {
      event.preventDefault();
      setActiveCountryIndex((current) => (current + 1) % filteredCountries.length);
      return;
    }

    if (event.key === "ArrowUp") {
      event.preventDefault();
      setActiveCountryIndex((current) => (current <= 0 ? filteredCountries.length - 1 : current - 1));
      return;
    }

    if (event.key === "Enter") {
      if (activeCountryIndex >= 0 && activeCountryIndex < filteredCountries.length) {
        event.preventDefault();
        handleCountrySelect(filteredCountries[activeCountryIndex]);
      }
      return;
    }

    if (event.key === "Escape") {
      event.preventDefault();
      setShowCountrySuggestions(false);
      setActiveCountryIndex(-1);
    }
  }

  return (
    <main className="page-shell stack">
      <ClubPageHeader />

      {!isAdmin && !isPersonalAccount ? (
        <div className="notice">You are in view-only mode. Only organisation admins can save changes.</div>
      ) : null}
      {loading ? <div className="notice">Loading organisation settings...</div> : null}
      {message ? <div className="notice settings-success">{message}</div> : null}
      {error ? <div className="notice error">{error}</div> : null}

      {isPersonalAccount ? (
        <section className="settings-grid">
          <section className="panel stack settings-primary">
            <div className="panel-heading">
              <h2>Profile</h2>
              <p className="helper-text">Basic account details.</p>
            </div>
            <form className="stack" onSubmit={handlePersonalProfileSubmit}>
              <div className="field-grid settings-profile-grid">
                <div className="field settings-profile-field--solo">
                  <label htmlFor="personal_username">Username</label>
                  <input
                    className="settings-input-compact"
                    id="personal_username"
                    readOnly
                    value={session?.username || "Not available"}
                  />
                </div>
                <div className="field">
                  <label htmlFor="personal_first_name">Name</label>
                  <input
                    id="personal_first_name"
                    placeholder="Name"
                    value={personalProfileForm.first_name}
                    onChange={(event) => setPersonalProfileForm((current) => ({
                      ...current,
                      first_name: event.target.value,
                    }))}
                  />
                </div>
                <div className="field">
                  <label htmlFor="personal_surname">Surname</label>
                  <input
                    id="personal_surname"
                    placeholder="Surname"
                    value={personalProfileForm.surname}
                    onChange={(event) => setPersonalProfileForm((current) => ({
                      ...current,
                      surname: event.target.value,
                    }))}
                  />
                </div>
                <div className="field settings-profile-field--solo">
                  <label htmlFor="personal_email">Email</label>
                  <input
                    className="settings-input-compact"
                    id="personal_email"
                    readOnly
                    value={personalEmail || "Not available"}
                  />
                </div>
                <div className="field">
                  <label htmlFor="personal_city_location">City / Location</label>
                  <input
                    id="personal_city_location"
                    placeholder="City or location"
                    value={personalProfileForm.city_location}
                    onChange={(event) => setPersonalProfileForm((current) => ({
                      ...current,
                      city_location: event.target.value,
                    }))}
                  />
                </div>
                <div className="field">
                  <label htmlFor="personal_country">Country</label>
                  <input
                    aria-activedescendant={
                      showCountrySuggestions && activeCountryIndex >= 0
                        ? `personal-country-option-${activeCountryIndex}`
                        : undefined
                    }
                    aria-autocomplete="list"
                    aria-controls="personal-country-suggestions"
                    aria-expanded={showCountrySuggestions ? "true" : "false"}
                    autoComplete="off"
                    id="personal_country"
                    placeholder="Search country"
                    role="combobox"
                    value={countryQuery}
                    onBlur={() => {
                      window.setTimeout(() => {
                        setShowCountrySuggestions(false);
                        setActiveCountryIndex(-1);
                        if (!personalProfileForm.country) {
                          setCountryQuery("");
                        }
                      }, 120);
                    }}
                    onFocus={() => setShowCountrySuggestions(true)}
                    onChange={(event) => handleCountryInputChange(event.target.value)}
                    onKeyDown={handleCountryKeyDown}
                  />
                  {showCountrySuggestions && filteredCountries.length ? (
                    <div
                      className="lookup-list settings-lookup-list"
                      id="personal-country-suggestions"
                      role="listbox"
                      aria-label="Country suggestions"
                    >
                      {filteredCountries.map((country, index) => (
                        <button
                          aria-selected={activeCountryIndex === index}
                          className={`lookup-item${activeCountryIndex === index ? " lookup-item--active" : ""}`}
                          id={`personal-country-option-${index}`}
                          key={country}
                          role="option"
                          type="button"
                          onMouseDown={(event) => event.preventDefault()}
                          onMouseEnter={() => setActiveCountryIndex(index)}
                          onClick={() => handleCountrySelect(country)}
                        >
                          {country}
                        </button>
                      ))}
                    </div>
                  ) : null}
                </div>
              </div>
              <div className="button-row">
                <button disabled={savingSection === "personal-profile"} type="submit">
                  {savingSection === "personal-profile" ? "Saving..." : "Save Profile"}
                </button>
              </div>
            </form>
          </section>

          <div className="settings-secondary-stack">
            <section className="panel stack">
              <div className="panel-heading">
                <h2>Account Access</h2>
                <p className="helper-text">
                  Send a secure password reset link to your account email.
                </p>
              </div>
              <div className="dashboard-item">
                <div className="dashboard-item-head">
                  <strong>Password Reset</strong>
                  <span className="status-pill">Email link</span>
                </div>
                <div className="dashboard-item-meta">
                  <span>{personalEmail || "No account email available"}</span>
                  <span>The link will let you choose a new password securely.</span>
                </div>
                <div className="button-row">
                  <button
                    className="personal-password-reset-button"
                    disabled={savingSection === "personal-password-reset" || !personalEmail}
                    type="button"
                    onClick={handlePersonalPasswordResetRequest}
                  >
                    {savingSection === "personal-password-reset" ? "Sending..." : "Send Reset"}
                  </button>
                </div>
              </div>
            </section>
            <section aria-hidden="true" className="panel settings-ghost-panel" />
          </div>

          <section className="panel stack">
            <article className="dashboard-item">
              <div className="dashboard-item-head">
                <strong>Current Plan</strong>
                <span className="status-pill">{personalPlanLabel}</span>
              </div>
              <div className="dashboard-item-meta">
                <span>Plan: {personalPlanLabel}</span>
                <span>Account: Single-user personal workspace</span>
              </div>
            </article>
            <div className="panel-heading panel-heading--subsection">
              <h3>Upgrade Options</h3>
              <p className="helper-text">Upgrade when you need deeper history or club tools.</p>
            </div>
            <div className="dashboard-list">
              <article className="dashboard-item">
                <div className="dashboard-item-head">
                  <strong>Personal+</strong>
                  <span className="status-pill">Paid</span>
                </div>
                <div className="dashboard-item-meta">
                  <span>Up to {personalHistoryLimit} completed matches</span>
                  <span>Performance trends, opponent records, serving results, streaks, and progress summaries.</span>
                </div>
              </article>
              <article className="dashboard-item">
                <div className="dashboard-item-head">
                  <strong>Club Subscription</strong>
                  <button
                    className="status-pill status-pill-button status-pill-button--accent"
                    type="button"
                    onClick={() => navigate("/ping?subject=club-subscription")}
                  >
                    Enquire
                  </button>
                </div>
                <div className="dashboard-item-meta">
                  <span>Multi-user club workspace with roles, courts, scheduled matches, live display, and club administration tools.</span>
                </div>
              </article>
            </div>
          </section>

          <section className="panel stack">
            {renderTimedBreakDefaults()}
          </section>
        </section>
      ) : (
        <>
          <section className="root-admin-tab-row matches-category-switch settings-category-switch" aria-label="Organisation settings sections" role="tablist">
            {visibleAdminTabs.map((tab) => (
              <button
                key={tab.id}
                aria-pressed={activeTab === tab.id}
                className={activeTab === tab.id ? "active" : ""}
                ref={(element) => {
                  settingsTabRefs.current[tab.id] = element;
                }}
                type="button"
                onClick={() => handleTabChange(tab.id)}
              >
                {tab.label}
              </button>
            ))}
          </section>

          {activeTab === "tournament-manager" && tournamentManagerEnabled ? (
            <section className="panel stack tournament-settings-card">
              <div className="panel-heading">
                <h2>Tournament Manager</h2>
                <p className="helper-text">
                  Create tournament events, register club members and visiting players, and prepare entries for draws and scheduling.
                </p>
              </div>
              <div className="dashboard-item">
                <div className="dashboard-item-head">
                  <strong>Web Tournament Manager</strong>
                  <span className="status-pill active">Enabled</span>
                </div>
                <div className="dashboard-item-meta">
                  <span>Available only while signed in to this club.</span>
                  <span>Visiting players are stored as guests without receiving club account access.</span>
                </div>
              </div>
              <div className="button-row">
                <button type="button" onClick={() => navigate("/tournaments")}>Open Tournament Manager</button>
              </div>
            </section>
          ) : null}

          {activeTab === "organisation" ? (
            <section className="club-admin-overview-grid">
              <section className="panel stack settings-primary">
                <div className="panel-heading">
                  <h2>Organisation Details</h2>
                  <p className="helper-text">Club details used for contact information and venue context.</p>
                </div>

                <form className="stack" onSubmit={handleOrganizationSubmit}>
                  <div className="field-grid">
                    <div className="field">
                      <label htmlFor="organization_name">Club Name</label>
                      <input
                        disabled={!isAdmin}
                        id="organization_name"
                        value={organizationForm.organization_name}
                        onChange={(event) => setOrganizationForm((current) => ({ ...current, organization_name: event.target.value }))}
                      />
                    </div>
                    <div className="field settings-field-wide">
                      <label htmlFor="org_address">Address</label>
                      <input
                        disabled={!isAdmin}
                        id="org_address"
                        value={organizationForm.org_address}
                        onChange={(event) => setOrganizationForm((current) => ({ ...current, org_address: event.target.value }))}
                      />
                    </div>
                    <div className="field settings-member-lookup">
                      <label htmlFor="org_contact">Primary Contact</label>
                      <input
                        aria-autocomplete="list"
                        aria-controls="primary-contact-suggestions"
                        aria-expanded={showPrimaryContactSuggestions ? "true" : "false"}
                        autoComplete="off"
                        disabled={!isAdmin}
                        id="org_contact"
                        placeholder="Search approved club members"
                        role="combobox"
                        value={primaryContactQuery}
                        onBlur={() => window.setTimeout(() => setShowPrimaryContactSuggestions(false), 120)}
                        onFocus={() => setShowPrimaryContactSuggestions(true)}
                        onChange={(event) => {
                          setPrimaryContactQuery(event.target.value);
                          setPrimaryContactUserId(null);
                          setShowPrimaryContactSuggestions(true);
                          setOrganizationForm((current) => ({ ...current, org_contact: "" }));
                        }}
                      />
                      {showPrimaryContactSuggestions && primaryContactSuggestions.length ? (
                        <div className="lookup-list settings-lookup-list" id="primary-contact-suggestions" role="listbox" aria-label="Primary contact suggestions">
                          {primaryContactSuggestions.map((user) => (
                            <button
                              className="lookup-item settings-member-lookup__option"
                              key={user.id}
                              role="option"
                              type="button"
                              onMouseDown={(event) => event.preventDefault()}
                              onClick={() => {
                                const contactName = primaryContactValue(user);
                                setPrimaryContactQuery(contactName);
                                setPrimaryContactUserId(user.id);
                                setShowPrimaryContactSuggestions(false);
                                setOrganizationForm((current) => ({ ...current, org_contact: contactName }));
                              }}
                            >
                              <strong>{primaryContactValue(user)}</strong>
                              <span>{user.username}</span>
                            </button>
                          ))}
                        </div>
                      ) : null}
                      {primaryContactQuery.trim() && !primaryContactUserId && primaryContactSuggestions.length === 0 ? (
                        <small className="field-hint field-hint--warning">
                          The primary contact must first be added as an approved HitnScore user and be part of this club.
                        </small>
                      ) : (
                        <small className="field-hint">Search by member name or email, then choose the club member.</small>
                      )}
                    </div>
                    <div className="field">
                      <label htmlFor="org_telephone">Telephone</label>
                      <input
                        disabled={!isAdmin}
                        id="org_telephone"
                        value={organizationForm.org_telephone}
                        onChange={(event) => setOrganizationForm((current) => ({ ...current, org_telephone: event.target.value }))}
                      />
                    </div>
                    <div className="field">
                      <label htmlFor="org_email">Email</label>
                      <input
                        disabled={!isAdmin}
                        id="org_email"
                        type="email"
                        value={organizationForm.org_email}
                        onChange={(event) => setOrganizationForm((current) => ({ ...current, org_email: event.target.value }))}
                      />
                    </div>
                    <div className="field settings-field-wide">
                      <label htmlFor="org_webaddress">Website</label>
                      <input
                        disabled={!isAdmin}
                        id="org_webaddress"
                        type="url"
                        value={organizationForm.org_webaddress}
                        onChange={(event) => setOrganizationForm((current) => ({ ...current, org_webaddress: event.target.value }))}
                      />
                    </div>
                  </div>

                  <div className="button-row">
                    <button disabled={!isAdmin || savingSection === "organization"} type="submit">
                      {savingSection === "organization" ? "Saving..." : "Save Organisation Details"}
                    </button>
                  </div>
                </form>
              </section>

              <section className="panel stack">
                <div className="panel-heading">
                  <h2>Venue Map</h2>
                  <p className="helper-text">Map preview generated from the saved address.</p>
                </div>
                {mapUrl ? (
                  <iframe
                    className="map-frame"
                    loading="lazy"
                    referrerPolicy="no-referrer-when-downgrade"
                    src={mapUrl}
                    title="Organisation map"
                  />
                ) : (
                  <div className="dashboard-empty">Save an address to show the venue map.</div>
                )}
              </section>

              <section className="panel stack">
                <div className="panel-heading">
                  <h2>Social Profiles</h2>
                  <p className="helper-text">Social profile storage is being prepared; these organisation fields are not editable yet.</p>
                </div>
                <div className="field-grid">
                  <div className="field"><label htmlFor="facebook_profile">Facebook</label><input className="read-only-input" disabled id="facebook_profile" placeholder="Coming soon" value="" /></div>
                  <div className="field"><label htmlFor="instagram_profile">Instagram</label><input className="read-only-input" disabled id="instagram_profile" placeholder="Coming soon" value="" /></div>
                  <div className="field"><label htmlFor="x_profile">X / Twitter</label><input className="read-only-input" disabled id="x_profile" placeholder="Coming soon" value="" /></div>
                  <div className="field"><label htmlFor="youtube_profile">YouTube</label><input className="read-only-input" disabled id="youtube_profile" placeholder="Coming soon" value="" /></div>
                </div>
              </section>
            </section>
          ) : null}

          {activeTab === "users" ? (
            <section className="panel stack">
              <div className="panel-heading settings-section-heading">
                <div>
                  <h2>Organisation Users</h2>
                  <p className="helper-text">Search existing members or add a new user with club access.</p>
                </div>
                <button
                  aria-expanded={addUserOpen}
                  aria-label={addUserOpen ? "Close Add User form" : "Add User"}
                  className="settings-add-button"
                  disabled={!isAdmin}
                  type="button"
                  onClick={() => {
                    setAddUserActivity(Date.now());
                    setAddUserOpen((current) => !current);
                  }}
                >
                  {addUserOpen ? "×" : "+"}
                </button>
              </div>

              {addUserOpen ? <section className="settings-collapsible-card stack compact settings-collapsible-card--open">
                <h3>Add User</h3>
                <form
                  className="stack"
                  onFocus={() => setAddUserActivity(Date.now())}
                  onInput={() => setAddUserActivity(Date.now())}
                  onSubmit={handleUserSubmit}
                >
                <div className="field-grid">
                  <div className="field">
                    <label htmlFor="new_first_name">First Name</label>
                    <input
                      disabled={!isAdmin}
                      id="new_first_name"
                      placeholder="First name"
                      value={userForm.first_name}
                      onChange={(event) => setUserForm((current) => ({ ...current, first_name: event.target.value }))}
                    />
                  </div>
                  <div className="field">
                    <label htmlFor="new_surname">Surname</label>
                    <input
                      disabled={!isAdmin}
                      id="new_surname"
                      placeholder="Surname"
                      value={userForm.surname}
                      onChange={(event) => setUserForm((current) => ({ ...current, surname: event.target.value }))}
                    />
                  </div>
                  <div className="field">
                    <label htmlFor="new_username">Email Address</label>
                    <input
                      disabled={!isAdmin}
                      id="new_username"
                      placeholder="user@club.com"
                      type="email"
                      value={userForm.username}
                      onChange={(event) => setUserForm((current) => ({ ...current, username: event.target.value }))}
                    />
                  </div>
                  <div className="field">
                    <label htmlFor="new_password">Password (new users only)</label>
                    <input
                      disabled={!isAdmin}
                      id="new_password"
                      placeholder="Optional when email already exists"
                      type="password"
                      value={userForm.password}
                      onChange={(event) => setUserForm((current) => ({ ...current, password: event.target.value }))}
                    />
                  </div>
                  <div className="field">
                    <label htmlFor="new_role">Role</label>
                    <select
                      disabled={!isAdmin}
                      id="new_role"
                      value={userForm.role}
                      onChange={(event) => setUserForm((current) => ({ ...current, role: event.target.value }))}
                    >
                      <option value="user">User</option>
                      <option value="admin">Admin</option>
                    </select>
                  </div>
                </div>
                <div className="button-row">
                  <button disabled={!isAdmin || savingSection === "user-create"} type="submit">
                    {savingSection === "user-create" ? "Adding..." : "Add User"}
                  </button>
                </div>
                </form>
              </section> : null}

              <div className="field settings-user-search">
                <label htmlFor="organisation-user-search">Search Users</label>
                <input
                  id="organisation-user-search"
                  placeholder="Search by first name, surname, or email"
                  type="search"
                  value={userSearchQuery}
                  onChange={(event) => setUserSearchQuery(event.target.value)}
                />
              </div>

              <div className="settings-compact-list settings-user-list">
                {sortedFilteredUsers.length ? <div aria-hidden="true" className="settings-user-row settings-list-header">
                  <div className="settings-user-row__identity"><span>First name</span><span>Surname</span><span>Username</span><span>Email</span></div>
                  <span>Role / Status</span>
                </div> : null}
                {sortedFilteredUsers.length === 0 ? (
                  <div className="dashboard-empty">{users.length ? "No users match that search." : "No organisation users found."}</div>
                ) : sortedFilteredUsers.map((user) => (
                  <article className="settings-user-row" key={user.id}>
                    <div className="settings-user-row__identity">
                      <strong>{user.first_name || "—"}</strong>
                      <strong>{user.surname || "—"}</strong>
                      <span>{user.username}</span>
                      <span>{user.email || user.username}</span>
                    </div>
                    <div className="settings-row-actions">
                      <span className="settings-role-badge" title={`Role: ${user.role}`}>{user.role || "user"}</span>
                      <span
                        aria-label={user.status === "pending" ? "Approval pending" : "Approved"}
                        className={`settings-status-icon${user.status === "pending" ? " pending" : ""}`}
                        role="img"
                        title={user.status === "pending" ? "Approval pending" : "Approved"}
                      >
                        {user.status === "pending" ? "!" : "✓"}
                      </span>
                      <button
                        aria-label={`Edit ${formatUserDisplayName(user) || user.username}`}
                        className="settings-edit-button"
                        disabled={!isAdmin}
                        title="Edit user"
                        type="button"
                        onClick={() => navigate(`/settings/users/${user.id}`)}
                      >
                        ✎
                      </button>
                    </div>
                  </article>
                ))}
              </div>
            </section>
          ) : null}

          {activeTab === "courts" ? (
            <section className="panel stack">
              <div className="panel-heading settings-section-heading">
                <div>
                  <h2>Courts</h2>
                </div>
                <button
                  aria-expanded={addCourtOpen}
                  aria-label={addCourtOpen ? "Close Add Court form" : "Add Court"}
                  className="settings-add-button"
                  disabled={!isAdmin}
                  type="button"
                  onClick={() => {
                    setAddCourtActivity(Date.now());
                    setAddCourtOpen((current) => !current);
                  }}
                >
                  {addCourtOpen ? "×" : "+"}
                </button>
              </div>

              {addCourtOpen ? <form
                className="settings-collapsible-card stack"
                onFocus={() => setAddCourtActivity(Date.now())}
                onInput={() => setAddCourtActivity(Date.now())}
                onSubmit={handleCourtCreate}
              >
                <h3>Add Court</h3>
                <div className="field-grid">
                  <div className="field">
                    <label htmlFor="court_sport">Racket Sport</label>
                    <select
                      disabled={!isAdmin}
                      id="court_sport"
                      required
                      value={courtForm.sport}
                      onChange={(event) => setCourtForm((current) => ({ ...current, sport: event.target.value }))}
                    >
                      {courtSportOptions.map((sport) => <option key={sport.value} value={sport.value}>{sport.label}</option>)}
                    </select>
                  </div>
                  <div className="field">
                    <label htmlFor="court_name">Court Name</label>
                    <input
                      disabled={!isAdmin}
                      id="court_name"
                      value={courtForm.court_name}
                      onChange={(event) => setCourtForm((current) => ({ ...current, court_name: event.target.value }))}
                    />
                  </div>
                  <div className="field">
                    <label htmlFor="court_alias">Court Alias</label>
                    <input
                      disabled={!isAdmin}
                      id="court_alias"
                      value={courtForm.court_alias}
                      onChange={(event) => setCourtForm((current) => ({ ...current, court_alias: event.target.value }))}
                    />
                  </div>
                </div>
                <div className="button-row">
                  <button disabled={!isAdmin || savingSection === "court-create"} type="submit">
                    {savingSection === "court-create" ? "Adding..." : "Create Court"}
                  </button>
                </div>
              </form> : null}

              <div className="field settings-court-filter">
                <label htmlFor="court-sport-filter">Filter by Racket Sport</label>
                <select id="court-sport-filter" value={courtSportFilter} onChange={(event) => setCourtSportFilter(event.target.value)}>
                  <option value="">All available sports</option>
                  {courtSportOptions.map((sport) => <option key={sport.value} value={sport.value}>{sport.label}</option>)}
                </select>
              </div>

              <div className="settings-compact-list settings-court-list">
                {filteredCourts.length ? <div aria-hidden="true" className="settings-court-row settings-list-header"><span>Sport</span><span>Name</span><span>Alias</span><span /></div> : null}
                {filteredCourts.length === 0 ? (
                  <div className="dashboard-empty">{courts.length ? "No courts match this sport filter." : "No courts configured yet."}</div>
                ) : filteredCourts.map((court) => (
                  <article className="settings-court-row" key={court.id}>
                    <span className="settings-court-row__sport">{getMatchSportLabel(court.sport)}</span>
                    <strong>{court.court_name || "Unnamed court"}</strong>
                    <span>{court.court_alias || "No alias"}</span>
                    <button
                      aria-expanded={editingCourtId === court.id}
                      aria-label={`Edit ${court.court_name || "court"}`}
                      className="settings-edit-button"
                      disabled={!isAdmin}
                      title="Edit court"
                      type="button"
                      onClick={() => setEditingCourtId((current) => current === court.id ? null : court.id)}
                    >
                      ✎
                    </button>

                    {editingCourtId === court.id ? <div className="settings-court-editor">
                    <div className="field-grid settings-field-grid-tight">
                      <div className="field">
                        <label htmlFor={`court-sport-${court.id}`}>Racket Sport</label>
                        <select
                          disabled={!isAdmin}
                          id={`court-sport-${court.id}`}
                          value={courtDrafts[court.id]?.sport || ""}
                          onChange={(event) => setCourtDrafts((current) => ({
                            ...current,
                            [court.id]: {
                              ...(current[court.id] || {}),
                              sport: event.target.value,
                            },
                          }))}
                        >
                          <option value="">All sports (legacy)</option>
                          {courtSportOptions.map((sport) => <option key={sport.value} value={sport.value}>{sport.label}</option>)}
                        </select>
                      </div>
                      <div className="field">
                        <label htmlFor={`court-name-${court.id}`}>Court Name</label>
                        <input
                          disabled={!isAdmin}
                          id={`court-name-${court.id}`}
                          value={courtDrafts[court.id]?.court_name || ""}
                          onChange={(event) => setCourtDrafts((current) => ({
                            ...current,
                            [court.id]: {
                              ...(current[court.id] || {}),
                              court_name: event.target.value,
                            },
                          }))}
                        />
                      </div>
                      <div className="field">
                        <label htmlFor={`court-alias-${court.id}`}>Court Alias</label>
                        <input
                          disabled={!isAdmin}
                          id={`court-alias-${court.id}`}
                          value={courtDrafts[court.id]?.court_alias || ""}
                          onChange={(event) => setCourtDrafts((current) => ({
                            ...current,
                            [court.id]: {
                              ...(current[court.id] || {}),
                              court_alias: event.target.value,
                            },
                          }))}
                        />
                      </div>
                    </div>
                    <div className="dashboard-item-meta dashboard-item-meta--stacked">
                      <span>Created: {formatDate(court.created_at)}</span>
                      <span>
                        Display code:{" "}
                        {court.display_code ? (
                          <code className="court-display-code">{court.display_code}</code>
                        ) : (
                          "Not generated yet"
                        )}
                      </span>
                      <span>Scoreboard URL: <a href={scoreboardUrl} rel="noreferrer" target="_blank">{scoreboardUrl}</a></span>
                    </div>
                    <div className="button-row">
                      <button
                        disabled={!isAdmin || savingSection === `court-save-${court.id}`}
                        type="button"
                        onClick={() => handleCourtSave(court.id)}
                      >
                        {savingSection === `court-save-${court.id}` ? "Saving..." : "Save Court"}
                      </button>
                      <button
                        className="secondary"
                        disabled={!isAdmin || savingSection === `court-display-code-${court.id}`}
                        type="button"
                        onClick={() => handleCourtDisplayCode(court.id)}
                      >
                        {savingSection === `court-display-code-${court.id}`
                          ? "Updating..."
                          : court.display_code
                            ? "Rotate Display Code"
                            : "Generate Display Code"}
                      </button>
                      <button
                        className="danger"
                        disabled={!isAdmin || savingSection === `court-delete-${court.id}`}
                        type="button"
                        onClick={() => handleCourtDelete(court.id)}
                      >
                        {savingSection === `court-delete-${court.id}` ? "Deleting..." : "Delete Court"}
                      </button>
                    </div>
                    </div> : null}
                  </article>
                ))}
              </div>
            </section>
          ) : null}

          {activeTab === "game-social" ? (
            <section className="panel stack">
              <div className="panel-heading">
                <h2>Game Settings</h2>
                <p className="helper-text">Choose a settings tile to manage current options. More game settings can be added here later.</p>
              </div>
              <div className="settings-tile-grid">
                <button
                  aria-expanded={activeGameSettingsTile === "sports"}
                  className={`settings-option-tile${activeGameSettingsTile === "sports" ? " active" : ""}`}
                  type="button"
                  onClick={() => setActiveGameSettingsTile((current) => current === "sports" ? "" : "sports")}
                >
                  <span className="settings-option-tile__icon" aria-hidden="true">◎</span>
                  <span><strong>Racket Sports</strong><small>Choose sports available for match setup.</small></span>
                  <span aria-hidden="true">›</span>
                </button>
                <button
                  aria-expanded={activeGameSettingsTile === "timers"}
                  className={`settings-option-tile${activeGameSettingsTile === "timers" ? " active" : ""}`}
                  type="button"
                  onClick={() => setActiveGameSettingsTile((current) => current === "timers" ? "" : "timers")}
                >
                  <span className="settings-option-tile__icon" aria-hidden="true">◷</span>
                  <span><strong>Default Timers</strong><small>Preselect warm-ups and timed breaks by sport.</small></span>
                  <span aria-hidden="true">›</span>
                </button>
              </div>

              {activeGameSettingsTile === "sports" ? <section className="settings-tile-detail stack">
                <div className="panel-heading"><h3>Racket Sports</h3><p className="helper-text">Control which racket sports this organisation can see when starting a new match.</p></div>
                <div className="sport-grid">
                  {MATCH_SPORT_OPTIONS.map((sport) => {
                    const enabled = enabledSports.includes(sport.value);
                    return <article className={`sport-option${enabled ? " active" : " disabled"}`} key={sport.value}>
                      <strong>{sport.label}</strong><span>{enabled ? "Enabled" : "Disabled"}</span><p>{sport.note}</p>
                      <button className={enabled ? "secondary" : ""} disabled={!isAdmin || savingSection === "enabled-sports"} type="button" onClick={() => toggleEnabledSport(sport.value)}>{enabled ? "Disable" : "Enable"}</button>
                    </article>;
                  })}
                </div>
                {isAdmin ? <div className="button-row"><button disabled={savingSection === "enabled-sports"} type="button" onClick={handleEnabledSportsSave}>{savingSection === "enabled-sports" ? "Saving..." : "Save Racket Sports"}</button></div> : null}
              </section> : null}

              {activeGameSettingsTile === "timers" ? <section className="settings-tile-detail stack">{renderTimedBreakDefaults()}</section> : null}
            </section>
          ) : null}

          {activeTab === "subscriptions" ? (
            <SubscriptionPreview
              accountEmail={settings?.organization?.org_email || session?.email || session?.username || ""}
              currentPlan={settings?.organization?.plan || "club_essentials"}
            />
          ) : null}
        </>
      )}

      <AppFooter />
    </main>
  );
}
