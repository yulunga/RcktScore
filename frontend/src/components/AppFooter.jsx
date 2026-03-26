import React from "react";
import packageJson from "../../package.json";
import { useAuth } from "../hooks/useAuth";

const APP_VERSION = `v${packageJson.version}`;
const BUILD_ID = import.meta.env.VITE_BUILD_ID || "local";
const FEEDBACK_EMAIL = "rcktinterest@ucingo.com";

export default function AppFooter() {
  const { isAuthenticated, session } = useAuth();
  const mailtoSubject = encodeURIComponent("RcktScore feedback");
  const mailtoBody = encodeURIComponent(
    `Please describe the issue or feedback.\n\nUser: ${session?.username || "unknown"}\nOrganisation: ${session?.organization_name || "unknown"}\nVersion: ${APP_VERSION}\nBuild: ${BUILD_ID}\n\nDetails:\n`,
  );

  return (
    <footer className="app-footer">
      <span>{`RcktScore ${APP_VERSION} • build ${BUILD_ID}`}</span>
      {isAuthenticated ? (
        <>
          <span className="app-footer__divider" aria-hidden="true">|</span>
          <a
            className="app-footer__link"
            href={`mailto:${FEEDBACK_EMAIL}?subject=${mailtoSubject}&body=${mailtoBody}`}
          >
            Feedback / Contact Us
          </a>
        </>
      ) : null}
    </footer>
  );
}
