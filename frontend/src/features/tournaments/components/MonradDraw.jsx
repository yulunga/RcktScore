import React from "react";

import { BracketSlot, TournamentMatchMenu } from "./TournamentBracket";

function ordinal(value) {
  const number = Number(value);
  const remainder = number % 100;
  if (remainder >= 11 && remainder <= 13) return `${number}th`;
  if (number % 10 === 1) return `${number}st`;
  if (number % 10 === 2) return `${number}nd`;
  if (number % 10 === 3) return `${number}rd`;
  return `${number}th`;
}

function roundTitle(roundNumber, roundCount, fieldSize) {
  if (roundNumber === 1) return `Last ${fieldSize}`;
  if (roundNumber === roundCount) return "Finals";
  if (roundNumber === roundCount - 1) return "Semis";
  if (roundNumber === roundCount - 2) return "Quarters";
  return `Round ${roundNumber}`;
}

function placementRange(firstRoundMatchCount, roundNumber, matchNumber) {
  const groups = 2 ** (roundNumber - 1);
  const matchesPerGroup = firstRoundMatchCount / groups;
  const groupIndex = Math.floor((matchNumber - 1) / matchesPerGroup);
  const groupSize = (firstRoundMatchCount * 2) / groups;
  const start = (groupIndex * groupSize) + 1;
  return [start, start + groupSize - 1];
}

function playerName(match, slot, fallback) {
  return match[`${slot}_name`] || fallback;
}

function finalPositions(finalMatches, fieldSize) {
  const positions = new Map();
  finalMatches.forEach((match) => {
    const firstPosition = (Number(match.match_number) * 2) - 1;
    const winnerId = match.winner_entry_id;
    const winnerName = winnerId && String(winnerId) === String(match.player1_entry_id)
      ? match.player1_name
      : winnerId && String(winnerId) === String(match.player2_entry_id)
        ? match.player2_name
        : null;
    const loserName = winnerId && String(winnerId) === String(match.player1_entry_id)
      ? match.player2_name
      : winnerId && String(winnerId) === String(match.player2_entry_id)
        ? match.player1_name
        : null;
    if (winnerName) positions.set(firstPosition, winnerName);
    if (loserName) positions.set(firstPosition + 1, loserName);
  });
  return Array.from({ length: fieldSize }, (_value, index) => ({
    position: index + 1,
    name: positions.get(index + 1),
  }));
}

export default function MonradDraw({ draw, entries = [], editable = false, isAdmin = false, onMove, onSchedule, onScore, title }) {
  const matches = draw?.matches || [];
  const firstRound = matches.filter((match) => Number(match.round_number) === 1);
  if (!firstRound.length) return null;

  const firstRoundMatchCount = firstRound.length;
  const fieldSize = firstRoundMatchCount * 2;
  const roundNumbers = [...new Set(matches.map((match) => Number(match.round_number)))].sort((a, b) => a - b);
  const roundCount = roundNumbers.length;
  const finalRound = matches.filter((match) => Number(match.round_number) === roundCount);
  const positions = finalPositions(finalRound, fieldSize);

  return (
    <section className="tournament-bracket-section tournament-monrad-section" aria-label={`${title || draw.name} Monrad draw`}>
      <div className="dashboard-item-head tournament-bracket-heading">
        <h3>{title || draw.name}</h3>
        {editable ? <span className="status-pill">Draft — editable</span> : null}
      </div>
      <p className="helper-text tournament-monrad-help">Winners and losers both continue after every round, producing a final placing for every player.</p>
      <div className="tournament-bracket-scroll">
        <div className="tournament-monrad-grid">
          {roundNumbers.map((roundNumber) => {
            const roundMatches = matches.filter((match) => Number(match.round_number) === roundNumber);
            return (
              <section className="tournament-monrad-round" key={roundNumber}>
                <header>
                  <strong>{roundTitle(roundNumber, roundCount, fieldSize)}</strong>
                  <small>{`Round ${roundNumber}`}{roundNumber === roundCount ? " · placings" : ""}</small>
                </header>
                <div className="tournament-monrad-round__matches">
                  {roundMatches.map((match) => {
                    const [start, end] = placementRange(firstRoundMatchCount, roundNumber, Number(match.match_number));
                    const rangeLabel = start === end ? ordinal(start) : `${ordinal(start)}–${ordinal(end)}`;
                    return (
                      <article className="tournament-monrad-match" key={match.id}>
                        <div className="tournament-monrad-match__number"><strong>{match.match_number}</strong><small>{rangeLabel}</small></div>
                        <div className="tournament-monrad-match__players">
                          {roundNumber === 1 && editable ? (
                            <>
                              <BracketSlot editable entries={entries} match={match} slot="player1" onMove={onMove} />
                              <BracketSlot editable entries={entries} match={match} slot="player2" onMove={onMove} />
                            </>
                          ) : (
                            <>
                              <span className={!match.player1_entry_id ? "tournament-bracket-slot--empty" : ""}>{playerName(match, "player1", "Awaiting previous result")}</span>
                              <span className={!match.player2_entry_id ? "tournament-bracket-slot--empty" : ""}>{playerName(match, "player2", "Awaiting previous result")}</span>
                            </>
                          )}
                        </div>
                        {match.score_summary ? <span className="tournament-monrad-match__score">{match.score_summary}</span> : null}
                        {!editable && onSchedule && onScore ? (
                          <TournamentMatchMenu isAdmin={isAdmin} match={match} onSchedule={onSchedule} onScore={onScore} />
                        ) : null}
                      </article>
                    );
                  })}
                </div>
              </section>
            );
          })}
          <section className="tournament-monrad-round tournament-monrad-finishing">
            <header><strong>Finishing</strong><small>Final positions</small></header>
            <div className="tournament-monrad-finishing__positions">
              {positions.map(({ position, name }) => (
                <div key={position}><strong>{position}</strong><span>{name || "—"}</span></div>
              ))}
            </div>
          </section>
        </div>
      </div>
    </section>
  );
}
