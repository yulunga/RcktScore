import React from "react";
import ReactDOM from "react-dom/client";
import { BrowserRouter } from "react-router-dom";

import App from "./App";
import { AuthProvider } from "./context/AuthContext";
import { MatchProvider } from "./context/MatchContext";
import { RootAdminProvider } from "./context/RootAdminContext";
import "./styles.css";

ReactDOM.createRoot(document.getElementById("root")).render(
  <React.StrictMode>
    <BrowserRouter>
      <RootAdminProvider>
        <AuthProvider>
          <MatchProvider>
            <App />
          </MatchProvider>
        </AuthProvider>
      </RootAdminProvider>
    </BrowserRouter>
  </React.StrictMode>,
);
