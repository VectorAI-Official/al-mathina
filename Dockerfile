FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for better caching
COPY Backend/requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy backend code
COPY Backend/ .

# Expose port
EXPOSE 8080

# Run the application
CMD ["python", "-m", "uvicorn", "main_production:app", "--host", "0.0.0.0", "--port", "8080"]
