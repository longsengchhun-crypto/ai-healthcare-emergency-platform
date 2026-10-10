package com.healthresponse.platform.ai;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.ConcurrentLinkedDeque;
import java.util.function.Function;

/** Test double for the provider boundary: replays queued answers/failures and records every request it received. */
public class ScriptedLlm implements LlmClient {
    private final ConcurrentLinkedDeque<Object> script = new ConcurrentLinkedDeque<>();
    public final List<Request> seen = new ArrayList<>();
    public Function<Request, String> fallback;

    public void reset() {
        script.clear();
        seen.clear();
        fallback = null;
    }

    public void answer(String json) { script.add(json); }

    public void fail(LlmException.Kind kind) { script.add(new LlmException(kind, "scripted " + kind)); }

    @Override
    public synchronized String complete(Request request) {
        seen.add(request);
        Object next = script.poll();
        if (next == null) {
            if (fallback != null) return fallback.apply(request);
            throw new LlmException(LlmException.Kind.UNAVAILABLE, "no scripted answer");
        }
        if (next instanceof LlmException e) throw e;
        return (String) next;
    }
}
