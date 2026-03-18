import React, { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";

import AppFooter from "../components/AppFooter";
import SessionBar from "../components/SessionBar";
import { useAuth } from "../hooks/useAuth";
import { useMatch } from "../hooks/useMatch";
import { getOrganizationSettings } from "../services/api";

const scoreTypeOptions = [11, 15];

const initialFormState = {
  tenant_id: "",
  court_id: "",
  court_name: "",
  player1_name: "",
  player1_surname: "",
  // player1_country: "",
  player2_name: "",
  player2_surname: "",
  // player2_country: "",
  referee_name: "",
  score_type: 15,
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
    formState.player2_name.trim();

  function handleChange(name, value) {
    setFormState((current) => ({
      ...current,
      [name]: name === "score_type" ? Number(value) : value,
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
    }));
  }

  async function handleSubmit(event) {
    event.preventDefault();
    const createdMatch = await startMatch({
      ...formState,
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
                  {court.id}
                  {court.court_alias ? ` • ${court.court_alias}` : ""}
                  {court.court_name ? ` • ${court.court_name}` : ""}
                </option>
              ))}
            </select>
          </div>

          <div className="field">
            <label htmlFor="court_name">
              Court Name
              <span className="required-mark"> *</span>
            </label>
            <input
              id="court_name"
              name="court_name"
              readOnly
              required
              value={formState.court_name}
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
              id="score_type"
              name="score_type"
              value={formState.score_type}
              onChange={(event) => handleChange("score_type", event.target.value)}
            >
              {scoreTypeOptions.map((scoreType) => (
                <option key={scoreType} value={scoreType}>
                  First to {scoreType}
                </option>
              ))}
            </select>
          </div>
        </div>

        {error ? <div className="notice error">{error}</div> : null}

        <div className="button-row">
          <button disabled={loading || !requiredFieldsComplete} type="submit">
            {loading ? "Starting..." : "Start Match"}
          </button>
        </div>
      </form>
      <AppFooter />
    </main>
  );
}
