import React from "react";
import { Link } from "react-router-dom";
import packageJson from "../../package.json";
import { useAuth } from "../hooks/useAuth";

const APP_VERSION = `v${packageJson.version}`;
const BUILD_ID = import.meta.env.VITE_BUILD_ID || "local";
const DISPLAY_BUILD_ID = String(BUILD_ID).replace(/^0+(?=\d)/, "");

export default function AppFooter() {
  const { isAuthenticated } = useAuth();

  return (
    <footer className="app-footer">
      <span>{`RcktScore ${APP_VERSION} • build ${DISPLAY_BUILD_ID}`}</span>
      {isAuthenticated ? (
        <>
          <span className="app-footer__divider" aria-hidden="true">|</span>
          <Link className="app-footer__link" to="/ping">
            Ping Us
          </Link>
        </>
      ) : null}
    </footer>
  );
}
