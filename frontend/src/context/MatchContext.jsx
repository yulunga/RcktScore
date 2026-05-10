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
  startScheduledMatch as startScheduledMatchRequest,
  startMatch as startMatchRequest,
  undoAction as undoActionRequest,
} from "../services/api";
import { createScoreSocket } from "../services/websocket";

export const MatchContext = createContext(null);

function mergeMatchPayload(previousMatch, nextMatch) {
  if (!nextMatch) {
    return nextMatch;
  }

  return {
    ...previousMatch,
    ...nextMatch,
    court_display_code: nextMatch.court_display_code || previousMatch?.court_display_code || "",
  };
}

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
      setCurrentMatch((current) => mergeMatchPayload(current, response.match));
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
      const nextMatch = payload.match || payload;
      setCurrentMatch((current) => mergeMatchPayload(current, nextMatch));
      return nextMatch;
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
      setCurrentMatch((current) => mergeMatchPayload(current, response.match));
      return response;
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

  const startScheduledMatch = useCallback(async (matchId) => {
    setLoading(true);
    setError("");
    try {
      const response = await startScheduledMatchRequest({ match_id: matchId });
      setCurrentMatch((current) => mergeMatchPayload(current, response.match));
      return response.match;
    } catch (requestError) {
      setError(requestError.message);
      return null;
    } finally {
      setLoading(false);
    }
  }, []);

  const connectRealtime = useCallback((matchId) => {
    if (socketRef.current) {
      socketRef.current();
    }

    socketRef.current = createScoreSocket(matchId, {
      onMessage(payload) {
        if (payload?.match) {
          setCurrentMatch((current) => mergeMatchPayload(current, payload.match));
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
      startScheduledMatch,
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
      startScheduledMatch,
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
