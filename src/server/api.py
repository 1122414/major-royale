"""AI Native 敌人决策服务。

接收战斗状态，返回结构化 JSON 决策。
AI 调用失败时自动使用规则兜底。
"""

import json
import os
from typing import Any

import httpx
from fastapi import FastAPI
from pydantic import BaseModel, Field, ValidationError

from src.ai.fallback import rule_based_decision
from src.server.prompts import build_prompt

app = FastAPI(title="专业大逃杀 AI 决策服务", version="0.1.0")

AI_API_KEY = os.getenv("AI_API_KEY", "")
AI_BASE_URL = os.getenv("AI_BASE_URL", "https://api.openai.com/v1")
AI_MODEL = os.getenv("AI_MODEL", "gpt-4o-mini")
AI_TEMPERATURE = float(os.getenv("AI_TEMPERATURE", "0.7"))
AI_MAX_TOKENS = int(os.getenv("AI_MAX_TOKENS", "256"))
AI_TIMEOUT = float(os.getenv("AI_TIMEOUT", "5"))
AI_DEBUG = os.getenv("AI_DEBUG", "false").lower() == "true"


class DecisionRequest(BaseModel):
    enemy: str
    player_major: str
    player_hp: int
    player_spirit: int
    visible_player_status: list[str] = Field(default_factory=list)
    last_player_actions: list[str] = Field(default_factory=list)
    allowed_actions: list[str] = Field(default_factory=list)
    prompt_key: str = Field(default="", description="提示词模板键")


class DecisionResponse(BaseModel):
    action_id: str
    intent_text: str
    ending_flag: str | None = None
    source: str = "llm"  ## llm 或 fallback


class HealthResponse(BaseModel):
    status: str
    version: str


@app.get("/health", response_model=HealthResponse)
async def health() -> dict[str, Any]:
    return {"status": "ok", "version": "0.1.0"}


@app.post("/decide", response_model=DecisionResponse)
async def decide(request: DecisionRequest) -> DecisionResponse:
    """返回敌人下一步行动决策。"""
    context = request.model_dump()
    prompt_key = request.prompt_key or _infer_prompt_key(request.enemy)

    if AI_DEBUG:
        print(f"[AI] prompt_key={prompt_key}, enemy={request.enemy}")

    # 无 API Key 时直接兜底
    if not AI_API_KEY or AI_API_KEY == "your_api_key_here":
        fallback = rule_based_decision(context)
        return DecisionResponse(
            action_id=fallback["action_id"],
            intent_text=fallback["intent_text"],
            ending_flag=fallback.get("ending_flag"),
            source="fallback",
        )

    try:
        llm_result = await _call_llm(context, prompt_key)
        return DecisionResponse(
            action_id=llm_result["action_id"],
            intent_text=llm_result["intent_text"],
            ending_flag=llm_result.get("ending_flag"),
            source="llm",
        )
    except Exception as e:
        if AI_DEBUG:
            print(f"[AI] LLM 调用失败，使用规则兜底: {e}")
        fallback = rule_based_decision(context)
        return DecisionResponse(
            action_id=fallback["action_id"],
            intent_text=fallback["intent_text"],
            ending_flag=fallback.get("ending_flag"),
            source="fallback",
        )


async def _call_llm(context: dict[str, Any], prompt_key: str) -> dict[str, Any]:
    """调用 LLM 并解析 JSON 输出。"""
    prompt = build_prompt(prompt_key, context)
    headers = {
        "Authorization": f"Bearer {AI_API_KEY}",
        "Content-Type": "application/json",
    }
    payload = {
        "model": AI_MODEL,
        "messages": [
            {"role": "system", "content": "你是一个游戏 AI 敌人决策器，只返回 JSON。"},
            {"role": "user", "content": prompt},
        ],
        "temperature": AI_TEMPERATURE,
        "max_tokens": AI_MAX_TOKENS,
    }

    async with httpx.AsyncClient(timeout=AI_TIMEOUT) as client:
        response = await client.post(f"{AI_BASE_URL}/chat/completions", headers=headers, json=payload)
        response.raise_for_status()
        data = response.json()
        content = data["choices"][0]["message"]["content"]

        # 尝试从文本中提取 JSON
        content = content.strip()
        if content.startswith("```"):
            content = content.strip("`")
            if content.lower().startswith("json"):
                content = content[4:].strip()

        result = json.loads(content)

        # 校验 action_id 合法
        action_id = result["action_id"]
        if action_id not in context.get("allowed_actions", []):
            raise ValueError(f"LLM 返回了不允许的行动: {action_id}")

        return result


def _infer_prompt_key(enemy_name: str) -> str:
    if "审稿人" in enemy_name or "reviewer" in enemy_name.lower():
        return "paper_reviewer"
    return "ai_interviewer"
