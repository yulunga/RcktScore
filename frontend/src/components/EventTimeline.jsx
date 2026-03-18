import React from "react";

export default function EventTimeline({ events = [] }) {
  return (
    <section className="timeline-card">
      <h2>Event Timeline</h2>
      <div className="timeline-scroll">
        <ul className="timeline-list">
          {events.length === 0 ? (
            <li className="timeline-item">No events recorded yet.</li>
          ) : (
            events.map((event) => (
              <li className="timeline-item" key={event.id || event.created_at}>
                <strong>{event.event_type}</strong>
                <span>{event.summary || JSON.stringify(event.payload || {})}</span>
                <small>{event.created_at}</small>
              </li>
            ))
          )}
        </ul>
      </div>
    </section>
  );
}
