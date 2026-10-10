# syntax=docker/dockerfile:1
FROM maven:3.9.9-eclipse-temurin-21 AS build
WORKDIR /build
COPY pom.xml .
RUN mvn -B -q dependency:go-offline
COPY src ./src
RUN mvn -B -q -DskipTests package

FROM eclipse-temurin:21-jre
RUN useradd --system --uid 10001 appuser && mkdir -p /data/private-documents && chown -R appuser /data
WORKDIR /app
COPY --from=build /build/target/platform-backend-1.0.0.jar app.jar
USER appuser
ENV STORAGE_ROOT=/data/private-documents
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s --retries=5 CMD curl -fsS http://localhost:8080/actuator/health/liveness || exit 1
ENTRYPOINT ["java", "-XX:MaxRAMPercentage=75", "-jar", "app.jar"]
