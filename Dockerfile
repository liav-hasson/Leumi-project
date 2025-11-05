FROM python:3.11-slim AS build-stage

WORKDIR /app

# Copy website source code and requirements.txt
COPY source_code/ /app/
COPY requirements.txt /app/

# Install dependencies to a local user directory
RUN pip install --no-cache-dir --user -r requirements.txt

# --- Final Stage ---
FROM python:3.11-slim AS final-stage

WORKDIR /app

# Add local user bin to PATH
ENV PATH=/root/.local/bin:$PATH

# Copy installed packages and app code from build stage
COPY --from=build-stage /root/.local /root/.local
COPY --from=build-stage /app /app

EXPOSE 5000

CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "3", "application:app"]