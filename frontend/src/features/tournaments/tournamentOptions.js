export const TOURNAMENT_SPORTS = [
  { value: "squash", label: "Squash" },
  { value: "racketball", label: "Racketball" },
  { value: "tennis", label: "Tennis" },
  { value: "padel", label: "Padel" },
];

export const TOURNAMENT_FORMATS = [
  { value: "knockout", label: "Knockout" },
  { value: "knockout_plate", label: "Knockout with Plate" },
  { value: "round_robin", label: "Round Robin" },
  { value: "monrad", label: "Monrad" },
];

export function optionLabel(options, value) {
  return options.find((option) => option.value === value)?.label || value;
}

