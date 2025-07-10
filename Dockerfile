FROM openjdk:17-jdk-slim
WORKDIR /app
COPY target/demo-0.0.1-SNAPSHOT.jar app.jar

# Health check configured for port 7070
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
  CMD curl --fail http://localhost:7070/health || exit 1

EXPOSE 7070
ENTRYPOINT ["java", "-jar", "app.jar"]

