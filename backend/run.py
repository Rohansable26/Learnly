import uvicorn
from app.core.config import settings

if __name__ == "__main__":
    print(f"🚀 Starting Learnly AI Engine on http://{settings.HOST}:{settings.PORT}")
    print(f"📖 Interactive Swagger Docs available at: http://localhost:{settings.PORT}/docs")
    uvicorn.run("app.main:app", host=settings.HOST, port=settings.PORT, reload=settings.DEBUG)
