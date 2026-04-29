import React, { useEffect, useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";

import AppFooter from "../components/AppFooter";
import ClubPageHeader from "../components/ClubPageHeader";
import { COUNTRIES } from "../constants/countries";
import {
  DEFAULT_PLAYER_SHIRT_COLORS,
  PLAYER_SHIRT_COLORS,
} from "../constants/playerShirtColors";
import { useAuth } from "../hooks/useAuth";
import { useMatch } from "../hooks/useMatch";
import { getDashboard, getOrganizationSettings, searchMatchSetupLookup } from "../services/api";

const scoreTypeOptions = [
  { value: 11, label: "PAR-11" },
  { value: 15, label: "PAR-15" },
];
const bestOfOptions = [
  { value: 1, label: "Best of 1" },
  { value: 3, label: "Best of 3" },
  { value: 5, label: "Best of 5" },
];
const handicapBands = ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M"];
const handicapMatrix = {
  A: { A: 0, B: -1, C: -2, D: -3, E: -4, F: -5, G: -6, H: -6, I: -7, J: -8, K: -8, L: -9, M: -10 },
  B: { A: 1, B: 0, C: -1, D: -2, E: -3, F: -4, G: -5, H: -6, I: -6, J: -7, K: -8, L: -8, M: -9 },
  C: { A: 2, B: 1, C: 0, D: -1, E: -2, F: -3, G: -4, H: -5, I: -6, J: -6, K: -7, L: -8, M: -8 },
  D: { A: 3, B: 2, C: 1, D: 0, E: -1, F: -2, G: -3, H: -4, I: -5, J: -6, K: -6, L: -7, M: -8 },
  E: { A: 4, B: 3, C: 2, D: 1, E: 0, F: -1, G: -2, H: -3, I: -4, J: -5, K: -6, L: -6, M: -7 },
  F: { A: 5, B: 4, C: 3, D: 2, E: 1, F: 0, G: -1, H: -2, I: -3, J: -4, K: -5, L: -6, M: -6 },
  G: { A: 6, B: 5, C: 4, D: 3, E: 2, F: 1, G: 0, H: -1, I: -2, J: -3, K: -4, L: -5, M: -6 },
  H: { A: 6, B: 6, C: 5, D: 4, E: 3, F: 2, G: 1, H: 0, I: -1, J: -2, K: -3, L: -4, M: -5 },
  I: { A: 7, B: 6, C: 6, D: 5, E: 4, F: 3, G: 2, H: 1, I: 0, J: -1, K: -2, L: -3, M: -4 },
  J: { A: 8, B: 7, C: 6, D: 6, E: 5, F: 4, G: 3, H: 2, I: 1, J: 0, K: -1, L: -2, M: -3 },
  K: { A: 8, B: 8, C: 7, D: 6, E: 6, F: 5, G: 4, H: 3, I: 2, J: 1, K: 0, L: -1, M: -2 },
  L: { A: 9, B: 8, C: 8, D: 7, E: 6, F: 6, G: 5, H: 4, I: 3, J: 2, K: 1, L: 0, M: -1 },
  M: { A: 10, B: 9, C: 8, D: 8, E: 7, F: 6, G: 6, H: 5, I: 4, J: 3, K: 2, L: 1, M: 0 },
};
const handicapColumns = [...handicapBands];

const initialFormState = {
  tenant_id: "",
  court_id: "",
  court_name: "",
  court_alias: "",
  player1_name: "",
  player1_surname: "",
  player1_country: "",
  player1_handedness: "right",
  player1_shirt_color: DEFAULT_PLAYER_SHIRT_COLORS.player1,
  player2_name: "",
  player2_surname: "",
  player2_country: "",
  player2_handedness: "right",
  player2_shirt_color: DEFAULT_PLAYER_SHIRT_COLORS.player2,
  referee_name: "",
  score_type: 15,
  best_of: 5,
  schedule_match: false,
  handicap_enabled: false,
  player1_band: "",
  player2_band: "",
  player1_offset: 0,
  player2_offset: 0,
};

function inferOrganizationType(session) {
  if (session?.organization_type) {
    return session.organization_type;
  }

  return Number(session?.organization_id) >= 50000 ? "personal" : "club";
}

export default function NewMatch() {
  const { session } = useAuth();
  const [formState, setFormState] = useState(initialFormState);
  const [availableCourts, setAvailableCourts] = useState([]);
  const [activeMatches, setActiveMatches] = useState([]);
  const [courtLoading, setCourtLoading] = useState(true);
  const [courtError, setCourtError] = useState("");
  const [setupNotice, setSetupNotice] = useState("");
  const [showHandicapMatrix, setShowHandicapMatrix] = useState(false);
  const [playerSuggestions, setPlayerSuggestions] = useState([]);
  const [refereeSuggestions, setRefereeSuggestions] = useState([]);
  const [activeLookupField, setActiveLookupField] = useState("");
  const [playerCountryQueries, setPlayerCountryQueries] = useState({
    player1: "",
    player2: "",
  });
  const [activeCountryLookupField, setActiveCountryLookupField] = useState("");
  const [activeCountryOptionIndex, setActiveCountryOptionIndex] = useState(-1);
  const [organizationType, setOrganizationType] = useState(() => inferOrganizationType(session));
  const [organizationPlan, setOrganizationPlan] = useState(
    () => session?.plan || (inferOrganizationType(session) === "personal" ? "personal_free" : "club_essentials"),
  );
  const navigate = useNavigate();
  const { startMatch, loading, error } = useMatch();
  const organizationId = session?.organization_id ? String(session.organization_id) : "";
  const isPersonalAccount = organizationType === "personal";
  const canChooseShirtColors = !isPersonalAccount || organizationPlan === "personal_plus";
  const personalActiveMatch = isPersonalAccount ? activeMatches[0] : null;
  const requiredFieldsComplete =
    organizationId &&
    (isPersonalAccount || (formState.court_id.trim() && formState.court_name.trim())) &&
    formState.player1_name.trim() &&
    formState.player2_name.trim() &&
    (!formState.handicap_enabled || (formState.player1_band && formState.player2_band));
  const handicapSummary =
    formState.player1_band && formState.player2_band
      ? `${formState.player1_band} vs ${formState.player2_band}: Player 1 starts ${formState.player1_offset}, Player 2 starts ${formState.player2_offset}.`
      : "Select both bands to see the starting offset for each player.";
  const headerActions = [
    {
      label: "Back to Dashboard",
      onClick: () => navigate("/dashboard"),
    },
  ];

  if (isPersonalAccount) {
    headerActions.push({
      label: "Settings",
      onClick: () => navigate("/settings"),
    });
  }
  const player1LookupQuery = useMemo(
    () => [formState.player1_name, formState.player1_surname].filter(Boolean).join(" ").trim(),
    [formState.player1_name, formState.player1_surname],
  );
  const player2LookupQuery = useMemo(
    () => [formState.player2_name, formState.player2_surname].filter(Boolean).join(" ").trim(),
    [formState.player2_name, formState.player2_surname],
  );
  const activeCourtMatch = useMemo(
    () => activeMatches.find((match) => String(match.court_id) === formState.court_id),
    [activeMatches, formState.court_id],
  );
  const filteredPlayerCountries = useMemo(() => {
    if (!activeCountryLookupField) {
      return [];
    }

    const query = playerCountryQueries[activeCountryLookupField]?.trim().toLowerCase() || "";
    if (!query) {
      return COUNTRIES.slice(0, 8);
    }

    return COUNTRIES.filter((country) => country.toLowerCase().includes(query)).slice(0, 8);
  }, [activeCountryLookupField, playerCountryQueries]);
  const shouldScheduleMatch = !isPersonalAccount && Boolean(formState.schedule_match || activeCourtMatch);
  const canSubmitMatch = requiredFieldsComplete && !personalActiveMatch;

  function handleChange(name, value) {
    setFormState((current) => ({
      ...current,
      [name]: ["score_type", "best_of"].includes(name) ? Number(value) : value,
    }));
  }

  function handleHandednessChange(name, checked) {
    setFormState((current) => ({
      ...current,
      [name]: checked ? "left" : "right",
    }));
  }

  function handlePlayerCountryInputChange(playerKey, value) {
    setPlayerCountryQueries((current) => ({
      ...current,
      [playerKey]: value,
    }));
    setActiveCountryLookupField(playerKey);
    setActiveCountryOptionIndex(0);
    setFormState((current) => ({
      ...current,
      [`${playerKey}_country`]: "",
    }));
  }

  function handlePlayerCountrySelect(playerKey, country) {
    setPlayerCountryQueries((current) => ({
      ...current,
      [playerKey]: country,
    }));
    setActiveCountryLookupField("");
    setActiveCountryOptionIndex(-1);
    setFormState((current) => ({
      ...current,
      [`${playerKey}_country`]: country,
    }));
  }

  function handlePlayerCountryBlur(playerKey) {
    window.setTimeout(() => {
      setActiveCountryLookupField((current) => (current === playerKey ? "" : current));
      setActiveCountryOptionIndex(-1);
      setPlayerCountryQueries((current) => {
        if (formState[`${playerKey}_country`]) {
          return current;
        }

        return {
          ...current,
          [playerKey]: "",
        };
      });
    }, 120);
  }

  function handlePlayerCountryKeyDown(playerKey, event) {
    if (activeCountryLookupField !== playerKey && ["ArrowDown", "ArrowUp"].includes(event.key)) {
      if (filteredPlayerCountries.length > 0) {
        event.preventDefault();
        setActiveCountryLookupField(playerKey);
        setActiveCountryOptionIndex(0);
      }
      return;
    }

    if (activeCountryLookupField !== playerKey || filteredPlayerCountries.length === 0) {
      if (event.key === "Escape") {
        setActiveCountryLookupField("");
        setActiveCountryOptionIndex(-1);
      }
      return;
    }

    if (event.key === "ArrowDown") {
      event.preventDefault();
      setActiveCountryOptionIndex((current) => (current + 1) % filteredPlayerCountries.length);
      return;
    }

    if (event.key === "ArrowUp") {
      event.preventDefault();
      setActiveCountryOptionIndex((current) => (
        current <= 0 ? filteredPlayerCountries.length - 1 : current - 1
      ));
      return;
    }

    if (event.key === "Enter") {
      if (activeCountryOptionIndex >= 0 && activeCountryOptionIndex < filteredPlayerCountries.length) {
        event.preventDefault();
        handlePlayerCountrySelect(playerKey, filteredPlayerCountries[activeCountryOptionIndex]);
      }
      return;
    }

    if (event.key === "Escape") {
      event.preventDefault();
      setActiveCountryLookupField("");
      setActiveCountryOptionIndex(-1);
    }
  }

  function handleHandicapToggle(checked) {
    if (isPersonalAccount) {
      return;
    }

    setFormState((current) => ({
      ...current,
      handicap_enabled: checked,
      score_type: checked ? 15 : current.score_type,
      player1_band: checked ? current.player1_band : "",
      player2_band: checked ? current.player2_band : "",
      player1_offset: checked ? current.player1_offset : 0,
      player2_offset: checked ? current.player2_offset : 0,
    }));
  }

  useEffect(() => {
    if (!isPersonalAccount) {
      return;
    }

    setFormState((current) => {
      if (!current.schedule_match && !current.handicap_enabled) {
        return current;
      }

      return {
        ...current,
        schedule_match: false,
        handicap_enabled: false,
        player1_band: "",
        player2_band: "",
        player1_offset: 0,
        player2_offset: 0,
      };
    });
  }, [isPersonalAccount]);

  useEffect(() => {
    const nextOrganizationType = inferOrganizationType(session);
    setOrganizationType(nextOrganizationType);
    setOrganizationPlan(session?.plan || (nextOrganizationType === "personal" ? "personal_free" : "club_essentials"));
  }, [session]);

  useEffect(() => {
    async function loadCourts() {
      if (!organizationId) {
        setCourtLoading(false);
        return;
      }

      setCourtLoading(true);
      setCourtError("");
      try {
        const response = await getOrganizationSettings(organizationId);
        const organizationSettings = response?.organizationSettings || {};
        const courts = organizationSettings?.courts || [];
        const nextOrganizationType = organizationSettings?.organization?.org_type || inferOrganizationType(session);
        const nextOrganizationPlan = organizationSettings?.organization?.plan
          || session?.plan
          || (nextOrganizationType === "personal" ? "personal_free" : "club_essentials");
        setAvailableCourts(courts);
        setOrganizationType(nextOrganizationType);
        setOrganizationPlan(nextOrganizationPlan);

        if (nextOrganizationType === "personal") {
          const personalCourt = courts[0];
          if (!personalCourt) {
            setFormState((current) => ({
              ...current,
              court_id: "",
              court_name: "Personal Match",
              court_alias: "Personal Match",
              referee_name: "",
            }));
            return;
          }

          setFormState((current) => ({
            ...current,
            court_id: String(personalCourt.id),
            court_name: personalCourt.court_name || "Personal Match",
            court_alias: personalCourt.court_alias || personalCourt.court_name || "Personal Match",
            referee_name: "",
          }));
        }
      } catch (requestError) {
        setCourtError(requestError.message || "Failed to load organisation courts.");
      } finally {
        setCourtLoading(false);
      }
    }

    loadCourts();
  }, [organizationId, session?.organization_type]);

  useEffect(() => {
    setPlayerCountryQueries({
      player1: formState.player1_country || "",
      player2: formState.player2_country || "",
    });
  }, [formState.player1_country, formState.player2_country]);

  useEffect(() => {
    async function loadActiveMatches() {
      if (!organizationId) {
        return;
      }

      try {
        const response = await getDashboard(organizationId);
        setActiveMatches(response?.dashboard?.active_matches || []);
      } catch {
        setActiveMatches([]);
      }
    }

    loadActiveMatches();
  }, [organizationId]);

  useEffect(() => {
    if (isPersonalAccount) {
      setSetupNotice(
        personalActiveMatch
          ? "You already have an active match running. End it before starting a new personal match."
          : "",
      );
      return;
    }

    if (activeCourtMatch) {
      setSetupNotice(
        `There is an active game currently on ${activeCourtMatch.court_name || formState.court_name}. `
        + "The new match will be set up as a scheduled match ready to start once the active match finishes.",
      );
      return;
    }

    setSetupNotice("");
  }, [activeCourtMatch, formState.court_name, isPersonalAccount, personalActiveMatch]);

  useEffect(() => {
    if (!organizationId || activeLookupField !== "player1" || player1LookupQuery.length < 2) {
      if (activeLookupField === "player1") {
        setPlayerSuggestions([]);
      }
      return undefined;
    }

    const timeoutId = window.setTimeout(async () => {
      try {
        const response = await searchMatchSetupLookup(organizationId, player1LookupQuery);
        setPlayerSuggestions(response?.lookups?.players || []);
      } catch {
        setPlayerSuggestions([]);
      }
    }, 180);

    return () => window.clearTimeout(timeoutId);
  }, [activeLookupField, organizationId, player1LookupQuery]);

  useEffect(() => {
    if (!organizationId || activeLookupField !== "player2" || player2LookupQuery.length < 2) {
      if (activeLookupField === "player2") {
        setPlayerSuggestions([]);
      }
      return undefined;
    }

    const timeoutId = window.setTimeout(async () => {
      try {
        const response = await searchMatchSetupLookup(organizationId, player2LookupQuery);
        setPlayerSuggestions(response?.lookups?.players || []);
      } catch {
        setPlayerSuggestions([]);
      }
    }, 180);

    return () => window.clearTimeout(timeoutId);
  }, [activeLookupField, organizationId, player2LookupQuery]);

  useEffect(() => {
    if (!activeCountryLookupField || filteredPlayerCountries.length === 0) {
      setActiveCountryOptionIndex(-1);
      return;
    }

    setActiveCountryOptionIndex(0);
  }, [activeCountryLookupField, filteredPlayerCountries]);

  useEffect(() => {
    if (
      isPersonalAccount
      || !organizationId
      || activeLookupField !== "referee"
      || formState.referee_name.trim().length < 2
    ) {
      if (activeLookupField === "referee") {
        setRefereeSuggestions([]);
      }
      return undefined;
    }

    const timeoutId = window.setTimeout(async () => {
      try {
        const response = await searchMatchSetupLookup(organizationId, formState.referee_name.trim());
        setRefereeSuggestions(response?.lookups?.referees || []);
      } catch {
        setRefereeSuggestions([]);
      }
    }, 180);

    return () => window.clearTimeout(timeoutId);
  }, [activeLookupField, formState.referee_name, isPersonalAccount, organizationId]);

  function handleCourtChange(value) {
    const selectedCourt = availableCourts.find((court) => String(court.id) === value);
    setFormState((current) => ({
      ...current,
      court_id: value,
      court_name: selectedCourt?.court_name || "",
      court_alias: selectedCourt?.court_alias || selectedCourt?.court_name || "",
    }));
  }

  function applyPlayerSuggestion(playerKey, suggestion) {
    setFormState((current) => ({
      ...current,
      [`${playerKey}_name`]: suggestion.first_name || "",
      [`${playerKey}_surname`]: suggestion.surname || "",
    }));
    setPlayerSuggestions([]);
    setActiveLookupField("");
  }

  function applyRefereeSuggestion(value) {
    setFormState((current) => ({
      ...current,
      referee_name: value,
    }));
    setRefereeSuggestions([]);
    setActiveLookupField("");
  }

  function handleHandicapBandChange(name, value) {
    setFormState((current) => {
      const nextState = {
        ...current,
        [name]: value,
      };

      if (nextState.player1_band && nextState.player2_band) {
        nextState.player1_offset = handicapMatrix[nextState.player1_band][nextState.player2_band];
        nextState.player2_offset = handicapMatrix[nextState.player2_band][nextState.player1_band];
      } else {
        nextState.player1_offset = 0;
        nextState.player2_offset = 0;
      }

      return nextState;
    });
  }

  function renderShirtColorField(playerKey, label) {
    const fieldName = `${playerKey}_shirt_color`;
    return (
      <div className="field shirt-color-field">
        <label>{label}</label>
        <div className="shirt-color-grid" role="radiogroup" aria-label={`${label} shirt color`}>
          {PLAYER_SHIRT_COLORS.map((color) => {
            const selected = formState[fieldName] === color.value;
            return (
              <button
                aria-checked={selected}
                className={`shirt-color-option${selected ? " shirt-color-option--selected" : ""}`}
                key={`${fieldName}-${color.value}`}
                role="radio"
                type="button"
                onClick={() => handleChange(fieldName, color.value)}
              >
                <span
                  aria-hidden="true"
                  className="shirt-color-swatch"
                  style={{
                    background: color.background,
                    borderColor: color.border,
                  }}
                />
                <span>{color.label}</span>
              </button>
            );
          })}
        </div>
      </div>
    );
  }

  async function handleSubmit(event) {
    event.preventDefault();
    if (personalActiveMatch) {
      setSetupNotice("You already have an active match running. End it before starting a new personal match.");
      return;
    }

    if (playerCountryQueries.player1.trim() && !formState.player1_country) {
      setSetupNotice("Choose Player 1's country from the search results.");
      return;
    }

    if (playerCountryQueries.player2.trim() && !formState.player2_country) {
      setSetupNotice("Choose Player 2's country from the search results.");
      return;
    }

    const response = await startMatch({
      ...formState,
      player1_shirt_color: canChooseShirtColors
        ? formState.player1_shirt_color
        : DEFAULT_PLAYER_SHIRT_COLORS.player1,
      player2_shirt_color: canChooseShirtColors
        ? formState.player2_shirt_color
        : DEFAULT_PLAYER_SHIRT_COLORS.player2,
      handicap_enabled: isPersonalAccount ? false : formState.handicap_enabled,
      schedule_match: isPersonalAccount ? false : formState.schedule_match,
      player1_band: isPersonalAccount ? "" : formState.player1_band,
      player2_band: isPersonalAccount ? "" : formState.player2_band,
      player1_offset: isPersonalAccount ? 0 : formState.player1_offset,
      player2_offset: isPersonalAccount ? 0 : formState.player2_offset,
      sport: "squash",
      status: shouldScheduleMatch ? "scheduled" : "active",
      tenant_id: organizationId,
    });
    if (response?.match?.auto_scheduled && response?.match?.auto_schedule_reason) {
      setSetupNotice(response.match.auto_schedule_reason);
    }

    if (response?.match?.id) {
      if (response.match.status === "scheduled" || response.match.auto_scheduled) {
        navigate("/dashboard");
        return;
      }

      navigate(`/match/${response.match.id}`);
    }
  }

  return (
    <main className="page-shell stack">
      <ClubPageHeader
        actions={headerActions}
        subtitle={
          isPersonalAccount
            ? "Create a personal match and open the live scoring screen."
            : "Start the next court session and publish it to the scoring console, spectator display, and device clients from one shared match record."
        }
        title="Create a New Match"
      />

      <form className="panel stack" onSubmit={handleSubmit}>
        <div className="section-heading stack compact">
          <h2>Match Setup</h2>
          <p>
            {isPersonalAccount
              ? "Enter both players and choose the match format before opening the live scoring screen."
              : "Complete the required court and player fields before opening the live scoring screen."}
          </p>
        </div>

        {courtError ? <div className="notice error">{courtError}</div> : null}
        {setupNotice ? <div className="notice">{setupNotice}</div> : null}

        <div className="match-setup-grid">
          <div className="match-setup-row match-setup-row--title">
            <div className="match-setup-section-title">Player 1</div>
          </div>

          <div className="match-setup-row match-setup-row--player">
            <div className="field">
              <label htmlFor="player1_name">First Name<span className="required-mark"> *</span></label>
              <input
                id="player1_name"
                name="player1_name"
                placeholder="Nour"
                required
                value={formState.player1_name}
                onFocus={() => setActiveLookupField("player1")}
                onChange={(event) => handleChange("player1_name", event.target.value)}
              />
            </div>

            <div className="field">
              <label htmlFor="player1_surname">Surname</label>
              <input
                id="player1_surname"
                name="player1_surname"
                placeholder="El Sherbini"
                value={formState.player1_surname}
                onFocus={() => setActiveLookupField("player1")}
                onChange={(event) => handleChange("player1_surname", event.target.value)}
              />
            </div>

            <div className="field checkbox-field match-setup-checkbox-field">
              <label className="checkbox-label" htmlFor="player1_handedness">
                <input
                  checked={formState.player1_handedness === "left"}
                  id="player1_handedness"
                  name="player1_handedness"
                  type="checkbox"
                  onChange={(event) => handleHandednessChange("player1_handedness", event.target.checked)}
                />
                Lefty
              </label>
            </div>
          </div>

          <div className="match-setup-row match-setup-row--country">
            <div className="field">
              <label htmlFor="player1_country">Country</label>
              <input
                aria-activedescendant={
                  activeCountryLookupField === "player1" && activeCountryOptionIndex >= 0
                    ? `player1-country-option-${activeCountryOptionIndex}`
                    : undefined
                }
                aria-autocomplete="list"
                aria-controls="player1-country-suggestions"
                aria-expanded={activeCountryLookupField === "player1" ? "true" : "false"}
                autoComplete="off"
                id="player1_country"
                placeholder="Search country"
                role="combobox"
                value={playerCountryQueries.player1}
                onBlur={() => handlePlayerCountryBlur("player1")}
                onFocus={() => {
                  setActiveCountryLookupField("player1");
                  setActiveCountryOptionIndex(0);
                }}
                onChange={(event) => handlePlayerCountryInputChange("player1", event.target.value)}
                onKeyDown={(event) => handlePlayerCountryKeyDown("player1", event)}
              />
              {activeCountryLookupField === "player1" && filteredPlayerCountries.length ? (
                <div
                  className="lookup-list settings-lookup-list"
                  id="player1-country-suggestions"
                  role="listbox"
                  aria-label="Player 1 country suggestions"
                >
                  {filteredPlayerCountries.map((country, index) => (
                    <button
                      aria-selected={activeCountryOptionIndex === index}
                      className={`lookup-item${activeCountryOptionIndex === index ? " lookup-item--active" : ""}`}
                      id={`player1-country-option-${index}`}
                      key={`player1-country-${country}`}
                      role="option"
                      type="button"
                      onMouseDown={(event) => event.preventDefault()}
                      onMouseEnter={() => setActiveCountryOptionIndex(index)}
                      onClick={() => handlePlayerCountrySelect("player1", country)}
                    >
                      {country}
                    </button>
                  ))}
                </div>
              ) : null}
            </div>
          </div>

          {activeLookupField === "player1" && playerSuggestions.length ? (
            <div className="match-setup-row match-setup-row--lookup">
              <div className="lookup-list" role="listbox" aria-label="Player 1 suggestions">
                {playerSuggestions.map((suggestion) => (
                  <button
                    key={`player1-${suggestion.display_name}`}
                    className="lookup-item"
                    type="button"
                    onMouseDown={(event) => event.preventDefault()}
                    onClick={() => applyPlayerSuggestion("player1", suggestion)}
                  >
                    {suggestion.display_name}
                  </button>
                ))}
              </div>
            </div>
          ) : null}

          <div className="match-setup-row match-setup-row--title">
            <div className="match-setup-section-title">Player 2</div>
          </div>

          <div className="match-setup-row match-setup-row--player">
            <div className="field">
              <label htmlFor="player2_name">First Name<span className="required-mark"> *</span></label>
              <input
                id="player2_name"
                name="player2_name"
                placeholder="Ali"
                required
                value={formState.player2_name}
                onFocus={() => setActiveLookupField("player2")}
                onChange={(event) => handleChange("player2_name", event.target.value)}
              />
            </div>

            <div className="field">
              <label htmlFor="player2_surname">Surname</label>
              <input
                id="player2_surname"
                name="player2_surname"
                placeholder="Farag"
                value={formState.player2_surname}
                onFocus={() => setActiveLookupField("player2")}
                onChange={(event) => handleChange("player2_surname", event.target.value)}
              />
            </div>

            <div className="field checkbox-field match-setup-checkbox-field">
              <label className="checkbox-label" htmlFor="player2_handedness">
                <input
                  checked={formState.player2_handedness === "left"}
                  id="player2_handedness"
                  name="player2_handedness"
                  type="checkbox"
                  onChange={(event) => handleHandednessChange("player2_handedness", event.target.checked)}
                />
                Lefty
              </label>
            </div>
          </div>

          <div className="match-setup-row match-setup-row--country">
            <div className="field">
              <label htmlFor="player2_country">Country</label>
              <input
                aria-activedescendant={
                  activeCountryLookupField === "player2" && activeCountryOptionIndex >= 0
                    ? `player2-country-option-${activeCountryOptionIndex}`
                    : undefined
                }
                aria-autocomplete="list"
                aria-controls="player2-country-suggestions"
                aria-expanded={activeCountryLookupField === "player2" ? "true" : "false"}
                autoComplete="off"
                id="player2_country"
                placeholder="Search country"
                role="combobox"
                value={playerCountryQueries.player2}
                onBlur={() => handlePlayerCountryBlur("player2")}
                onFocus={() => {
                  setActiveCountryLookupField("player2");
                  setActiveCountryOptionIndex(0);
                }}
                onChange={(event) => handlePlayerCountryInputChange("player2", event.target.value)}
                onKeyDown={(event) => handlePlayerCountryKeyDown("player2", event)}
              />
              {activeCountryLookupField === "player2" && filteredPlayerCountries.length ? (
                <div
                  className="lookup-list settings-lookup-list"
                  id="player2-country-suggestions"
                  role="listbox"
                  aria-label="Player 2 country suggestions"
                >
                  {filteredPlayerCountries.map((country, index) => (
                    <button
                      aria-selected={activeCountryOptionIndex === index}
                      className={`lookup-item${activeCountryOptionIndex === index ? " lookup-item--active" : ""}`}
                      id={`player2-country-option-${index}`}
                      key={`player2-country-${country}`}
                      role="option"
                      type="button"
                      onMouseDown={(event) => event.preventDefault()}
                      onMouseEnter={() => setActiveCountryOptionIndex(index)}
                      onClick={() => handlePlayerCountrySelect("player2", country)}
                    >
                      {country}
                    </button>
                  ))}
                </div>
              ) : null}
            </div>
          </div>

          {activeLookupField === "player2" && playerSuggestions.length ? (
            <div className="match-setup-row match-setup-row--lookup">
              <div className="lookup-list" role="listbox" aria-label="Player 2 suggestions">
                {playerSuggestions.map((suggestion) => (
                  <button
                    key={`player2-${suggestion.display_name}`}
                    className="lookup-item"
                    type="button"
                    onMouseDown={(event) => event.preventDefault()}
                    onClick={() => applyPlayerSuggestion("player2", suggestion)}
                  >
                    {suggestion.display_name}
                  </button>
                ))}
              </div>
            </div>
          ) : null}

          {canChooseShirtColors ? (
            <div className="match-setup-row match-setup-row--shirt-colors">
              {renderShirtColorField("player1", "Player 1 Shirt")}
              {renderShirtColorField("player2", "Player 2 Shirt")}
            </div>
          ) : null}

          {!isPersonalAccount ? (
            <div className="match-setup-row match-setup-row--court-controls">
              <div className="field">
                <label htmlFor="court_id">Court ID<span className="required-mark"> *</span></label>
                <select
                  disabled={courtLoading || availableCourts.length === 0}
                  id="court_id"
                  name="court_id"
                  required
                  value={formState.court_id}
                  onChange={(event) => handleCourtChange(event.target.value)}
                >
                  <option value="">
                    {courtLoading ? "Loading courts..." : "Select a court"}
                  </option>
                  {availableCourts.map((court) => (
                    <option key={court.id} value={String(court.id)}>
                      {court.court_name || `Court ${court.id}`}
                    </option>
                  ))}
                </select>
              </div>

              <div className="field">
                <label htmlFor="court_alias">Court Alias<span className="required-mark"> *</span></label>
                <input
                  id="court_alias"
                  name="court_alias"
                  readOnly
                  placeholder="Select a court first"
                  value={formState.court_alias}
                />
              </div>
            </div>
          ) : null}

          <div className="match-setup-row match-setup-row--format">
            <div className="field">
              <label htmlFor="best_of">Match Format</label>
              <select
                id="best_of"
                name="best_of"
                value={formState.best_of}
                onChange={(event) => handleChange("best_of", event.target.value)}
              >
                {bestOfOptions.map((option) => (
                  <option key={option.value} value={option.value}>
                    {option.label}
                  </option>
                ))}
              </select>
            </div>

            <div className="field">
              <label htmlFor="score_type">Game Format</label>
              <select
                disabled={formState.handicap_enabled}
                id="score_type"
                name="score_type"
                value={formState.score_type}
                onChange={(event) => handleChange("score_type", event.target.value)}
              >
                {scoreTypeOptions.map((scoreType) => (
                  <option key={scoreType.value} value={scoreType.value}>
                    {scoreType.label}
                  </option>
                ))}
              </select>
            </div>

            {!isPersonalAccount ? (
              <div className="field checkbox-field match-setup-checkbox-field">
                <label className="checkbox-label" htmlFor="handicap_enabled">
                  <input
                    checked={formState.handicap_enabled}
                    id="handicap_enabled"
                    name="handicap_enabled"
                    type="checkbox"
                    onChange={(event) => handleHandicapToggle(event.target.checked)}
                  />
                  Handicap Match
                </label>
              </div>
            ) : null}
          </div>

          {!isPersonalAccount ? (
            <>
              <div className="match-setup-row match-setup-row--referee">
                <div className="field">
                  <label htmlFor="referee_name">Referee</label>
                  <input
                    id="referee_name"
                    name="referee_name"
                    placeholder="Match official"
                    value={formState.referee_name}
                    onFocus={() => setActiveLookupField("referee")}
                    onChange={(event) => handleChange("referee_name", event.target.value)}
                  />
                </div>
              </div>

              {activeLookupField === "referee" && refereeSuggestions.length ? (
                <div className="match-setup-row match-setup-row--lookup">
                  <div className="lookup-list" role="listbox" aria-label="Referee suggestions">
                    {refereeSuggestions.map((suggestion) => (
                      <button
                        key={`referee-${suggestion}`}
                        className="lookup-item"
                        type="button"
                        onMouseDown={(event) => event.preventDefault()}
                        onClick={() => applyRefereeSuggestion(suggestion)}
                      >
                        {suggestion}
                      </button>
                    ))}
                  </div>
                </div>
              ) : null}
            </>
          ) : null}
        </div>

        {!isPersonalAccount && formState.handicap_enabled ? (
          <div className="panel stack compact">
            <div className="panel-heading">
              <h2>Handicap Setup</h2>
              <p className="helper-text">
                Select each player&apos;s band to calculate the starting offsets from the predefined matrix.
              </p>
            </div>

            <div className="field-grid">
              <div className="field">
                <label htmlFor="player1_band">
                  Player 1 Band
                  <span className="required-mark"> *</span>
                </label>
                <select
                  id="player1_band"
                  name="player1_band"
                  required
                  value={formState.player1_band}
                  onChange={(event) => handleHandicapBandChange("player1_band", event.target.value)}
                >
                  <option value="">Select band</option>
                  {handicapBands.map((band) => (
                    <option key={band} value={band}>
                      {band}
                    </option>
                  ))}
                </select>
              </div>

              <div className="field">
                <label htmlFor="player2_band">
                  Player 2 Band
                  <span className="required-mark"> *</span>
                </label>
                <select
                  id="player2_band"
                  name="player2_band"
                  required
                  value={formState.player2_band}
                  onChange={(event) => handleHandicapBandChange("player2_band", event.target.value)}
                >
                  <option value="">Select band</option>
                  {handicapBands.map((band) => (
                    <option key={band} value={band}>
                      {band}
                    </option>
                  ))}
                </select>
              </div>

              <div className="field">
                <label htmlFor="player1_offset">Player 1 Starting Offset</label>
                <input id="player1_offset" name="player1_offset" readOnly value={formState.player1_offset} />
              </div>

              <div className="field">
                <label htmlFor="player2_offset">Player 2 Starting Offset</label>
                <input id="player2_offset" name="player2_offset" readOnly value={formState.player2_offset} />
              </div>
            </div>
          </div>
        ) : null}

        {error ? <div className="notice error">{error}</div> : null}

        {!isPersonalAccount ? (
          <div className="field checkbox-field">
            <label className="checkbox-label" htmlFor="schedule_match">
              <input
                checked={Boolean(formState.schedule_match)}
                id="schedule_match"
                name="schedule_match"
                type="checkbox"
                onChange={(event) => handleChange("schedule_match", event.target.checked)}
              />
              Schedule Match
            </label>
          </div>
        ) : null}

        <div className="button-row">
          <button disabled={loading || !canSubmitMatch} type="submit">
            {loading ? "Saving..." : "Start Match"}
          </button>
          {personalActiveMatch?.id ? (
            <button
              className="secondary"
              type="button"
              onClick={() => navigate(`/match/${personalActiveMatch.id}`)}
            >
              Resume Active Match
            </button>
          ) : null}
          {!isPersonalAccount ? (
            <button
              className="secondary"
              type="button"
              onClick={() => {
                setShowHandicapMatrix((current) => {
                  const next = !current;
                  if (!current) {
                    window.setTimeout(() => {
                      document.getElementById("handicap-matrix")?.scrollIntoView({
                        behavior: "smooth",
                        block: "start",
                      });
                    }, 0);
                  }
                  return next;
                });
              }}
            >
              {showHandicapMatrix ? "Hide Handicap Matrix" : "View Handicap Matrix"}
            </button>
          ) : null}
        </div>

        {!isPersonalAccount && showHandicapMatrix ? (
          <section className="panel stack compact matrix-panel" id="handicap-matrix">
            <div className="panel-heading">
              <h2>2024 Handicap Matrix</h2>
              <p className="helper-text">
                Pick each player&apos;s band and use the row-to-column intersection as that player&apos;s starting
                score. Example: band C versus band G starts Player 1 on -4 and Player 2 on +4.
              </p>
            </div>

            <div className="matrix-scroll">
              <table className="matrix-table">
                <thead>
                  <tr>
                    <th scope="col">Band</th>
                    {handicapColumns.map((band) => (
                      <th key={band} scope="col">
                        {band}
                      </th>
                    ))}
                  </tr>
                </thead>
                <tbody>
                  {handicapBands.map((rowBand) => (
                    <tr key={rowBand}>
                      <th scope="row">{rowBand}</th>
                      {handicapColumns.map((columnBand) => {
                        const value = handicapMatrix[rowBand][columnBand];
                        const isSelectedPair =
                          formState.player1_band === rowBand && formState.player2_band === columnBand;
                        return (
                          <td className={isSelectedPair ? "selected-cell" : ""} key={`${rowBand}-${columnBand}`}>
                            {value}
                          </td>
                        );
                      })}
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </section>
        ) : null}
      </form>
      <AppFooter />
    </main>
  );
}
