export const PLAYER_SHIRT_COLORS = [
  { value: "navy", label: "Navy", background: "#123c69", foreground: "#fff", border: "#123c69" },
  { value: "blue", label: "Blue", background: "#1274d0", foreground: "#fff", border: "#1274d0" },
  { value: "red", label: "Red", background: "#d64545", foreground: "#fff", border: "#d64545" },
  { value: "green", label: "Green", background: "#2f855a", foreground: "#fff", border: "#2f855a" },
  { value: "black", label: "Black", background: "#1f2933", foreground: "#fff", border: "#1f2933" },
  { value: "white", label: "White", background: "#fff", foreground: "#102a43", border: "#bcccdc" },
  { value: "yellow", label: "Yellow", background: "#f7d154", foreground: "#102a43", border: "#e3b924" },
  { value: "orange", label: "Orange", background: "#d9822b", foreground: "#fff", border: "#d9822b" },
  { value: "purple", label: "Purple", background: "#7c3aed", foreground: "#fff", border: "#7c3aed" },
  { value: "pink", label: "Pink", background: "#d9468f", foreground: "#fff", border: "#d9468f" },
];

export const DEFAULT_PLAYER_SHIRT_COLORS = {
  player1: "navy",
  player2: "white",
};

export function getPlayerShirtColor(value) {
  return PLAYER_SHIRT_COLORS.find((color) => color.value === value) || PLAYER_SHIRT_COLORS[0];
}
