# Use Python 3.11 (avoids Python 3.13 SSL bug with MongoDB Atlas)
FROM python:3.11-slim

# Force unbuffered output for real-time logs
ENV PYTHONUNBUFFERED=1

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for better caching
COPY requirements-docker.txt requirements.txt

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Expose port
EXPOSE 8080

# Run the production server with hot-reload support
# RELOAD env var can be set to true for development, false for production
CMD sh -c 'if [ "$RELOAD" = "true" ]; then python -m uvicorn main_production:app --host 0.0.0.0 --port 8080 --reload; else python -m uvicorn main_production:app --host 0.0.0.0 --port 8080; fi'
