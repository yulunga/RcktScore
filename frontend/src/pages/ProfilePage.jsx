import React, { useCallback, useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";

import AppFooter from "../components/AppFooter";
import ClubPageHeader from "../components/ClubPageHeader";
import { COUNTRIES } from "../constants/countries";
import { useAuth } from "../hooks/useAuth";
import { getOrganizationSettings, updatePersonalProfile } from "../services/api";

const EMPTY_PROFILE = {
  email: "",
  first_name: "",
  surname: "",
  telephone: "",
  city_location: "",
  country: "",
};

function findSignedInUser(settings, username) {
  const normalizedUsername = String(username || "").trim().toLowerCase();
  return (settings?.users || []).find(
    (user) => String(user?.username || user?.clubusername || "").trim().toLowerCase() === normalizedUsername,
  ) || null;
}

function profileFromUser(user, session) {
  return {
    email: user?.username || user?.clubusername || session?.username || "",
    first_name: user?.first_name || session?.first_name || "",
    surname: user?.surname || session?.surname || "",
    telephone: user?.telephone || session?.telephone || "",
    city_location: user?.city_location || session?.city_location || "",
    country: user?.country || session?.country || "",
  };
}

export default function ProfilePage() {
  const navigate = useNavigate();
  const { session, setSession, logout } = useAuth();
  const [profile, setProfile] = useState(EMPTY_PROFILE);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState("");
  const [error, setError] = useState("");
  const organizationId = session?.organization_id;

  const loadProfile = useCallback(async () => {
    if (!organizationId) {
      setLoading(false);
      return;
    }

    setLoading(true);
    setError("");
    try {
      const response = await getOrganizationSettings(organizationId);
      const settings = response?.organizationSettings || response;
      setProfile(profileFromUser(findSignedInUser(settings, session?.username), session));
    } catch (requestError) {
      setError(requestError.message || "Failed to load your profile.");
    } finally {
      setLoading(false);
    }
  }, [organizationId, session]);

  useEffect(() => {
    loadProfile();
  }, [loadProfile]);

  function updateField(field, value) {
    setProfile((current) => ({ ...current, [field]: value }));
  }

  async function handleSubmit(event) {
    event.preventDefault();
    setSaving(true);
    setMessage("");
    setError("");
    try {
      const nextEmail = profile.email.trim().toLowerCase();
      const emailChanged = nextEmail !== String(session?.username || "").trim().toLowerCase();
      const response = await updatePersonalProfile(organizationId, {
        ...profile,
        email: nextEmail,
      });
      if (emailChanged) {
        window.sessionStorage.setItem(
          "rcktscore.profile-message",
          `Email updated. Sign in again using ${nextEmail}.`,
        );
        logout();
        navigate("/", { replace: true });
        return;
      }
      const settings = response?.organizationSettings || response;
      const refreshedProfile = profileFromUser(findSignedInUser(settings, nextEmail), {
        ...session,
        ...profile,
      });
      setProfile(refreshedProfile);
      setSession({ ...session, ...refreshedProfile });
      setMessage("Your profile has been updated.");
    } catch (requestError) {
      setError(requestError.message || "Failed to update your profile.");
    } finally {
      setSaving(false);
    }
  }

  return (
    <main className="page-shell stack">
      <ClubPageHeader />

      <section className="panel stack profile-page-panel">
        <div className="panel-heading">
          <h2>Your Profile</h2>
          <p className="helper-text">Update the personal details attached to your HitnScore account.</p>
        </div>

        {loading ? <div className="notice">Loading your profile...</div> : null}
        {message ? <div className="notice settings-success">{message}</div> : null}
        {error ? <div className="notice error">{error}</div> : null}

        {!loading ? (
          <form className="stack" onSubmit={handleSubmit}>
            <div className="field-grid settings-profile-grid">
              <div className="field settings-profile-field--solo">
                <label htmlFor="profile_email">Email / Username</label>
                <input
                  autoComplete="email"
                  className="settings-input-compact"
                  id="profile_email"
                  required
                  type="email"
                  value={profile.email}
                  onChange={(event) => updateField("email", event.target.value)}
                />
              </div>
              <div className="field">
                <label htmlFor="profile_first_name">First name</label>
                <input
                  autoComplete="given-name"
                  id="profile_first_name"
                  value={profile.first_name}
                  onChange={(event) => updateField("first_name", event.target.value)}
                />
              </div>
              <div className="field">
                <label htmlFor="profile_surname">Surname</label>
                <input
                  autoComplete="family-name"
                  id="profile_surname"
                  value={profile.surname}
                  onChange={(event) => updateField("surname", event.target.value)}
                />
              </div>
              <div className="field">
                <label htmlFor="profile_telephone">Telephone</label>
                <input
                  autoComplete="tel"
                  id="profile_telephone"
                  type="tel"
                  value={profile.telephone}
                  onChange={(event) => updateField("telephone", event.target.value)}
                />
              </div>
              <div className="field">
                <label htmlFor="profile_city_location">City / Location</label>
                <input
                  autoComplete="address-level2"
                  id="profile_city_location"
                  value={profile.city_location}
                  onChange={(event) => updateField("city_location", event.target.value)}
                />
              </div>
              <div className="field settings-profile-field--solo">
                <label htmlFor="profile_country">Country</label>
                <select
                  autoComplete="country-name"
                  id="profile_country"
                  value={profile.country}
                  onChange={(event) => updateField("country", event.target.value)}
                >
                  <option value="">Select a country</option>
                  {COUNTRIES.map((country) => <option key={country} value={country}>{country}</option>)}
                </select>
              </div>
            </div>
            <div className="button-row">
              <button disabled={saving} type="submit">
                {saving ? "Saving..." : "Save Profile"}
              </button>
            </div>
          </form>
        ) : null}
      </section>

      <AppFooter />
    </main>
  );
}
