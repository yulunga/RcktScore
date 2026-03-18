import React, { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";

import AppFooter from "../components/AppFooter";
import SessionBar from "../components/SessionBar";
import { useAuth } from "../hooks/useAuth";
import { useMatch } from "../hooks/useMatch";
import { getOrganizationSettings } from "../services/api";

const scoreTypeOptions = [
  { value: 11, label: "PAR-11" },
  { value: 15, label: "PAR-15" },
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
  // player1_country: "",
  player2_name: "",
  player2_surname: "",
  // player2_country: "",
  referee_name: "",
  score_type: 15,
  handicap_enabled: false,
  player1_band: "",
  player2_band: "",
  player1_offset: 0,
  player2_offset: 0,
};

const formFields = [
  {
    name: "tenant_id",
    label: "Tenant ID",
    placeholder: "club-hq",
    required: true,
  },
  {
    name: "player1_name",
    label: "Player 1 First Name",
    placeholder: "Nour",
    required: true,
  },
  {
    name: "player1_surname",
    label: "Player 1 Surname",
    placeholder: "El Sherbini",
  },
  {
    name: "player2_name",
    label: "Player 2 First Name",
    placeholder: "Ali",
    required: true,
  },
  {
    name: "player2_surname",
    label: "Player 2 Surname",
    placeholder: "Farag",
  },
  {
    name: "referee_name",
    label: "Referee",
    placeholder: "Match official",
  },
];

export default function NewMatch() {
  const { session } = useAuth();
  const [formState, setFormState] = useState(initialFormState);
  const [availableCourts, setAvailableCourts] = useState([]);
  const [courtLoading, setCourtLoading] = useState(true);
  const [courtError, setCourtError] = useState("");
  const navigate = useNavigate();
  const { startMatch, loading, error } = useMatch();
  const organizationId = session?.organization_id ? String(session.organization_id) : "";
  const requiredFieldsComplete =
    organizationId &&
    formState.court_id.trim() &&
    formState.court_name.trim() &&
    formState.player1_name.trim() &&
    formState.player2_name.trim() &&
    (!formState.handicap_enabled || (formState.player1_band && formState.player2_band));
  const handicapSummary =
    formState.player1_band && formState.player2_band
      ? `${formState.player1_band} vs ${formState.player2_band}: Player 1 starts ${formState.player1_offset}, Player 2 starts ${formState.player2_offset}.`
      : "Select both bands to see the starting offset for each player.";

  function handleChange(name, value) {
    setFormState((current) => ({
      ...current,
      [name]: name === "score_type" ? Number(value) : value,
    }));
  }

  function handleHandicapToggle(checked) {
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
    async function loadCourts() {
      if (!organizationId) {
        setCourtLoading(false);
        return;
      }

      setCourtLoading(true);
      setCourtError("");
      try {
        const response = await getOrganizationSettings(organizationId);
        setAvailableCourts(response?.courts || []);
      } catch (requestError) {
        setCourtError(requestError.message || "Failed to load organisation courts.");
      } finally {
        setCourtLoading(false);
      }
    }

    loadCourts();
  }, [organizationId]);

  function handleCourtChange(value) {
    const selectedCourt = availableCourts.find((court) => String(court.id) === value);
    setFormState((current) => ({
      ...current,
      court_id: value,
      court_name: selectedCourt?.court_name || "",
      court_alias: selectedCourt?.court_alias || selectedCourt?.court_name || "",
    }));
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

  async function handleSubmit(event) {
    event.preventDefault();
    const createdMatch = await startMatch({
      ...formState,
      sport: "squash",
      tenant_id: organizationId,
    });
    if (createdMatch?.id) {
      navigate(`/match/${createdMatch.id}`);
    }
  }

  return (
    <main className="page-shell">
      <SessionBar />
      <section className="hero-card stack">
        <span className="status-pill">RcktScore v2</span>
        <h1>Create a New Match</h1>
        <p>
          Start the next court session and publish it to the scoring console,
          spectator display, and device clients from one shared match record.
        </p>
      </section>

      <form className="panel stack" onSubmit={handleSubmit}>
        <div className="section-heading stack compact">
          <h2>Match Setup</h2>
          <p>Complete the required court and player fields before opening the live scoring screen.</p>
        </div>

        <div className="notice">
          Organisation: {session?.organization_name || "Unknown"} ({organizationId || "No organisation id"})
        </div>

        {courtError ? <div className="notice error">{courtError}</div> : null}

        <div className="button-row">
          <button className="secondary" type="button" onClick={() => navigate("/dashboard")}>
            Back to Dashboard
          </button>
          <a className="button-link secondary" href="#handicap-matrix">
            View Handicap Matrix
          </a>
        </div>

        <div className="field-grid">
          <div className="field">
            <label htmlFor="court_id">
              Court ID
              <span className="required-mark"> *</span>
            </label>
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
            <label htmlFor="court_alias">
              Court Alias
              <span className="required-mark"> *</span>
            </label>
            <input
              id="court_alias"
              name="court_alias"
              readOnly
              required
              value={formState.court_alias}
            />
          </div>

          {formFields
            .filter(({ name }) => name !== "tenant_id")
            .map(({ name, label, placeholder, required }) => (
              <div className="field" key={name}>
                <label htmlFor={name}>
                  {label}
                  {required ? <span className="required-mark"> *</span> : null}
                </label>
                <input
                  id={name}
                  name={name}
                  placeholder={placeholder}
                  required={required}
                  value={formState[name]}
                  onChange={(event) => handleChange(name, event.target.value)}
                />
              </div>
            ))}

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
        </div>

        <div className="field checkbox-field">
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
          <p className="helper-text">
            Uses the 2024 matrix bands. Handicap matches are locked to PAR-15 scoring.
          </p>
          <p className="helper-text">{handicapSummary}</p>
        </div>

        {formState.handicap_enabled ? (
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

        <div className="button-row">
          <button disabled={loading || !requiredFieldsComplete} type="submit">
            {loading ? "Starting..." : "Start Match"}
          </button>
        </div>

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
      </form>
      <AppFooter />
    </main>
  );
}
