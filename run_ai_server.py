#!/usr/bin/env python3
"""启动 AI Native 敌人决策服务（FastAPI）。"""

import os
from pathlib import Path

import uvicorn
from dotenv import load_dotenv

ENV_PATH = Path(__file__).parent / ".env"
if ENV_PATH.exists():
    load_dotenv(ENV_PATH, override=True)

HOST = os.getenv("AI_SERVER_HOST", "127.0.0.1")
PORT = int(os.getenv("AI_SERVER_PORT", "8000"))

if __name__ == "__main__":
    uvicorn.run("src.server.api:app", host=HOST, port=PORT, reload=False)
