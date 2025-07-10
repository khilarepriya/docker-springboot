FROM openjdk:17-jdk-slim
WORKDIR /app

# Copy any JAR from target/
COPY target/*.jar app.jar

EXPOSE 7070

HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
  CMD curl --fail http://localhost:7070/health || exit 1

ENTRYPOINT ["java", "-jar", "app.jar"]

