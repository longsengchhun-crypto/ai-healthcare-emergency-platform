package com.healthresponse.platform.common;

import java.time.Instant;
import java.util.Map;

public record ApiError(String code, String message, int status, Instant timestamp, Map<String, String> fields) {
    public static ApiError of(int status, String code, String message) {
        return new ApiError(code, message, status, Instant.now(), null);
    }
}
