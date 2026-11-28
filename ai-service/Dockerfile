# Pinned by digest so a rebuild gives the same image.
FROM python:3.13-slim@sha256:168d3a5d10f2152f8e8d77b6843ac82c22a846cfefeef7afdf9aa630404e82a7
RUN useradd --system --uid 1001 app
WORKDIR /srv
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app app
USER app
EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
