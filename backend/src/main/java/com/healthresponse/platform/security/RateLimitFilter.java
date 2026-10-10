package com.healthresponse.platform.security;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.healthresponse.platform.common.ApiError;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.time.Instant;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

/**
 * Fixed-window, per-IP limiter for the unauthenticated auth endpoints.
 * In-memory: correct for a single instance; swap for a Redis-backed limiter when running several instances.
 */
@Component
public class RateLimitFilter extends OncePerRequestFilter {
    private record Window(long minute, int count) {}

    private final ConcurrentHashMap<String, Window> windows = new ConcurrentHashMap<>();
    private final int limit;
    private final ObjectMapper mapper;

    public RateLimitFilter(AppProperties props, ObjectMapper mapper) {
        this.limit = props.rateLimit().authPerMinute();
        this.mapper = mapper;
    }

    @Override
    protected boolean shouldNotFilter(HttpServletRequest req) {
        String p = req.getRequestURI();
        return !(p.startsWith("/api/v1/auth/login") || p.startsWith("/api/v1/auth/register")
                || p.startsWith("/api/v1/auth/password-reset") || p.startsWith("/api/v1/auth/refresh"));
    }

    @Override
    protected void doFilterInternal(HttpServletRequest req, HttpServletResponse res, FilterChain chain)
            throws ServletException, IOException {
        long minute = Instant.now().getEpochSecond() / 60;
        Window w = windows.merge(req.getRemoteAddr(), new Window(minute, 1),
                (old, fresh) -> old.minute() == minute ? new Window(minute, old.count() + 1) : fresh);
        if (w.count() > limit) {
            res.setStatus(429);
            res.setContentType("application/json");
            res.setHeader("Retry-After", "60");
            mapper.writeValue(res.getOutputStream(),
                    ApiError.of(429, "RATE_LIMITED", "Too many requests. Please try again shortly."));
            return;
        }
        chain.doFilter(req, res);
    }
}
