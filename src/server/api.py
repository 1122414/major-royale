"""AI Native 敌人决策服务。

接收战斗状态，返回结构化 JSON 决策。
AI 调用失败时自动使用规则兜底。
"""

import os
from typing import Any

from fastapi import FastAPI
from pydantic import BaseModel, Field

app = FastAPI(title="专业大逃杀 AI 决策服务", version="0.1.0")


class DecisionRequest(BaseModel):
    enemy: str
    player_major: str
    player_hp: int
    player_spirit: int
    visible_player_status: list[str] = Field(default_factory=list)
    last_player_actions: list[str] = Field(default_factory=list)
    allowed_actions: list[str] = Field(default_factory=list)


class DecisionResponse(BaseModel):
    action_id: str
    intent_text: str
    ending_flag: str | None = None


class HealthResponse(BaseModel):
    status: str
    version: str


@app.get("/health", response_model=HealthResponse)
async def health() -> dict[str, Any]:
    return {"status": "ok", "version": "0.1.0"}


@app.post("/decide", response_model=DecisionResponse)
async def decide(request: DecisionRequest) -> DecisionResponse:
    """返回敌人下一步行动决策。"""
    # TODO: 阶段 8 接入真实 LLM 调用与规则兜底
    if request.allowed_actions:
        action = request.allowed_actions[0]
    else:
        action = "attack"
    return DecisionResponse(
        action_id=action,
        intent_text=f"敌人准备使用 {action}。",
        ending_flag=None,
    )
