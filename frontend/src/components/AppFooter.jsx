import React, { useState } from "react";
import { Link } from "react-router-dom";
import packageJson from "../../package.json";
import { useAuth } from "../hooks/useAuth";

const APP_VERSION = `v${packageJson.version}`;
const BUILD_ID = import.meta.env.VITE_BUILD_ID || "local";
const DISPLAY_BUILD_ID = String(BUILD_ID).replace(/^0+(?=\d)/, "");

export default function AppFooter() {
  const { isAuthenticated } = useAuth();
  const [showHelpOptions, setShowHelpOptions] = useState(false);

  return (
    <footer className="app-footer">
      <span>{`RcktScore ${APP_VERSION} • build ${DISPLAY_BUILD_ID}`}</span>
      {isAuthenticated ? (
        <>
          <span className="app-footer__divider" aria-hidden="true">|</span>
          <button
            className="app-footer__help-button"
            type="button"
            onClick={() => setShowHelpOptions(true)}
          >
            Need Help?
          </button>
          {showHelpOptions ? (
            <div className="footer-help-modal" role="dialog" aria-modal="true" aria-label="Need help options">
              <button
                className="footer-help-modal__backdrop"
                type="button"
                aria-label="Close help options"
                onClick={() => setShowHelpOptions(false)}
              />
              <div className="footer-help-modal__panel">
                <div className="footer-help-modal__header">
                  <h2>Need Help?</h2>
                  <button
                    className="footer-help-modal__close"
                    type="button"
                    aria-label="Close help options"
                    onClick={() => setShowHelpOptions(false)}
                  >
                    ×
                  </button>
                </div>
                <div className="footer-help-modal__links">
                  <Link to="/help?section=privacy" onClick={() => setShowHelpOptions(false)}>
                    Privacy
                  </Link>
                  <Link to="/help?section=terms" onClick={() => setShowHelpOptions(false)}>
                    Terms
                  </Link>
                  <Link to="/ping" onClick={() => setShowHelpOptions(false)}>
                    Ping Us
                  </Link>
                </div>
              </div>
            </div>
          ) : null}
        </>
      ) : null}
    </footer>
  );
}
