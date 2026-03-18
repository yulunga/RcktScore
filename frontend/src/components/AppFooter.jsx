import React from "react";
import packageJson from "../../package.json";

const APP_VERSION = `v${packageJson.version}`;
const BUILD_ID = import.meta.env.VITE_BUILD_ID || "local";

export default function AppFooter() {
  return (
    <footer className="app-footer">
      <span>{`RcktScore ${APP_VERSION} • build ${BUILD_ID}`}</span>
    </footer>
  );
}
