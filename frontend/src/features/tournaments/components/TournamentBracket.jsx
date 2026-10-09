import React from "react";

function playerLabel(entry, fallback) {
  if (!entry) return fallback || "TBD";
  return `${entry.seed ? `(${entry.seed}) ` : ""}${entry.display_name}`;
}

function BracketSlot({ editable, entries, match, slot, onMove }) {
  const entryId = match[`${slot}_entry_id`];
  const name = match[`${slot}_name`];
  const selectedEntry = entries.find((entry) => entry.id === entryId);
  if (!editable) {
    return <span className={!entryId ? "tournament-bracket-slot--empty" : ""}>{playerLabel(selectedEntry, name || "Bye")}</span>;
  }
  return (
    <select
      aria-label={`Move ${name || "player"} in the draw`}
      value={entryId || ""}
      onChange={(event) => onMove(match.id, slot, event.target.value)}
    >
      {!entryId ? <option disabled value="">Bye — choose a player to move here</option> : null}
      {entries.map((entry) => (
        <option key={entry.id} value={entry.id}>{playerLabel(entry)}</option>
      ))}
    </select>
  );
}

export default function TournamentBracket({ draw, entries = [], editable = false, onMove, title }) {
  const firstRound = (draw?.matches || []).filter((match) => Number(match.round_number) === 1);
  if (!firstRound.length) return null;
  const rounds = [{ number: 1, matches: firstRound }];
  let previousCount = firstRound.length;
  let roundNumber = 2;
  while (previousCount > 1) {
    const matchCount = Math.ceil(previousCount / 2);
    rounds.push({
      number: roundNumber,
      matches: Array.from({ length: matchCount }, (_value, index) => ({
        id: `${draw.id || draw.name}-future-${roundNumber}-${index + 1}`,
        player1_name: `Winner ${index * 2 + 1}`,
        player2_name: index * 2 + 2 <= previousCount ? `Winner ${index * 2 + 2}` : "Bye",
      })),
    });
    previousCount = matchCount;
    roundNumber += 1;
  }

  return (
    <section className="tournament-bracket-section" aria-label={`${title || draw.name} bracket`}>
      <div className="dashboard-item-head tournament-bracket-heading">
        <h3>{title || draw.name}</h3>
        {editable ? <span className="status-pill">Draft — editable</span> : null}
      </div>
      <div className="tournament-bracket-scroll">
        <div className="tournament-bracket">
          {rounds.map((round, roundIndex) => (
            <section className="tournament-bracket-round" key={round.number}>
              <strong>{round.matches.length === 1 ? "Final" : `Round ${round.number}`}</strong>
              <div className="tournament-bracket-round__matches">
                {round.matches.map((match) => (
                  <article className={`tournament-bracket-match tournament-bracket-match--round-${roundIndex + 1}`} key={match.id}>
                    {round.number === 1 ? (
                      <>
                        <BracketSlot editable={editable} entries={entries} match={match} slot="player1" onMove={onMove} />
                        <BracketSlot editable={editable} entries={entries} match={match} slot="player2" onMove={onMove} />
                      </>
                    ) : (
                      <>
                        <span className="tournament-bracket-slot--empty">{match.player1_name}</span>
                        <span className="tournament-bracket-slot--empty">{match.player2_name}</span>
                      </>
                    )}
                  </article>
                ))}
              </div>
            </section>
          ))}
        </div>
      </div>
    </section>
  );
}
