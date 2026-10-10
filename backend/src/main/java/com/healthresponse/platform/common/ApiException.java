package com.healthresponse.platform.common;

import org.springframework.http.HttpStatus;

/** Business-rule failure that maps to a structured HTTP error. Messages must never contain secrets or PHI. */
public class ApiException extends RuntimeException {
    private final HttpStatus status;
    private final String code;

    public ApiException(HttpStatus status, String code, String message) {
        super(message);
        this.status = status;
        this.code = code;
    }

    public HttpStatus status() { return status; }
    public String code() { return code; }

    public static ApiException notFound(String what) { return new ApiException(HttpStatus.NOT_FOUND, "NOT_FOUND", what + " not found"); }
    public static ApiException forbidden(String msg) { return new ApiException(HttpStatus.FORBIDDEN, "FORBIDDEN", msg); }
    public static ApiException conflict(String code, String msg) { return new ApiException(HttpStatus.CONFLICT, code, msg); }
    public static ApiException badRequest(String code, String msg) { return new ApiException(HttpStatus.BAD_REQUEST, code, msg); }
    public static ApiException unauthorized(String msg) { return new ApiException(HttpStatus.UNAUTHORIZED, "UNAUTHORIZED", msg); }
}
