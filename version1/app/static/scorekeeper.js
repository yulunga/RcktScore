const gameData = JSON.parse(document.getElementById('game-data').textContent);
const scoreType = gameData.score_type;
const player1Name = gameData.player1_name;
const player1Country = gameData.player1_country;
const player2Name = gameData.player2_name;
const player2Country = gameData.player2_country;

const player1ScoreDisplay = document.getElementById('player1-score');
const player2ScoreDisplay = document.getElementById('player2-score');
const player1NameDisplay = document.getElementById('player1-name');
const player2NameDisplay = document.getElementById('player2-name');
const player1CountryDisplay = document.getElementById('player1-country');
const player2CountryDisplay = document.getElementById('player2-country');
const scoreTypeDisplay = document.getElementById('score-type');
const scoreLimit = parseInt(scoreType);

let player1Score = 0;
let player2Score = 0;

// update player names, countries, and score type on the page
player1NameDisplay.textContent = player1Name;
player2NameDisplay.textContent = player2Name;
player1CountryDisplay.textContent = player1Country;
player2CountryDisplay.textContent = player2Country;
scoreTypeDisplay.textContent = `Score Type: ${scoreType}`;

// update player scores on the page
player1ScoreDisplay.textContent = player1Score;
player2ScoreDisplay.textContent = player2Score;

// add event listeners for score buttons
const player1ScoreButtons = document.querySelectorAll('.player1-score-button');
const player2ScoreButtons = document.querySelectorAll('.player2-score-button');

player1ScoreButtons.forEach(button => {
  button.addEventListener('click', () => {
    if (player1Score < scoreLimit) {
      player1Score++;
      player1ScoreDisplay.textContent = player1Score;
      if (player1Score === scoreLimit) {
        alert(`${player1Name} has won the game!`);
        window.location.href = '/new-game';
      }
    }
  });
});

player2ScoreButtons.forEach(button => {
  button.addEventListener('click', () => {
    if (player2Score < scoreLimit) {
      player2Score++;
      player2ScoreDisplay.textContent = player2Score;
      if (player2Score === scoreLimit) {
        alert(`${player2Name} has won the game!`);
        window.location.href = '/new-game';
      }
    }
  });
});

// add event listener for reset button
const resetButton = document.getElementById('reset-button');
resetButton.addEventListener('click', () => {
  player1Score = 0;
  player2Score = 0;
  player1ScoreDisplay.textContent = player1Score;
  player2ScoreDisplay.textContent = player2Score;
});
