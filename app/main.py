# app/main.py
import uvicorn

if __name__ == "__main__":
    uvicorn.run("adk_agent:app", host="0.0.0.0", port=int(os.environ.get("PORT", 8080)))
