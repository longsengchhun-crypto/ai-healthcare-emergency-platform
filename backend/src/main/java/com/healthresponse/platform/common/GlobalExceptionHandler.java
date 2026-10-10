package com.healthresponse.platform.common;

import jakarta.validation.ConstraintViolationException;
import java.util.LinkedHashMap;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.MissingServletRequestParameterException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;
import org.springframework.web.multipart.MaxUploadSizeExceededException;

@RestControllerAdvice
public class GlobalExceptionHandler {
    private static final Logger log = LoggerFactory.getLogger(GlobalExceptionHandler.class);

    @ExceptionHandler(ApiException.class)
    ResponseEntity<ApiError> api(ApiException e) {
        return ResponseEntity.status(e.status()).body(ApiError.of(e.status().value(), e.code(), e.getMessage()));
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    ResponseEntity<ApiError> validation(MethodArgumentNotValidException e) {
        Map<String, String> fields = new LinkedHashMap<>();
        e.getBindingResult().getFieldErrors().forEach(f -> fields.putIfAbsent(f.getField(), f.getDefaultMessage()));
        return ResponseEntity.unprocessableEntity()
                .body(new ApiError("VALIDATION_FAILED", "Request validation failed", 422, java.time.Instant.now(), fields));
    }

    @ExceptionHandler({ConstraintViolationException.class, HttpMessageNotReadableException.class,
            MissingServletRequestParameterException.class, MethodArgumentTypeMismatchException.class})
    ResponseEntity<ApiError> badInput(Exception e) {
        return ResponseEntity.badRequest().body(ApiError.of(400, "BAD_REQUEST", "Malformed or invalid request"));
    }

    @ExceptionHandler(MaxUploadSizeExceededException.class)
    ResponseEntity<ApiError> tooLarge(Exception e) {
        return ResponseEntity.status(HttpStatus.PAYLOAD_TOO_LARGE).body(ApiError.of(413, "FILE_TOO_LARGE", "File exceeds the 10 MB limit"));
    }

    @ExceptionHandler(AccessDeniedException.class)
    ResponseEntity<ApiError> denied(AccessDeniedException e) {
        return ResponseEntity.status(HttpStatus.FORBIDDEN).body(ApiError.of(403, "FORBIDDEN", "You do not have permission to perform this action"));
    }

    @ExceptionHandler(DuplicateKeyException.class)
    ResponseEntity<ApiError> duplicate(DuplicateKeyException e) {
        return ResponseEntity.status(HttpStatus.CONFLICT).body(ApiError.of(409, "CONFLICT", "The request conflicts with existing data"));
    }

    @ExceptionHandler(Exception.class)
    ResponseEntity<ApiError> unexpected(Exception e) {
        log.error("Unhandled exception", e);
        return ResponseEntity.internalServerError().body(ApiError.of(500, "INTERNAL_ERROR", "An unexpected error occurred"));
    }
}
