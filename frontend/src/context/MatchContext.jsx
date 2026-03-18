import React, {
  createContext,
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
} from "react";

import {
  endMatch as endMatchRequest,
  getScore,
  scorePoint as scorePointRequest,
  sendEventAction as sendEventActionRequest,
  startMatch as startMatchRequest,
  undoAction as undoActionRequest,
} from "../services/api";
import { createScoreSocket } from "../services/websocket";

export const MatchContext = createContext(null);

export function MatchProvider({ children }) {
  const [currentMatch, setCurrentMatch] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const socketRef = useRef(null);

  useEffect(() => {
    return () => {
      socketRef.current?.();
      socketRef.current = null;
    };
  }, []);

  const runMatchMutation = useCallback(async (request) => {
    setLoading(true);
    setError("");
    try {
      const response = await request();
      setCurrentMatch(response.match);
      return response.match;
    } catch (requestError) {
      setError(requestError.message);
      return null;
    } finally {
      setLoading(false);
    }
  }, []);

  const loadMatch = useCallback(async (matchId) => {
    if (!matchId) {
      return null;
    }

    setLoading(true);
    setError("");
    try {
      const payload = await getScore(matchId);
      setCurrentMatch(payload.match || payload);
      return payload.match || payload;
    } catch (requestError) {
      setError(requestError.message);
      return null;
    } finally {
      setLoading(false);
    }
  }, []);

  const startMatch = useCallback(async (payload) => {
    setLoading(true);
    setError("");
    try {
      const response = await startMatchRequest(payload);
      setCurrentMatch(response.match);
      return response.match;
    } catch (requestError) {
      setError(requestError.message);
      return null;
    } finally {
      setLoading(false);
    }
  }, []);

  const scorePoint = useCallback(async (matchId, scorer) => {
    return runMatchMutation(() =>
      scorePointRequest({ match_id: matchId, scorer }),
    );
  }, [runMatchMutation]);

  const sendEventAction = useCallback(async (matchId, actionType, payload = {}) => {
    return runMatchMutation(() =>
      sendEventActionRequest({
        match_id: matchId,
        action_type: actionType,
        ...payload,
      }),
    );
  }, [runMatchMutation]);

  const undoLastAction = useCallback(async (matchId) => {
    return runMatchMutation(() => undoActionRequest({ match_id: matchId }));
  }, [runMatchMutation]);

  const endMatch = useCallback(async (matchId, payload = {}) => {
    return runMatchMutation(() =>
      endMatchRequest({
        match_id: matchId,
        ...payload,
      }),
    );
  }, [runMatchMutation]);

  const connectRealtime = useCallback((matchId) => {
    if (socketRef.current) {
      socketRef.current();
    }

    socketRef.current = createScoreSocket(matchId, {
      onMessage(payload) {
        if (payload?.match) {
          setCurrentMatch(payload.match);
        }
      },
      onError() {
        setError("WebSocket connection failed.");
      },
    });

    return () => {
      socketRef.current?.();
      socketRef.current = null;
    };
  }, []);

  const contextValue = useMemo(
    () => ({
      currentMatch,
      loading,
      error,
      loadMatch,
      startMatch,
      scorePoint,
      sendEventAction,
      undoLastAction,
      endMatch,
      connectRealtime,
    }),
    [
      connectRealtime,
      currentMatch,
      error,
      loadMatch,
      loading,
      scorePoint,
      sendEventAction,
      startMatch,
      undoLastAction,
      endMatch,
    ],
  );

  return (
    <MatchContext.Provider value={contextValue}>
      {children}
    </MatchContext.Provider>
  );
}
