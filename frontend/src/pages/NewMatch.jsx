import { useState } from "react";
import { useNavigate } from "react-router-dom";

import { useMatch } from "../hooks/useMatch";

const initialFormState = {
  tenant_id: "",
  court_id: "",
  court_name: "",
  player1_name: "",
  player1_surname: "",
  player1_country: "",
  player2_name: "",
  player2_surname: "",
  player2_country: "",
  referee_name: "",
  score_type: 15,
};

export default function NewMatch() {
  const [formState, setFormState] = useState(initialFormState);
  const navigate = useNavigate();
  const { startMatch, loading, error } = useMatch();

  async function handleSubmit(event) {
    event.preventDefault();
    const createdMatch = await startMatch(formState);
    if (createdMatch?.id) {
      navigate(`/match/${createdMatch.id}`);
    }
  }

  return (
    <main className="page-shell">
      <section className="hero-card stack">
        <span className="status-pill">RcktScore v2</span>
        <h1>Create a New Match</h1>
        <p>
          Start a match, open a live scoring session, and make it available to
          mobile clients and ESP32-powered displays through the shared API.
        </p>
      </section>

      <form className="panel stack" onSubmit={handleSubmit}>
        <div className="field-grid">
          {Object.entries(formState).map(([key, value]) => (
            <div className="field" key={key}>
              <label htmlFor={key}>{key.replaceAll("_", " ")}</label>
              <input
                id={key}
                name={key}
                value={value}
                onChange={(event) =>
                  setFormState((current) => ({
                    ...current,
                    [key]: event.target.value,
                  }))
                }
              />
            </div>
          ))}
        </div>

        {error ? <div className="notice error">{error}</div> : null}

        <div className="button-row">
          <button disabled={loading} type="submit">
            {loading ? "Starting..." : "Start Match"}
          </button>
        </div>
      </form>
    </main>
  );
}
