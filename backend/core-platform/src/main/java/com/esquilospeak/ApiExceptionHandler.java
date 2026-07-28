package com.esquilospeak;

import jakarta.validation.ConstraintViolationException;
import java.net.URI;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

@RestControllerAdvice
final class ApiExceptionHandler {

    @ExceptionHandler(ApiException.class)
    ProblemDetail handleApiException(ApiException exception) {
        return problem(
                exception.status(),
                exception.code(),
                exception.getMessage(),
                exception.retryable(),
                exception.violations());
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    ProblemDetail handleInvalidBody(MethodArgumentNotValidException exception) {
        List<ApiException.Violation> violations = exception.getBindingResult().getFieldErrors().stream()
                .map(error -> new ApiException.Violation(
                        error.getField(),
                        error.getCode() == null ? "INVALID" : error.getCode().toUpperCase()))
                .toList();
        return problem(
                HttpStatus.BAD_REQUEST,
                "INVALID_REQUEST",
                "The request body is invalid.",
                false,
                violations);
    }

    @ExceptionHandler(ConstraintViolationException.class)
    ProblemDetail handleConstraintViolation(ConstraintViolationException exception) {
        List<ApiException.Violation> violations = exception.getConstraintViolations().stream()
                .map(violation -> new ApiException.Violation(
                        violation.getPropertyPath().toString(), "INVALID"))
                .toList();
        return problem(
                HttpStatus.BAD_REQUEST,
                "INVALID_REQUEST",
                "The request parameters are invalid.",
                false,
                violations);
    }

    private ProblemDetail problem(
            HttpStatus status,
            String code,
            String detail,
            boolean retryable,
            List<ApiException.Violation> violations) {
        ProblemDetail problem = ProblemDetail.forStatusAndDetail(status, detail);
        problem.setType(URI.create("https://api.esquilospeak.com/problems/" + code.toLowerCase()));
        problem.setTitle(status.getReasonPhrase());
        problem.setProperty("code", code);
        problem.setProperty("traceId", UUID.randomUUID().toString());
        problem.setProperty("retryable", retryable);
        if (!violations.isEmpty()) {
            problem.setProperty("violations", violations);
        }
        return problem;
    }
}
