const WEBSOCKET_URL = import.meta.env.VITE_WEBSOCKET_URL;

export function createScoreSocket(matchId, callbacks = {}) {
  if (!WEBSOCKET_URL || !matchId) {
    return () => {};
  }

  const socket = new WebSocket(`${WEBSOCKET_URL}?match_id=${matchId}`);

  socket.onopen = () => callbacks.onOpen?.();
  socket.onclose = () => callbacks.onClose?.();
  socket.onerror = (error) => callbacks.onError?.(error);
  socket.onmessage = (message) => {
    try {
      callbacks.onMessage?.(JSON.parse(message.data));
    } catch {
      callbacks.onMessage?.(message.data);
    }
  };

  return () => socket.close();
}
