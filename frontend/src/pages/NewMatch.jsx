import React, { useEffect, useMemo, useState } from "react";
import { useNavigate, useSearchParams } from "react-router-dom";

import AppFooter from "../components/AppFooter";
import ClubPageHeader from "../components/ClubPageHeader";
import { COUNTRIES } from "../constants/countries";
import { getMatchSportOption, getPlayableMatchSports, normalizeMatchSport } from "../constants/matchSports";
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
const tennisScoreTypeOptions = [
  { value: 4, label: "First to 4 Games" },
  { value: 6, label: "First to 6 Games" },
];
const bestOfOptions = [
  { value: 1, label: "Best of 1" },
  { value: 3, label: "Best of 3" },
  { value: 5, label: "Best of 5" },
];
const handicapModeOptions = [
  { value: "custom", label: "Custom Scoring" },
  { value: "matrix", label: "Matrix Band" },
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
  player3_name: "",
  player3_surname: "",
  player3_shirt_color: "blue",
  player4_name: "",
  player4_surname: "",
  player4_shirt_color: "red",
  referee_name: "",
  score_type: 15,
  best_of: 5,
  schedule_match: false,
  handicap_enabled: false,
  handicap_mode: "custom",
  player1_band: "",
  player2_band: "",
  player1_offset: 0,
  player2_offset: 0,
  team_format: "singles",
  tennis_no_ad_scoring: false,
  tennis_final_set_match_tiebreak: false,
  tennis_timed_breaks: false,
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
  const [openShirtPicker, setOpenShirtPicker] = useState("");
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
  const [organizationPlan, setOrganizationPlan] = useState(() => String(session?.plan || "").toLowerCase());
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();
  const { startMatch, loading, error } = useMatch();
  const organizationId = session?.organization_id ? String(session.organization_id) : "";
  const selectedSport = normalizeMatchSport(searchParams.get("sport"));
  const selectedSportOption = getMatchSportOption(selectedSport);
  const playableSports = useMemo(() => getPlayableMatchSports(session?.enabled_sports), [session?.enabled_sports]);
  const selectedSportIsAvailable = playableSports.some((sport) => sport.value === selectedSport);
  const isTennisMatch = selectedSport === "tennis";
  const isPadelMatch = selectedSport === "padel";
  const isTennisStyleMatch = isTennisMatch || isPadelMatch;
  const isTennisDoubles = isTennisStyleMatch && (isPadelMatch || formState.team_format === "doubles");
  const visibleScoreTypeOptions = isTennisStyleMatch ? tennisScoreTypeOptions : scoreTypeOptions;
  const isPersonalAccount = organizationType === "personal";
  const isPersonalPlus = isPersonalAccount && organizationPlan === "personal_plus";
  const canScheduleMatch = !isPersonalAccount || isPersonalPlus;
  const requestedScheduledMatch = canScheduleMatch && Boolean(formState.schedule_match);
  const canChooseShirtColors = true;
  const personalActiveMatch = isPersonalAccount && !requestedScheduledMatch ? activeMatches[0] : null;
  const usesMatrixHandicap = formState.handicap_enabled && formState.handicap_mode === "matrix";
  const usesCustomHandicap = formState.handicap_enabled && formState.handicap_mode === "custom";
  const hasValidHandicapSetup = !formState.handicap_enabled
    || (usesMatrixHandicap
      ? Boolean(formState.player1_band && formState.player2_band)
      : formState.player1_offset !== "" && formState.player2_offset !== "");
  const requiredFieldsComplete =
    organizationId &&
    (isPersonalAccount || (formState.court_id.trim() && formState.court_name.trim())) &&
    formState.player1_name.trim() &&
    formState.player2_name.trim() &&
    (!isTennisDoubles || (formState.player3_name.trim() && formState.player4_name.trim())) &&
    hasValidHandicapSetup;
  const handicapSummary =
    usesMatrixHandicap && formState.player1_band && formState.player2_band
      ? `${formState.player1_band} vs ${formState.player2_band}: Player 1 starts ${formState.player1_offset}, Player 2 starts ${formState.player2_offset}.`
      : usesCustomHandicap
        ? `Custom start: Player 1 starts ${formState.player1_offset || 0}, Player 2 starts ${formState.player2_offset || 0}.`
        : "Select both bands to see the starting offset for each player.";
  const playerDisplayName = (playerKey, fallback) => formState[`${playerKey}_name`].trim() || fallback;
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
  const shouldScheduleMatch = requestedScheduledMatch || (!isPersonalAccount && Boolean(activeCourtMatch));
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
    if (isTennisStyleMatch) {
      return;
    }

    setFormState((current) => ({
      ...current,
      handicap_enabled: checked,
      score_type: checked ? 15 : current.score_type,
      handicap_mode: checked ? current.handicap_mode : "custom",
      player1_band: checked ? current.player1_band : "",
      player2_band: checked ? current.player2_band : "",
      player1_offset: checked ? current.player1_offset : 0,
      player2_offset: checked ? current.player2_offset : 0,
    }));

    if (!checked) {
      setShowHandicapMatrix(false);
    }
  }

  useEffect(() => {
    if (!isPersonalAccount && !isTennisStyleMatch) {
      return;
    }

    setFormState((current) => {
      return {
        ...current,
        schedule_match: isPersonalAccount && !isPersonalPlus ? false : current.schedule_match,
        handicap_enabled: isTennisStyleMatch ? false : current.handicap_enabled,
        handicap_mode: isTennisStyleMatch ? "custom" : current.handicap_mode,
        player1_band: isTennisStyleMatch ? "" : current.player1_band,
        player2_band: isTennisStyleMatch ? "" : current.player2_band,
        player1_offset: isTennisStyleMatch ? 0 : current.player1_offset,
        player2_offset: isTennisStyleMatch ? 0 : current.player2_offset,
      };
    });
  }, [isPersonalAccount, isPersonalPlus, isTennisStyleMatch]);

  useEffect(() => {
    setFormState((current) => {
      if (isTennisStyleMatch) {
        return {
          ...current,
          team_format: isPadelMatch ? "doubles" : current.team_format,
          score_type: tennisScoreTypeOptions.some((option) => option.value === current.score_type) ? current.score_type : 6,
          best_of: [1, 3, 5].includes(current.best_of) ? current.best_of : 3,
          handicap_enabled: false,
          handicap_mode: "custom",
          player1_band: "",
          player2_band: "",
          player1_offset: 0,
          player2_offset: 0,
        };
      }

      return {
        ...current,
        score_type: scoreTypeOptions.some((option) => option.value === current.score_type) ? current.score_type : 15,
      };
    });
  }, [isPadelMatch, isTennisStyleMatch]);

  useEffect(() => {
    const nextOrganizationType = inferOrganizationType(session);
    setOrganizationType(nextOrganizationType);
    setOrganizationPlan(String(session?.plan || "").toLowerCase());
  }, [session]);

  useEffect(() => {
    if (!selectedSport) {
      navigate("/match/new", { replace: true });
      return;
    }

    if (!selectedSportIsAvailable) {
      navigate("/match/new", { replace: true });
    }
  }, [navigate, selectedSport, selectedSportIsAvailable]);

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
        const timedBreakDefaults = organizationSettings?.organization?.timed_break_defaults || {};
        const nextOrganizationType = organizationSettings?.organization?.org_type || inferOrganizationType(session);
        const nextOrganizationPlan = organizationSettings?.organization?.plan || session?.plan || "";
        setAvailableCourts(courts);
        setOrganizationType(nextOrganizationType);
        setOrganizationPlan(String(nextOrganizationPlan).toLowerCase());
        setFormState((current) => ({
          ...current,
          tennis_timed_breaks: Boolean(timedBreakDefaults[selectedSport]),
        }));

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
  }, [organizationId, selectedSport, session?.organization_type]);

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

  function handleHandicapModeChange(value) {
    setFormState((current) => {
      if (value === "custom") {
        return {
          ...current,
          handicap_mode: value,
          player1_band: "",
          player2_band: "",
        };
      }

      const nextState = {
        ...current,
        handicap_mode: value,
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

    if (value !== "matrix") {
      setShowHandicapMatrix(false);
    }
  }

  function handleHandicapOffsetChange(name, value) {
    setFormState((current) => ({
      ...current,
      [name]: value === "" ? "" : Number(value),
    }));
  }

  function renderShirtColorField(playerKey, label) {
    const fieldName = `${playerKey}_shirt_color`;
    const selectedColor = PLAYER_SHIRT_COLORS.find((color) => color.value === formState[fieldName]) || PLAYER_SHIRT_COLORS[0];
    const isOpen = openShirtPicker === fieldName;
    return (
      <div className="field shirt-color-field">
        <label>{label}</label>
        <button
          aria-expanded={isOpen}
          aria-label={`Change ${label}, currently ${selectedColor.label}`}
          className="shirt-color-trigger"
          type="button"
          onClick={() => setOpenShirtPicker((current) => current === fieldName ? "" : fieldName)}
        >
          <span
            aria-hidden="true"
            className="shirt-color-swatch"
            style={{ background: selectedColor.background, borderColor: selectedColor.border }}
          />
          <span>{selectedColor.label}</span>
          <span className="shirt-color-trigger__chevron" aria-hidden="true">⌄</span>
        </button>
        {isOpen ? <div className="shirt-color-grid" role="radiogroup" aria-label={`${label} shirt color`}>
          {PLAYER_SHIRT_COLORS.map((color) => {
            const selected = formState[fieldName] === color.value;
            return (
              <button
                aria-checked={selected}
                className={`shirt-color-option${selected ? " shirt-color-option--selected" : ""}`}
                key={`${fieldName}-${color.value}`}
                role="radio"
                type="button"
                onClick={() => {
                  handleChange(fieldName, color.value);
                  setOpenShirtPicker("");
                }}
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
        </div> : null}
      </div>
    );
  }

  function renderOptionSwitch({ id, label, description, checked, disabled = false, onChange }) {
    return (
      <label className={`match-option-switch${disabled ? " match-option-switch--disabled" : ""}`} htmlFor={id}>
        <span className="match-option-switch__copy">
          <strong>{label}</strong>
          {description ? <small>{description}</small> : null}
        </span>
        <span className="match-option-switch__control">
          <input
            checked={checked}
            disabled={disabled}
            id={id}
            type="checkbox"
            onChange={(event) => onChange(event.target.checked)}
          />
          <span className="match-option-switch__track" aria-hidden="true"><span /></span>
        </span>
      </label>
    );
  }

  function renderAdditionalTennisPlayer(playerKey, label) {
    const [teamLabel, fallbackPlayerLabel] = label.split("·").map((value) => value.trim());
    const playerName = playerDisplayName(playerKey, fallbackPlayerLabel || label);
    const displayName = fallbackPlayerLabel ? `${teamLabel} · ${playerName}` : playerName;
    return (
      <section className="panel stack compact tennis-participant-card" data-testid={`${playerKey}-card`}>
        <div className="panel-heading"><h3>{displayName}</h3></div>
        <div className="field-grid">
          <div className="field">
            <label htmlFor={`${playerKey}_name`}>First Name<span className="required-mark"> *</span></label>
            <input
              id={`${playerKey}_name`}
              name={`${playerKey}_name`}
              required={isTennisDoubles}
              value={formState[`${playerKey}_name`]}
              onChange={(event) => handleChange(`${playerKey}_name`, event.target.value)}
            />
          </div>
          <div className="field">
            <label htmlFor={`${playerKey}_surname`}>Surname</label>
            <input
              id={`${playerKey}_surname`}
              name={`${playerKey}_surname`}
              value={formState[`${playerKey}_surname`]}
              onChange={(event) => handleChange(`${playerKey}_surname`, event.target.value)}
            />
          </div>
        </div>
        {renderShirtColorField(playerKey, `${playerName} Shirt`)}
      </section>
    );
  }

  async function handleSubmit(event) {
    event.preventDefault();
    if (!selectedSport) {
      navigate("/match/new", { replace: true });
      return;
    }

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

    const tennisTeamOneName = isTennisDoubles
      ? [formState.player1_name, formState.player2_name].filter(Boolean).join(" / ")
      : formState.player1_name;
    const tennisTeamTwoName = isTennisDoubles
      ? [formState.player3_name, formState.player4_name].filter(Boolean).join(" / ")
      : formState.player2_name;
    const response = await startMatch({
      ...formState,
      player1_name: isTennisStyleMatch ? tennisTeamOneName : formState.player1_name,
      player1_surname: isTennisDoubles ? "" : formState.player1_surname,
      player2_name: isTennisStyleMatch ? tennisTeamTwoName : formState.player2_name,
      player2_surname: isTennisDoubles ? "" : formState.player2_surname,
      player1_shirt_color: canChooseShirtColors
        ? formState.player1_shirt_color
        : DEFAULT_PLAYER_SHIRT_COLORS.player1,
      player2_shirt_color: canChooseShirtColors
        ? formState.player2_shirt_color
        : DEFAULT_PLAYER_SHIRT_COLORS.player2,
      handicap_enabled: formState.handicap_enabled,
      schedule_match: canScheduleMatch ? formState.schedule_match : false,
      player1_band: formState.player1_band,
      player2_band: formState.player2_band,
      player1_offset: formState.player1_offset,
      player2_offset: formState.player2_offset,
      sport: selectedSport,
      status: shouldScheduleMatch ? "scheduled" : "active",
      tenant_id: organizationId,
      team_format: isTennisStyleMatch ? (isPadelMatch ? "doubles" : formState.team_format) : undefined,
      team1_player1_name: isTennisStyleMatch ? formState.player1_name.trim() : undefined,
      team1_player1_surname: isTennisStyleMatch ? formState.player1_surname.trim() : undefined,
      team1_player2_name: isTennisDoubles ? formState.player2_name.trim() : undefined,
      team1_player2_surname: isTennisDoubles ? formState.player2_surname.trim() : undefined,
      team2_player1_name: isTennisStyleMatch
        ? (isTennisDoubles ? formState.player3_name.trim() : formState.player2_name.trim())
        : undefined,
      team2_player1_surname: isTennisStyleMatch
        ? (isTennisDoubles ? formState.player3_surname.trim() : formState.player2_surname.trim())
        : undefined,
      team2_player2_name: isTennisDoubles ? formState.player4_name.trim() : undefined,
      team2_player2_surname: isTennisDoubles ? formState.player4_surname.trim() : undefined,
      team1_player1_shirt_color: isTennisStyleMatch ? formState.player1_shirt_color : undefined,
      team1_player2_shirt_color: isTennisDoubles ? formState.player2_shirt_color : undefined,
      team2_player1_shirt_color: isTennisStyleMatch
        ? (isTennisDoubles ? formState.player3_shirt_color : formState.player2_shirt_color)
        : undefined,
      team2_player2_shirt_color: isTennisDoubles ? formState.player4_shirt_color : undefined,
      tennis_no_ad_scoring: formState.tennis_no_ad_scoring,
      tennis_final_set_match_tiebreak: isTennisMatch
        && formState.best_of > 1
        && formState.tennis_final_set_match_tiebreak,
      tennis_timed_breaks: formState.tennis_timed_breaks,
    });
    if (response?.match?.auto_scheduled && response?.match?.auto_schedule_reason) {
      setSetupNotice(response.match.auto_schedule_reason);
    }

    if (response?.match?.id) {
      if (response.match.status === "scheduled" || response.match.auto_scheduled) {
        navigate("/matches#scheduled-matches-section");
        return;
      }

      navigate(`/match/${response.match.id}`);
    }
  }

  return (
    <main className="page-shell stack">
      <ClubPageHeader />

      <form className="panel stack" onSubmit={handleSubmit}>
        <div className="section-heading stack compact">
          <h2>{selectedSportOption?.label || "Racket Sport"} Match Setup</h2>
        </div>

        {courtError ? <div className="notice error">{courtError}</div> : null}
        {setupNotice ? <div className="notice">{setupNotice}</div> : null}

        {isTennisMatch ? (
          <section className="panel stack compact tennis-format-card">
            <div className="panel-heading">
              <h2>Players</h2>
              <p className="helper-text">Choose singles or doubles before entering the line-up.</p>
            </div>
            <div className="tennis-format-options" role="radiogroup" aria-label="Tennis match type">
              <button
                aria-checked={formState.team_format === "singles"}
                className={formState.team_format === "singles" ? "secondary active" : "secondary"}
                role="radio"
                type="button"
                onClick={() => handleChange("team_format", "singles")}
              >Singles</button>
              <button
                aria-checked={formState.team_format === "doubles"}
                className={formState.team_format === "doubles" ? "secondary active" : "secondary"}
                role="radio"
                type="button"
                onClick={() => handleChange("team_format", "doubles")}
              >Doubles</button>
            </div>
          </section>
        ) : null}

        {isPadelMatch ? (
          <div className="notice">Padel is doubles-only. Enter two players for each team.</div>
        ) : null}

        <div className="match-setup-grid">
          <div className="match-setup-row match-setup-row--title">
            <div className="match-setup-section-title">{isTennisDoubles ? `Team 1 · ${playerDisplayName("player1", "Player 1")}` : playerDisplayName("player1", "Player 1")}</div>
          </div>

          <div className="match-setup-row match-setup-row--player">
            <div className="field">
              <label htmlFor="player1_name">First Name<span className="required-mark"> *</span></label>
              <input
                id="player1_name"
                name="player1_name"
                placeholder="P1_Name"
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
                placeholder="P1_Surname"
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

          {canChooseShirtColors ? (
            <div className="match-setup-row match-setup-row--player-accessory">
              {renderShirtColorField("player1", `${playerDisplayName("player1", "Player 1")} Shirt`)}
            </div>
          ) : null}

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
            <div className="match-setup-section-title">{isTennisDoubles ? `Team 1 · ${playerDisplayName("player2", "Player 2")}` : playerDisplayName("player2", "Player 2")}</div>
          </div>

          <div className="match-setup-row match-setup-row--player">
            <div className="field">
              <label htmlFor="player2_name">First Name<span className="required-mark"> *</span></label>
              <input
                id="player2_name"
                name="player2_name"
                placeholder="P2_Name"
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
                placeholder="P2_Surname"
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

          {canChooseShirtColors ? (
            <div className="match-setup-row match-setup-row--player-accessory">
              {renderShirtColorField("player2", `${playerDisplayName("player2", "Player 2")} Shirt`)}
            </div>
          ) : null}

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

          {isTennisDoubles ? (
            <div className="match-setup-row tennis-doubles-lineup">
              {renderAdditionalTennisPlayer("player3", "Team 2 · Player 1")}
              {renderAdditionalTennisPlayer("player4", "Team 2 · Player 2")}
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
                disabled={!isTennisStyleMatch && formState.handicap_enabled}
                id="score_type"
                name="score_type"
                value={formState.score_type}
                onChange={(event) => handleChange("score_type", event.target.value)}
              >
                {visibleScoreTypeOptions.map((scoreType) => (
                  <option key={scoreType.value} value={scoreType.value}>
                    {scoreType.label}
                  </option>
                ))}
              </select>
            </div>

            {!isTennisStyleMatch ? (
              renderOptionSwitch({
                id: "handicap_enabled",
                label: "Handicap Match",
                description: "Give players different starting scores to create a balanced match.",
                checked: formState.handicap_enabled,
                onChange: handleHandicapToggle,
              })
            ) : null}
          </div>

          {isTennisStyleMatch ? (
            <section className="panel stack compact tennis-rules-card">
              <div className="panel-heading">
                <h2>{isPadelMatch ? "Padel Rules" : "Tennis Rules"}</h2>
                <p className="helper-text">These choices are stored with the match and apply on every client.</p>
              </div>
              {renderOptionSwitch({
                id: "tennis_no_ad_scoring",
                label: "Golden Point at 40-40",
                description: isPadelMatch
                  ? "At 40-40, one deciding point is played after the receiving team chooses its receiver."
                  : "At 40-40, the next point decides the game instead of playing advantage.",
                checked: formState.tennis_no_ad_scoring,
                onChange: (checked) => handleChange("tennis_no_ad_scoring", checked),
              })}
              {!isPadelMatch ? renderOptionSwitch({
                id: "tennis_final_set_match_tiebreak",
                label: "Final-set 10-point match tiebreak",
                description: "Replace the deciding set with a first-to-10 tiebreak, winning by two points.",
                checked: formState.tennis_final_set_match_tiebreak,
                disabled: formState.best_of === 1,
                onChange: (checked) => handleChange("tennis_final_set_match_tiebreak", checked),
              }) : null}
              {renderOptionSwitch({
                id: "tennis_timed_breaks",
                label: "Timed breaks: 90-second odd-game changeovers and 120-second set breaks",
                description: "Runs 90-second odd-game changeovers and 120-second set breaks.",
                checked: formState.tennis_timed_breaks,
                onChange: (checked) => handleChange("tennis_timed_breaks", checked),
              })}
            </section>
          ) : null}

          {!isTennisStyleMatch ? (
            <section className="panel stack compact tennis-rules-card">
              <div className="panel-heading">
                <h2>{selectedSportOption?.label || "Racket Sport"} Rules</h2>
                <p className="helper-text">These choices are stored with this match and apply on web and iOS.</p>
              </div>
              {renderOptionSwitch({
                id: "racket_golden_point",
                label: `Golden Point at ${formState.score_type - 1}-all`,
                description: `At ${formState.score_type - 1}-all, the next point decides the game.`,
                checked: formState.tennis_no_ad_scoring,
                onChange: (checked) => handleChange("tennis_no_ad_scoring", checked),
              })}
              {renderOptionSwitch({
                id: "racket_timed_breaks",
                label: "Timed warm-up and 90-second game breaks",
                description: "Runs the sport warm-up timer and a 90-second break after each game.",
                checked: formState.tennis_timed_breaks,
                onChange: (checked) => handleChange("tennis_timed_breaks", checked),
              })}
            </section>
          ) : null}

        </div>

        {!isTennisStyleMatch && formState.handicap_enabled ? (
          <div className="panel stack compact">
            <div className="panel-heading">
              <h2>Handicap Setup</h2>
              <p className="helper-text">
                Choose whether to use the standard matrix bands or set custom starting scores manually.
              </p>
            </div>

            <div className="field-grid">
              <div className="field">
                <label htmlFor="handicap_mode">
                  Handicap Option
                  <span className="required-mark"> *</span>
                </label>
                <select
                  id="handicap_mode"
                  name="handicap_mode"
                  value={formState.handicap_mode}
                  onChange={(event) => handleHandicapModeChange(event.target.value)}
                >
                  {handicapModeOptions.map((option) => (
                    <option key={option.value} value={option.value}>
                      {option.label}
                    </option>
                  ))}
                </select>
              </div>

              {usesMatrixHandicap ? (
                <>
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
                </>
              ) : null}

              {usesCustomHandicap ? (
                <>
                  <div className="field">
                    <label htmlFor="player1_offset">
                      Player 1 Starting Score
                      <span className="required-mark"> *</span>
                    </label>
                    <input
                      id="player1_offset"
                      inputMode="numeric"
                      name="player1_offset"
                      required
                      step="1"
                      type="number"
                      value={formState.player1_offset}
                      onChange={(event) => handleHandicapOffsetChange("player1_offset", event.target.value)}
                    />
                  </div>

                  <div className="field">
                    <label htmlFor="player2_offset">
                      Player 2 Starting Score
                      <span className="required-mark"> *</span>
                    </label>
                    <input
                      id="player2_offset"
                      inputMode="numeric"
                      name="player2_offset"
                      required
                      step="1"
                      type="number"
                      value={formState.player2_offset}
                      onChange={(event) => handleHandicapOffsetChange("player2_offset", event.target.value)}
                    />
                  </div>
                </>
              ) : null}
            </div>

            {formState.handicap_enabled ? (
              <p className="helper-text">{handicapSummary}</p>
            ) : null}
          </div>
        ) : null}

        {error ? <div className="notice error">{error}</div> : null}

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

        {canScheduleMatch ? (
          renderOptionSwitch({
            id: "schedule_match",
            label: isPersonalPlus ? "Schedule for Later" : "Schedule Match",
            description: "Save this match without starting the scoring clock, then start it later from Matches.",
            checked: Boolean(formState.schedule_match),
            onChange: (checked) => handleChange("schedule_match", checked),
          })
        ) : null}

        <div className="button-row">
          <button disabled={loading || !canSubmitMatch} type="submit">
            {loading ? "Saving..." : shouldScheduleMatch ? "Schedule Match" : "Start Match"}
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
          {!isPersonalAccount && usesMatrixHandicap ? (
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

        {!isPersonalAccount && usesMatrixHandicap && showHandicapMatrix ? (
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
