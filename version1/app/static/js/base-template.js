
// Javascript to countdown after user inactivity and log user out

let idleTime = 0;
let warningShown = false;
let countdownTimer = null;
let timeoutModal = null;

function resetIdleTime() {
    idleTime = 0;

    if (timeoutModal) {
        timeoutModal.hide(); // Hide using the Bootstrap API
    }

    warningShown = false;
    if (countdownTimer) clearInterval(countdownTimer);
    countdownTimer = null;
}

function showTimeoutWarning() {
    const modalEl = document.getElementById('timeoutModal');
    timeoutModal = bootstrap.Modal.getOrCreateInstance(modalEl);
    timeoutModal.show();

    let seconds = 60;
    document.getElementById('timeoutCountdown').innerText = seconds;

    countdownTimer = setInterval(() => {
        seconds--;
        document.getElementById('timeoutCountdown').innerText = seconds;

        if (seconds <= 0) {
            clearInterval(countdownTimer);
            countdownTimer = null;
            const logoutUrl = document.body.dataset.logoutUrl;
            window.location.href = logoutUrl;
        }
    }, 1000);
}

// Event listeners
['mousemove', 'keydown', 'click'].forEach(evt => {
    document.addEventListener(evt, resetIdleTime, false);
});

setInterval(() => {
    idleTime += 1;
    if (idleTime === 5 && !warningShown) {  // 14 minutes of inactivity
        warningShown = true;
        showTimeoutWarning();
    }
}, 60000); // every 1 minute

document.getElementById('stayLoggedInBtn').addEventListener('click', () => {
    resetIdleTime();
    // Optional: ping the server
    fetch(location.href, { method: 'GET', cache: 'no-store' });
});
