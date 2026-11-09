import React from "react";

export default function RootAdminSwitch({ label, children, checked, disabled, onChange }) {
  return (
    <label className={`root-admin-switch${disabled ? " match-option-switch--disabled" : ""}`}>
      {children}
      <span className="match-option-switch__control">
        <input type="checkbox" role="switch" aria-label={label} checked={checked} disabled={disabled} onChange={onChange} />
        <span className="match-option-switch__track" aria-hidden="true"><span /></span>
      </span>
    </label>
  );
}
