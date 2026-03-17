
const gameId = document.getElementById('scorewrapper').dataset.gameId;
const playersElem = document.getElementById('players');
const player1NameElem = document.getElementById('player1-name');
const player2NameElem = document.getElementById('player2-name');
const player1ScoreElem = document.getElementById('player1-score');
const player2ScoreElem = document.getElementById('player2-score');
const servingElem = document.getElementById('serving'); 
const pointHistoryElem = document.getElementById('point-history');

async function fetchScores() {
        try {
            const response = await fetch(`/game/matchscore/logs/${gameId}`);
            if (!response.ok) {
                throw new Error('Network response was not ok');
            }
            const data = await response.json();

            // Update player names
            const player1 = data.player1_name || 'Player 1';
            const player2 = data.player2_name || 'Player 2';
            if (player1NameElem)player1NameElem.textContent = player1;
            if (player2NameElem)player2NameElem.textContent = player2;

            // Update scores
            const scores = data.scores || {};
            const player1Score = scores.player1 !== undefined ? scores.player1 : 0;
            const player2Score = scores.player2 !== undefined ? scores.player2 : 0;
            if (player1ScoreElem)player1ScoreElem.textContent = player1Score;
            if (player2ScoreElem)player2ScoreElem.textContent = player2Score;

            // Update serving information
            // Assuming 'serving_player' and 'serving_side' are part of the JSON response
            const servingPlayer = data.serving_player;
            const servingSide = data.serving_side || 'Right';
            if (servingPlayer === 1) {
                servingElem.textContent = `${player1} is serving from the ${servingSide} side`;
            } else if (servingPlayer === 2) {
                servingElem.textContent = `${player2} is serving from the ${servingSide} side`;
            } else {
                servingElem.textContent = 'Serving information not available';
            }

            // Update point history
            const events = data.events || [];
            pointHistoryElem.innerHTML = '';
            events.forEach(event => {
                const li = document.createElement('li');
                if (event.event_type === 'score') {
                    li.textContent = `${event.data.player} scored`;
                } else if (['let', 'stroke', 'undo', 'serve_side'].includes(event.event_type)) {
                    const detail = event.data.player || event.data.side || '';
                    li.textContent = `${event.event_type.charAt(0).toUpperCase() + event.event_type.slice(1)}: ${detail}`;
                } else {
                    li.textContent = `${event.event_type}`;
                }
                pointHistoryElem.appendChild(li);
            });
        } catch (error) {
            console.error('Error fetching scores:', error);
        }
}

    // Initial fetch
    fetchScores();

    // Poll every 2 seconds
    setInterval(fetchScores, 2000);