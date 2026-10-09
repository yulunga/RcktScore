import React, { useCallback, useEffect, useRef, useState } from "react";
import { useParams } from "react-router-dom";

import AppFooter from "../../../components/AppFooter";
import ClubPageHeader from "../../../components/ClubPageHeader";
import { useAuth } from "../../../hooks/useAuth";
import {
  createTournamentEntry,
  generateTournamentDraw,
  getTournament,
  publishTournamentDraw,
  returnTournamentDrawToDraft,
  searchTournamentPlayers,
  updateTournamentDrawSlot,
  updateTournamentEntry,
} from "../../../services/api";
import TournamentBracket from "../components/TournamentBracket";
import { optionLabel, TOURNAMENT_FORMATS, TOURNAMENT_SPORTS } from "../tournamentOptions";

const EMPTY_ENTRY = {
  first_name: "",
  surname: "",
  email: "",
  home_club_name: "",
  ability_level: "",
};

const ABILITY_OPTIONS = [
  { value: "1", grade: "A", label: "Advanced player", detail: "Experienced league or tournament competitor." },
  { value: "2", grade: "B", label: "Club player", detail: "Consistent rallies with sound movement and match awareness." },
  { value: "3", grade: "C", label: "Developing player", detail: "Can serve, return and sustain a short rally." },
  { value: "4", grade: "D", label: "Racket up is this way", detail: "New player learning grip, contact and basic movement." },
];

function normalizePlayerKey(player) {
  const email = (player.email || "").trim().toLowerCase();
  if (email) return `email:${email}`;
  return `name:${`${player.first_name || ""} ${player.surname || ""}`.trim().toLowerCase().replace(/\s+/g, " ")}`;
}

function parseCsv(text) {
  const rows = [];
  let row = [];
  let value = "";
  let quoted = false;
  for (let index = 0; index < text.length; index += 1) {
    const character = text[index];
    if (character === '"' && quoted && text[index + 1] === '"') {
      value += '"';
      index += 1;
    } else if (character === '"') {
      quoted = !quoted;
    } else if (character === "," && !quoted) {
      row.push(value.trim());
      value = "";
    } else if ((character === "\n" || character === "\r") && !quoted) {
      if (character === "\r" && text[index + 1] === "\n") index += 1;
      row.push(value.trim());
      if (row.some(Boolean)) rows.push(row);
      row = [];
      value = "";
    } else {
      value += character;
    }
  }
  row.push(value.trim());
  if (row.some(Boolean)) rows.push(row);
  return rows;
}

function abilityLabel(level) {
  const option = ABILITY_OPTIONS.find((item) => item.value === String(level));
  return option ? `Grade ${option.grade}` : "Grade A";
}

function describeAddedPlayer(entry) {
  if (!entry) {
    return "Player added to the tournament. Tournament entry does not grant app or club access.";
  }
  if (entry.claim_status === "linked" && entry.relationship === "member") {
    return "Player added as a linked HitNScore club member. Their existing app role, plan and access are unchanged.";
  }
  if (entry.claim_status === "linked") {
    return "Player added as a guest linked to an existing HitNScore account. This does not grant membership, a role or access to this club.";
  }
  if (entry.claim_status === "claimable") {
    return "Player added as a claimable guest. They have no login, role, plan or club access from this tournament entry.";
  }
  return "Player added as an unclaimed named guest. They have no login, role, plan or club access.";
}

function findAddedEntry(nextTournament, player) {
  const entries = nextTournament?.entries || [];
  if (player.player_id) {
    return entries.find((entry) => entry.player_id === player.player_id);
  }
  const email = (player.email || "").trim().toLowerCase();
  if (email) {
    return entries.find((entry) => (entry.email || "").trim().toLowerCase() === email);
  }
  return entries.find((entry) => (
    entry.first_name === player.first_name && entry.surname === player.surname
  ));
}

function AbilitySelector({ value, onChange, idPrefix }) {
  return (
    <fieldset className="tournament-ability-fieldset">
      <legend>Player Ability</legend>
      <div className="tournament-ability-options">
        {ABILITY_OPTIONS.map((option) => (
          <label
            className={`tournament-ability-option${value === option.value ? " tournament-ability-option--selected" : ""}`}
            htmlFor={`${idPrefix}-${option.value}`}
            key={option.value}
          >
            <input
              checked={value === option.value}
              id={`${idPrefix}-${option.value}`}
              name={`${idPrefix}-ability`}
              required
              type="radio"
              value={option.value}
              onChange={(event) => onChange(event.target.value)}
            />
            <span>
              <strong>{`Grade ${option.grade}`}</strong>
              <small>{option.detail}</small>
            </span>
          </label>
        ))}
      </div>
    </fieldset>
  );
}

function LinkIcon() {
  return (
    <svg aria-hidden="true" viewBox="0 0 24 24">
      <path d="M10.4 13.6a4.5 4.5 0 0 0 6.4 0l2.1-2.1a4.5 4.5 0 0 0-6.4-6.4l-1.2 1.2" />
      <path d="M13.6 10.4a4.5 4.5 0 0 0-6.4 0l-2.1 2.1a4.5 4.5 0 0 0 6.4 6.4l1.2-1.2" />
    </svg>
  );
}

function MemberIcon() {
  return (
    <svg aria-hidden="true" viewBox="0 0 24 24">
      <circle cx="12" cy="8" r="3.25" />
      <path d="M5.5 19c.5-3.4 2.7-5.2 6.5-5.2s6 1.8 6.5 5.2" />
    </svg>
  );
}

function EntryIndicator({ className = "", description, label, children }) {
  return (
    <span
      aria-label={`${label}. ${description}`}
      className={`tournament-entry-indicator ${className}`.trim()}
      data-tooltip={description}
      role="img"
      tabIndex="0"
    >
      {children}
    </span>
  );
}

function buildPlateDraw(draw) {
  const mainMatches = (draw.matches || []).filter((match) => (
    Number(match.round_number) === 1 && match.player1_entry_id && match.player2_entry_id
  ));
  const loserSlots = mainMatches.map((match, index) => ({ name: `Loser Championship Match ${index + 1}` }));
  const matches = [];
  for (let index = 0; index < loserSlots.length; index += 2) {
    matches.push({
      id: `${draw.id}-plate-${index / 2 + 1}`,
      round_number: 1,
      player1_name: loserSlots[index]?.name || "TBD",
      player2_name: loserSlots[index + 1]?.name || "Bye",
    });
  }
  return { id: `${draw.id}-plate`, name: `${draw.name} Plate`, matches };
}

export default function TournamentDetailPage() {
  const { tournamentId } = useParams();
  const { session } = useAuth();
  const organizationId = session?.organization_id;
  const isAdmin = session?.role === "admin";
  const [tournament, setTournament] = useState(null);
  const [entryForm, setEntryForm] = useState(EMPTY_ENTRY);
  const [searchQuery, setSearchQuery] = useState("");
  const [searchResults, setSearchResults] = useState([]);
  const [selectedPlayer, setSelectedPlayer] = useState(null);
  const [selectedAbility, setSelectedAbility] = useState("");
  const [manualEntryOpen, setManualEntryOpen] = useState(false);
  const [importOpen, setImportOpen] = useState(false);
  const [importRows, setImportRows] = useState([]);
  const [importing, setImporting] = useState(false);
  const [editingEntryId, setEditingEntryId] = useState(null);
  const [editForm, setEditForm] = useState(null);
  const [searching, setSearching] = useState(false);
  const [searchPerformed, setSearchPerformed] = useState(false);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [drawing, setDrawing] = useState(false);
  const [message, setMessage] = useState("");
  const [error, setError] = useState("");
  const searchRequestRef = useRef(0);

  const load = useCallback(async () => {
    if (!tournamentId || !organizationId) return;
    setLoading(true);
    setError("");
    try {
      const response = await getTournament(tournamentId, organizationId);
      setTournament(response?.tournament || null);
    } catch (requestError) {
      setError(requestError.message || "Unable to load the tournament.");
    } finally {
      setLoading(false);
    }
  }, [organizationId, tournamentId]);

  useEffect(() => {
    load();
  }, [load]);

  useEffect(() => {
    const query = searchQuery.trim();
    const requestId = searchRequestRef.current + 1;
    searchRequestRef.current = requestId;
    setSelectedPlayer(null);

    if (query.length < 2 || !organizationId) {
      setSearchResults([]);
      setSearchPerformed(false);
      setSearching(false);
      return undefined;
    }

    setSearching(true);
    setSearchPerformed(false);
    const timeoutId = window.setTimeout(async () => {
      try {
        const response = await searchTournamentPlayers(organizationId, query);
        if (searchRequestRef.current !== requestId) return;
        setSearchResults(response?.players || []);
        setSearchPerformed(true);
        setError("");
      } catch (requestError) {
        if (searchRequestRef.current !== requestId) return;
        setSearchResults([]);
        setSearchPerformed(true);
        setError(requestError.message || "Unable to search for players.");
      } finally {
        if (searchRequestRef.current === requestId) setSearching(false);
      }
    }, 300);

    return () => window.clearTimeout(timeoutId);
  }, [organizationId, searchQuery]);

  async function handleAddEntry(event) {
    event.preventDefault();
    setSaving(true);
    setMessage("");
    setError("");
    try {
      const response = await createTournamentEntry(tournamentId, {
        ...entryForm,
        organization_id: organizationId,
      });
      const nextTournament = response?.tournament || null;
      setTournament(nextTournament);
      setEntryForm(EMPTY_ENTRY);
      setManualEntryOpen(false);
      setMessage(describeAddedPlayer(findAddedEntry(nextTournament, entryForm)));
    } catch (requestError) {
      setError(requestError.message || "Unable to add the player.");
    } finally {
      setSaving(false);
    }
  }

  async function handleAddSelected(event) {
    event.preventDefault();
    if (!selectedPlayer || !selectedAbility) return;
    setSaving(true);
    setMessage("");
    setError("");
    try {
      const response = await createTournamentEntry(tournamentId, {
        organization_id: organizationId,
        player_id: selectedPlayer.player_id,
        first_name: selectedPlayer.first_name,
        surname: selectedPlayer.surname,
        email: selectedPlayer.email,
        home_club_name: selectedPlayer.home_club_name,
        ability_level: selectedAbility,
      });
      const nextTournament = response?.tournament || null;
      setTournament(nextTournament);
      setSearchQuery("");
      setSearchResults([]);
      setSearchPerformed(false);
      setSelectedPlayer(null);
      setSelectedAbility("");
      setMessage(describeAddedPlayer(findAddedEntry(nextTournament, selectedPlayer)));
    } catch (requestError) {
      setError(requestError.message || "Unable to add the player.");
    } finally {
      setSaving(false);
    }
  }

  async function handleImportFile(event) {
    const file = event.target.files?.[0];
    event.target.value = "";
    if (!file) return;
    setError("");
    setMessage("");
    try {
      const csvRows = parseCsv(await file.text());
      if (csvRows.length < 2) throw new Error("The CSV must contain a header row and at least one player.");
      const headers = csvRows[0].map((header) => header.trim().toLowerCase().replace(/[^a-z]/g, ""));
      const column = (...names) => headers.findIndex((header) => names.includes(header));
      const firstNameColumn = column("firstname", "first");
      const surnameColumn = column("surname", "lastname", "familyname");
      if (firstNameColumn < 0 || surnameColumn < 0) {
        throw new Error("CSV headers must include First Name and Surname.");
      }
      const emailColumn = column("email", "emailaddress");
      const clubColumn = column("club", "homeclub", "clubassociation");
      const abilityColumn = column("ability", "abilitylevel", "level");
      const existingByKey = new Map();
      (tournament?.entries || []).forEach((entry) => {
        existingByKey.set(normalizePlayerKey(entry), entry);
        existingByKey.set(`name:${entry.display_name.trim().toLowerCase().replace(/\s+/g, " ")}`, entry);
      });
      const seen = new Set();
      const parsedRows = csvRows.slice(1).map((cells, index) => {
        const player = {
          import_id: `${Date.now()}-${index}`,
          first_name: (cells[firstNameColumn] || "").trim(),
          surname: (cells[surnameColumn] || "").trim(),
          email: emailColumn >= 0 ? (cells[emailColumn] || "").trim() : "",
          home_club_name: clubColumn >= 0 ? (cells[clubColumn] || "").trim() : "",
          ability_level: abilityColumn >= 0 && ["1", "2", "3", "4"].includes((cells[abilityColumn] || "").trim())
            ? (cells[abilityColumn] || "").trim()
            : "1",
        };
        const key = normalizePlayerKey(player);
        const nameKey = `name:${`${player.first_name} ${player.surname}`.trim().toLowerCase().replace(/\s+/g, " ")}`;
        const existingEntry = existingByKey.get(key) || existingByKey.get(nameKey);
        const invalid = !player.first_name || !player.surname;
        const fileDuplicate = seen.has(key) || seen.has(nameKey);
        seen.add(key);
        seen.add(nameKey);
        return {
          ...player,
          key,
          duplicate_group_key: nameKey,
          existing_entry_id: existingEntry?.id || null,
          issue: invalid
            ? "First name and surname are required"
            : existingEntry
              ? "Already entered in this tournament"
              : fileDuplicate
                ? "Duplicate row in this import"
                : "",
          duplicate_type: existingEntry ? "tournament" : (fileDuplicate ? "file" : null),
          action: invalid || fileDuplicate ? "skip" : (existingEntry ? "skip" : "add"),
        };
      });
      const checkedRows = await Promise.all(parsedRows.map(async (row) => {
        if (row.issue || !row.first_name || !row.surname) return row;
        const lookup = row.email || `${row.first_name} ${row.surname}`;
        const response = await searchTournamentPlayers(organizationId, lookup);
        const normalizedEmail = row.email.toLowerCase();
        const normalizedName = `${row.first_name} ${row.surname}`.trim().toLowerCase().replace(/\s+/g, " ");
        const exactMatches = (response?.players || []).filter((candidate) => (
          (normalizedEmail && candidate.email.toLowerCase() === normalizedEmail)
          || candidate.display_name.trim().toLowerCase().replace(/\s+/g, " ") === normalizedName
        ));
        if (exactMatches.length !== 1) return row;
        const candidate = exactMatches[0];
        return {
          ...row,
          existing_player: candidate,
          issue: "Matches an existing HitNScore player",
          duplicate_type: "system",
          action: "use_existing",
        };
      }));
      setImportRows(checkedRows);
    } catch (requestError) {
      setImportRows([]);
      setError(requestError.message || "Unable to read the player import file.");
    }
  }

  function updateImportRow(importId, changes) {
    setImportRows((current) => current.map((row) => (
      row.import_id === importId ? { ...row, ...changes } : row
    )));
  }

  async function handleImportPlayers() {
    const chosenRows = importRows.filter((row) => row.action !== "skip" && !row.issue.startsWith("First name"));
    if (!chosenRows.length) {
      setError("Select at least one valid player to import.");
      return;
    }
    setImporting(true);
    setError("");
    setMessage("");
    let latestTournament = tournament;
    let importedCount = 0;
    const failures = [];
    const replacementKeys = new Set(chosenRows.filter((row) => row.action === "replace").map((row) => row.duplicate_group_key));
    const rowsToProcess = chosenRows.filter((row, index, allRows) => (
      !replacementKeys.has(row.duplicate_group_key)
      || index === allRows.map((item) => item.duplicate_group_key).lastIndexOf(row.duplicate_group_key)
    ));
    for (const row of rowsToProcess) {
      const existingEntry = row.existing_entry_id
        ? tournament.entries.find((entry) => entry.id === row.existing_entry_id)
        : null;
      const payload = {
        organization_id: organizationId,
        player_id: row.action === "use_existing" ? row.existing_player?.player_id : undefined,
        first_name: row.first_name,
        surname: row.surname,
        email: row.action === "use_existing"
          ? row.existing_player?.email
          : existingEntry?.claim_status === "linked" ? existingEntry.email : row.email,
        home_club_name: row.action === "use_existing"
          ? row.existing_player?.home_club_name
          : existingEntry?.claim_status === "linked" ? existingEntry.home_club_name : row.home_club_name,
        ability_level: row.ability_level,
      };
      try {
        const response = row.action === "update" && row.existing_entry_id
          ? await updateTournamentEntry(tournamentId, row.existing_entry_id, payload)
          : await createTournamentEntry(tournamentId, payload);
        latestTournament = response?.tournament || latestTournament;
        importedCount += 1;
      } catch (requestError) {
        failures.push(`${row.first_name} ${row.surname}: ${requestError.message || "Import failed"}`);
      }
    }
    setTournament(latestTournament);
    setImporting(false);
    if (failures.length) {
      setError(`${importedCount} player${importedCount === 1 ? "" : "s"} imported. ${failures.join(" ")}`);
    } else {
      setMessage(`${importedCount} player${importedCount === 1 ? "" : "s"} imported successfully.`);
      setImportRows([]);
      setImportOpen(false);
    }
  }

  function beginEditEntry(entry) {
    setEditingEntryId(entry.id);
    setEditForm({
      first_name: entry.first_name,
      surname: entry.surname,
      email: entry.email,
      home_club_name: entry.home_club_name,
      ability_level: String(entry.ability_level || 1),
      seed: entry.seed || "",
    });
    setError("");
    setMessage("");
  }

  async function handleUpdateEntry(event, entry) {
    event.preventDefault();
    setSaving(true);
    setError("");
    setMessage("");
    try {
      const response = await updateTournamentEntry(tournamentId, entry.id, {
        ...editForm,
        organization_id: organizationId,
      });
      setTournament(response?.tournament || tournament);
      setEditingEntryId(null);
      setEditForm(null);
      setMessage("Player details updated.");
    } catch (requestError) {
      setError(requestError.message || "Unable to update the player.");
    } finally {
      setSaving(false);
    }
  }

  async function handleGenerateDraw() {
    setDrawing(true);
    setError("");
    setMessage("");
    try {
      const response = await generateTournamentDraw(tournamentId, { organization_id: organizationId });
      setTournament(response?.tournament || tournament);
      setMessage(publishedDrawMissing
        ? "Missing published fixtures rebuilt."
        : "Draft draw generated. Review player positions before publishing.");
    } catch (requestError) {
      setError(requestError.message || "Unable to generate the draw.");
    } finally {
      setDrawing(false);
    }
  }

  async function handlePublishDraw() {
    setDrawing(true);
    setError("");
    setMessage("");
    try {
      const response = await publishTournamentDraw(tournamentId, { organization_id: organizationId });
      setTournament(response?.tournament || tournament);
      setMessage("Draw published and available through its public read-only key.");
    } catch (requestError) {
      setError(requestError.message || "Unable to publish the draw.");
    } finally {
      setDrawing(false);
    }
  }

  async function handleReturnToDraft() {
    if (!window.confirm("Return this published draw to draft? Public access will be disabled until you publish it again.")) return;
    setDrawing(true);
    setError("");
    setMessage("");
    try {
      const response = await returnTournamentDrawToDraft(tournamentId, { organization_id: organizationId });
      setTournament(response?.tournament || tournament);
      setMessage("The draw is back in draft and public access is disabled.");
    } catch (requestError) {
      setError(requestError.message || "Unable to return the draw to draft.");
    } finally {
      setDrawing(false);
    }
  }

  async function handleMovePlayer(matchId, slot, entryId) {
    if (!entryId) return;
    setDrawing(true);
    setError("");
    try {
      const response = await updateTournamentDrawSlot(tournamentId, matchId, {
        organization_id: organizationId,
        slot,
        entry_id: entryId,
      });
      setTournament(response?.tournament || tournament);
      setMessage("Draft draw position updated.");
    } catch (requestError) {
      setError(requestError.message || "Unable to move the player.");
    } finally {
      setDrawing(false);
    }
  }

  const visibleSearchResults = selectedPlayer ? [selectedPlayer] : searchResults.slice(0, 4);
  const generatedDraws = (tournament?.draws || []).filter((draw) => (draw.matches || []).length > 0);
  const entriesEditable = ["draft", "registration"].includes(tournament?.status);
  const publishedDrawMissing = tournament?.status === "draw_published" && generatedDraws.length === 0;
  const displayStatus = tournament?.status === "draw_published"
    ? (publishedDrawMissing ? "Draw needs rebuilding" : "Live")
    : generatedDraws.length ? "Draw ready" : (tournament?.status || "draft").replaceAll("_", " ");
  const publicDrawUrl = tournament?.public_draw_key && typeof window !== "undefined"
    ? `${window.location.origin}/tournament-draw/${tournament.public_draw_key}`
    : "";

  return (
    <main className="page-shell stack">
      <ClubPageHeader />

      {loading ? <div className="notice">Loading tournament...</div> : null}
      {message ? <div className="notice settings-success">{message}</div> : null}
      {error ? <div className="notice error">{error}</div> : null}

      {tournament ? (
        <>
          <section className="tournament-summary-grid">
            <article className="panel stack">
              <div className="dashboard-item-head">
                <div className="panel-heading">
                  <h2>{tournament.name}</h2>
                  <p className="helper-text">
                    {optionLabel(TOURNAMENT_SPORTS, tournament.sport)} · {optionLabel(TOURNAMENT_FORMATS, tournament.draw_format)}
                  </p>
                </div>
                <span className={`status-pill${publishedDrawMissing ? " warning" : ""}`}>{displayStatus}</span>
              </div>
              <div className="tournament-summary-details">
                <span>Venue: {tournament.venue_name || session?.organization_name || "Not set"}</span>
                <span>Start: {tournament.starts_on || "Not set"} · End: {tournament.ends_on || "Not set"}</span>
                <span>{tournament.audience === "open" ? "Open tournament" : "Internal tournament"}</span>
                <span>{tournament.graded_enabled ? "Graded tournament" : "Ungraded tournament"}</span>
                <span>{tournament.draw_size_limit ? `Size limit: ${tournament.draw_size_limit} entries` : "No size limit"}</span>
              </div>
            </article>
            <article className={`panel stack tournament-next-stage${generatedDraws.length ? " tournament-next-stage--wide" : ""}`}>
              <div className="panel-heading">
                <h2>Draw & Scheduling</h2>
                <p className="helper-text">
                  {generatedDraws.length
                    ? tournament.status === "draw_published"
                      ? "This draw is live and available through its public read-only key."
                      : "The draw is ready for review. Publish it when the player positions are correct."
                    : publishedDrawMissing
                      ? "The event was marked live, but no fixtures were returned. Rebuild the missing draw below."
                      : "Generate the tournament draw from the registered players. Entries lock only after you publish it."}
                </p>
              </div>
              {generatedDraws.length ? (
                <div className="tournament-draws stack">
                  {entriesEditable && isAdmin ? (
                    <div className="tournament-draw-review stack">
                      <p className="helper-text">Review the draw below. Use the player selectors to swap positions, or change seeds and regenerate before making it live.</p>
                      <div className="button-row">
                        <button disabled={drawing} type="button" onClick={handlePublishDraw}>Publish Draw</button>
                        <button className="secondary" disabled={drawing} type="button" onClick={handleGenerateDraw}>Regenerate from Seeds</button>
                      </div>
                    </div>
                  ) : null}
                  {generatedDraws.map((draw) => {
                    const drawEntries = (tournament.entries || []).filter((entry) => !draw.grade || entry.ability_grade === draw.grade);
                    const knockout = tournament.draw_format === "knockout" || tournament.draw_format === "knockout_plate";
                    return knockout ? (
                      <React.Fragment key={draw.id || draw.name}>
                        <TournamentBracket
                          draw={draw}
                          entries={drawEntries}
                          editable={isAdmin && entriesEditable && !drawing}
                          title={`${draw.name} — Championship`}
                          onMove={handleMovePlayer}
                        />
                        {tournament.draw_format === "knockout_plate" && buildPlateDraw(draw).matches.length ? (
                          <TournamentBracket draw={buildPlateDraw(draw)} title={`${draw.name} — Plate`} />
                        ) : null}
                      </React.Fragment>
                    ) : (
                      <section className="tournament-draw" key={draw.id || draw.name}>
                        <div className="dashboard-item-head"><h3>{draw.name}</h3><span className="status-pill">{draw.status}</span></div>
                        {[...new Set(draw.matches.map((match) => match.round_number))].map((roundNumber) => (
                          <div className="tournament-draw-round" key={`${draw.id}-${roundNumber}`}>
                            <strong>{`Round ${roundNumber}`}</strong>
                            {draw.matches.filter((match) => match.round_number === roundNumber).map((match) => (
                              <div className="tournament-draw-match" key={match.id}><span>{match.player1_name}</span><small>vs</small><span>{match.player2_name || "—"}</span></div>
                            ))}
                          </div>
                        ))}
                      </section>
                    );
                  })}
                  {tournament.draw_format === "monrad" ? (
                    <p className="helper-text">Later Monrad rounds will be paired from standings after opening-round results.</p>
                  ) : null}
                  {tournament.status === "draw_published" ? (
                    <div className="tournament-public-access stack">
                      <div><strong>Public read-only draw key</strong><code>{tournament.public_draw_key || "Unavailable"}</code></div>
                      {publicDrawUrl ? <a href={publicDrawUrl} target="_blank" rel="noreferrer">Open Public Draw</a> : null}
                      {isAdmin ? (
                        <div className="button-row">
                          {!tournament.public_draw_key ? <button disabled={drawing} type="button" onClick={handlePublishDraw}>Enable Public Access</button> : null}
                          <button className="secondary" disabled={drawing} type="button" onClick={handleReturnToDraft}>Return Draw to Draft</button>
                        </div>
                      ) : null}
                    </div>
                  ) : null}
                </div>
              ) : (
                <>
                  <div className="button-row">
                    <button
                      disabled={!isAdmin || drawing || (tournament.entries || []).length < 2}
                      type="button"
                      onClick={handleGenerateDraw}
                    >
                      {drawing ? (publishedDrawMissing ? "Rebuilding..." : "Generating...") : (publishedDrawMissing ? "Rebuild Missing Draw" : "Generate Draw")}
                    </button>
                  </div>
                  {(tournament.entries || []).length < 2 ? <p className="helper-text">Add at least two players to enable the draw.</p> : null}
                  {!isAdmin ? <p className="helper-text">A club administrator can generate the draw.</p> : null}
                </>
              )}
            </article>
          </section>

          <section className="tournament-manager-grid">
            {isAdmin ? <section className="panel stack">
              <div className="panel-heading">
                <h2>Add Players</h2>
                <p className="helper-text">
                  Search the shared HitNScore player list first. If there is no match, add a new player manually.
                </p>
              </div>
              {entriesEditable ? <>
              <div className="stack">
                <div className="field tournament-player-search">
                  <label htmlFor="tournament-player-search">Search Players</label>
                  <input
                    id="tournament-player-search"
                    placeholder="Type a name or email address"
                    value={searchQuery}
                    onChange={(event) => setSearchQuery(event.target.value)}
                  />
                  {searching ? <small className="tournament-search-status">Searching...</small> : null}
                </div>
              </div>

              {visibleSearchResults.length ? (
                <div className="tournament-search-results" aria-label="Player search results">
                  {visibleSearchResults.map((player) => {
                    const key = player.player_id || player.user_id || player.email;
                    const selected = (selectedPlayer?.player_id || selectedPlayer?.user_id) === (player.player_id || player.user_id);
                    return (
                      <button
                        className={`tournament-search-result${selected ? " tournament-search-result--selected" : ""}`}
                        key={key}
                        type="button"
                        onClick={() => setSelectedPlayer(player)}
                      >
                        <span><strong>{player.display_name || player.email}</strong><small>{player.email}</small></span>
                        <span><small>{player.home_club_name || "No home club"}</small><span className="status-pill">{player.relationship}</span></span>
                      </button>
                    );
                  })}
                </div>
              ) : searchPerformed && !searching ? <p className="helper-text">No matching player was found. You can add them manually below.</p> : null}

              {selectedPlayer ? (
                <form className="stack" onSubmit={handleAddSelected}>
                  <AbilitySelector idPrefix="selected-player" value={selectedAbility} onChange={setSelectedAbility} />
                  <div className="button-row">
                    <button disabled={saving || !selectedAbility} type="submit">{saving ? "Adding..." : `Add ${selectedPlayer.display_name}`}</button>
                  </div>
                </form>
              ) : null}

              <div className="tournament-manual-divider"><span>Player not found?</span></div>
              <div className="button-row tournament-add-player-row">
                <button type="button" onClick={() => setManualEntryOpen((current) => !current)}>
                  {manualEntryOpen ? "Close Manual Entry" : "Add Player Manually"}
                </button>
                <button className="secondary" type="button" onClick={() => setImportOpen((current) => !current)}>
                  {importOpen ? "Close Player Import" : "Import Players"}
                </button>
              </div>

              {importOpen ? (
                <section className="tournament-import stack" aria-label="Import players">
                  <div className="panel-heading">
                    <h3>Import Players from CSV</h3>
                    <p className="helper-text">
                      Required columns: First Name and Surname. Optional columns: Email, Club and Ability (1–4).
                    </p>
                  </div>
                  <div className="button-row">
                    <label className="button-link" htmlFor="tournament-player-import">Choose CSV File</label>
                    <input
                      accept=".csv,text/csv"
                      className="visually-hidden"
                      id="tournament-player-import"
                      type="file"
                      onChange={handleImportFile}
                    />
                  </div>
                  {importRows.length ? (
                    <div className="tournament-import-preview">
                      {importRows.map((row) => (
                        <article
                          className={`tournament-import-row${row.issue ? " tournament-import-row--warning" : ""}`}
                          key={row.import_id}
                        >
                          <div>
                            <strong>{row.first_name || "Missing first name"} {row.surname || "Missing surname"}</strong>
                            <small>{row.email || "No email"} · {row.home_club_name || "No club"} · {abilityLabel(row.ability_level)}</small>
                            {row.issue ? <span>{row.issue}</span> : null}
                          </div>
                          {row.duplicate_type === "tournament" ? (
                            <select
                              aria-label={`Duplicate action for ${row.first_name} ${row.surname}`}
                              value={row.action}
                              onChange={(event) => updateImportRow(row.import_id, { action: event.target.value })}
                            >
                              <option value="skip">Skip duplicate</option>
                              <option value="update">Update tournament entry</option>
                            </select>
                          ) : row.duplicate_type === "file" ? (
                            <select
                              aria-label={`Duplicate action for ${row.first_name} ${row.surname}`}
                              value={row.action}
                              onChange={(event) => updateImportRow(row.import_id, { action: event.target.value })}
                            >
                              <option value="skip">Keep earlier row</option>
                              <option value="replace">Use this row instead</option>
                            </select>
                          ) : row.duplicate_type === "system" ? (
                            <select
                              aria-label={`Existing player action for ${row.first_name} ${row.surname}`}
                              value={row.action}
                              onChange={(event) => updateImportRow(row.import_id, { action: event.target.value })}
                            >
                              <option value="use_existing">Use existing player</option>
                              <option value="skip">Skip player</option>
                            </select>
                          ) : row.issue ? <span className="status-pill">Cannot import</span> : <span className="status-pill">Ready</span>}
                        </article>
                      ))}
                    </div>
                  ) : null}
                  {importRows.length ? (
                    <div className="button-row">
                      <button disabled={importing} type="button" onClick={handleImportPlayers}>
                        {importing ? "Importing..." : "Import Selected Players"}
                      </button>
                    </div>
                  ) : null}
                </section>
              ) : null}

              {manualEntryOpen ? <form className="stack" onSubmit={handleAddEntry}>
                <div className="field-grid">
                  <div className="field">
                    <label htmlFor="entry-first-name">First Name</label>
                    <input
                      id="entry-first-name"
                      required
                      value={entryForm.first_name}
                      onChange={(event) => setEntryForm((current) => ({ ...current, first_name: event.target.value }))}
                    />
                  </div>
                  <div className="field">
                    <label htmlFor="entry-surname">Surname</label>
                    <input
                      id="entry-surname"
                      required
                      value={entryForm.surname}
                      onChange={(event) => setEntryForm((current) => ({ ...current, surname: event.target.value }))}
                    />
                  </div>
                  <div className="field settings-field-wide">
                    <label htmlFor="entry-email">Email Address</label>
                    <input
                      id="entry-email"
                      type="email"
                      value={entryForm.email}
                      onChange={(event) => setEntryForm((current) => ({ ...current, email: event.target.value }))}
                    />
                  </div>
                  <div className="field">
                    <label htmlFor="entry-club">Home Club</label>
                    <input
                      id="entry-club"
                      value={entryForm.home_club_name}
                      onChange={(event) => setEntryForm((current) => ({ ...current, home_club_name: event.target.value }))}
                    />
                  </div>
                </div>
                <AbilitySelector
                  idPrefix="manual-player"
                  value={entryForm.ability_level}
                  onChange={(value) => setEntryForm((current) => ({ ...current, ability_level: value }))}
                />
                <div className="button-row">
                  <button disabled={saving} type="submit">{saving ? "Adding..." : "Add Tournament Player"}</button>
                </div>
              </form> : null}
              </> : <p className="helper-text">Player entries are locked because the draw has been published.</p>}
            </section> : (
              <section className="panel stack">
                <div className="panel-heading">
                  <h2>Member View</h2>
                  <p className="helper-text">Entries are read-only. A club administrator manages players, draws and scheduling.</p>
                </div>
              </section>
            )}

            <section className="panel stack">
              <div className="panel-heading">
                <h2>Entries</h2>
                <p className="helper-text">{tournament.entries.length} registered player{tournament.entries.length === 1 ? "" : "s"}</p>
              </div>
              <div className="dashboard-list">
                {tournament.entries.length === 0 ? (
                  <div className="dashboard-empty">No players have been added yet.</div>
                ) : tournament.entries.map((entry) => (
                  <article className={`dashboard-item${editingEntryId === entry.id ? "" : " tournament-entry-card"}`} key={entry.id}>
                    {editingEntryId === entry.id && editForm ? (
                      <form className="stack" onSubmit={(event) => handleUpdateEntry(event, entry)}>
                        <div className="field-grid">
                          <div className="field">
                            <label htmlFor={`edit-first-${entry.id}`}>First Name</label>
                            <input
                              id={`edit-first-${entry.id}`}
                              required
                              value={editForm.first_name}
                              onChange={(event) => setEditForm((current) => ({ ...current, first_name: event.target.value }))}
                            />
                          </div>
                          <div className="field">
                            <label htmlFor={`edit-surname-${entry.id}`}>Surname</label>
                            <input
                              id={`edit-surname-${entry.id}`}
                              required
                              value={editForm.surname}
                              onChange={(event) => setEditForm((current) => ({ ...current, surname: event.target.value }))}
                            />
                          </div>
                          <div className="field">
                            <label htmlFor={`edit-email-${entry.id}`}>Email Address</label>
                            <input
                              disabled={entry.claim_status === "linked"}
                              id={`edit-email-${entry.id}`}
                              type="email"
                              value={editForm.email}
                              onChange={(event) => setEditForm((current) => ({ ...current, email: event.target.value }))}
                            />
                          </div>
                          <div className="field">
                            <label htmlFor={`edit-club-${entry.id}`}>Home Club</label>
                            <input
                              disabled={entry.claim_status === "linked"}
                              id={`edit-club-${entry.id}`}
                              value={editForm.home_club_name}
                              onChange={(event) => setEditForm((current) => ({ ...current, home_club_name: event.target.value }))}
                            />
                          </div>
                          <div className="field settings-field-wide">
                            <label htmlFor={`edit-ability-${entry.id}`}>Player Ability</label>
                            <select
                              id={`edit-ability-${entry.id}`}
                              value={editForm.ability_level}
                              onChange={(event) => setEditForm((current) => ({ ...current, ability_level: event.target.value }))}
                            >
                              {ABILITY_OPTIONS.map((option) => (
                                <option key={option.value} value={option.value}>{abilityLabel(option.value)}</option>
                              ))}
                            </select>
                          </div>
                          <div className="field">
                            <label htmlFor={`edit-seed-${entry.id}`}>Seed</label>
                            <select
                              id={`edit-seed-${entry.id}`}
                              value={editForm.seed}
                              onChange={(event) => setEditForm((current) => ({ ...current, seed: event.target.value }))}
                            >
                              <option value="">Unseeded</option>
                              {Array.from({ length: 8 }, (_, index) => index + 1).map((seed) => (
                                <option key={seed} value={seed}>{seed}</option>
                              ))}
                            </select>
                          </div>
                        </div>
                        {entry.claim_status === "linked" ? (
                          <p className="helper-text">Email and home club come from the existing HitNScore account and cannot be changed here.</p>
                        ) : null}
                        <div className="button-row">
                          <button disabled={saving} type="submit">{saving ? "Saving..." : "Save Player Changes"}</button>
                          <button className="secondary" type="button" onClick={() => setEditingEntryId(null)}>Cancel</button>
                        </div>
                      </form>
                    ) : (
                      <>
                        <div className="tournament-entry-card__content">
                          <div className="tournament-entry-card__identity">
                            <strong>{entry.display_name}</strong>
                            <span>{entry.email || "Named player — no email yet"}</span>
                            <span>{entry.home_club_name || "No home club recorded"}</span>
                          </div>
                          <div className="tournament-entry-card__indicators">
                            {entry.ability_level ? (
                              <EntryIndicator
                                className={`tournament-grade-pill tournament-grade-pill--${(entry.ability_grade || "").toLowerCase()}`}
                                description={`Grade ${entry.ability_grade} player ability`}
                                label={`Grade ${entry.ability_grade}`}
                              >
                                {entry.ability_grade}
                              </EntryIndicator>
                            ) : null}
                            {entry.seed ? (
                              <EntryIndicator className="tournament-seed-pill" description={`Seed ${entry.seed} in this tournament draw`} label={`Seed ${entry.seed}`}>
                                {entry.seed}
                              </EntryIndicator>
                            ) : null}
                            {entry.claim_status === "linked" ? (
                              <EntryIndicator
                                className="tournament-link-indicator"
                                description="Linked to a registered HitNScore account. Account-owned identity details are managed from that account."
                                label="Linked HitNScore account"
                              >
                                <LinkIcon />
                              </EntryIndicator>
                            ) : null}
                            {entry.relationship === "member" ? (
                              <EntryIndicator
                                className="tournament-member-indicator"
                                description="Approved member of the club hosting this tournament."
                                label="Club member"
                              >
                                <MemberIcon />
                              </EntryIndicator>
                            ) : null}
                          </div>
                        </div>
                        {isAdmin && entriesEditable ? (
                          <div className="button-row tournament-entry-actions">
                            <button type="button" onClick={() => beginEditEntry(entry)}>Edit Player</button>
                          </div>
                        ) : null}
                      </>
                    )}
                  </article>
                ))}
              </div>
            </section>
          </section>
        </>
      ) : null}

      <AppFooter />
    </main>
  );
}
