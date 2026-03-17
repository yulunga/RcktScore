/**
 * Initializes inline editing functionality for specified elements.
 * 
 * @param {string} selector - CSS selector for the elements to make editable.
 * @param {string} updateUrlTemplate - URL template for the update API, with `{id}` as a placeholder for the item ID.
 * @param {string} feedbackSelector - CSS selector for the feedback element (default is '#feedback').
 */

let activeEditor = null;

function initInlineEditable(selector, updateUrlTemplate, feedbackSelector = '#feedback') {
    const feedback = document.querySelector(feedbackSelector);
    let activeEditor = null;

    function attachEditable(span) {
        if (activeEditor) return;

        const field = span.dataset.field;
        const courtRow = span.closest('tr');
        const courtId = courtRow.dataset.courtId;
        const oldValue = span.textContent.trim();

        const input = document.createElement('input');
        input.type = 'text';
        input.value = oldValue;
        input.classList.add('form-control', 'form-control-sm');
        activeEditor = input;

        const saveChange = () => {
            const newValue = input.value.trim();
            const url = updateUrlTemplate.replace('{id}', courtId);

            fetch(url, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'X-Requested-With': 'XMLHttpRequest'
                },
                body: JSON.stringify({ field, value: newValue })
            })
            .then(res => {
                if (!res.ok) throw new Error(`HTTP ${res.status}`);
                return res.json();
            })
            .then(data => {
                const newSpan = document.createElement('span');
                newSpan.className = span.className;
                newSpan.dataset.field = field;
                newSpan.textContent = newValue;

                // Re-attach the click handler so it's still editable
                newSpan.addEventListener('click', () => attachEditable(newSpan));
                input.replaceWith(newSpan);
                activeEditor = null;

                // Visual feedback
                newSpan.classList.add('bg-success', 'text-white');
                setTimeout(() => newSpan.classList.remove('bg-success', 'text-white'), 1500);

                if (feedback) {
                    feedback.textContent = '✅ Update successful';
                    feedback.className = 'alert alert-success';
                    feedback.classList.remove('d-none');
                    setTimeout(() => feedback.classList.add('d-none'), 2000);
                }
            })
            .catch(err => {
                console.error("❌ Update failed:", err);
                input.replaceWith(span);
                activeEditor = null;

                span.classList.add('bg-danger', 'text-white');
                setTimeout(() => span.classList.remove('bg-danger', 'text-white'), 1500);

                if (feedback) {
                    feedback.textContent = '❌ Update failed';
                    feedback.className = 'alert alert-danger';
                    feedback.classList.remove('d-none');
                    setTimeout(() => feedback.classList.add('d-none'), 2000);
                }
            });
        };

        input.addEventListener('blur', saveChange);
        input.addEventListener('keydown', (e) => {
            if (e.key === 'Enter') {
                e.preventDefault();
                input.blur();
            }
        });

        span.replaceWith(input);
        input.focus();
    }

    document.querySelectorAll(selector).forEach(span => {
        span.addEventListener('click', () => attachEditable(span));
    });
}
