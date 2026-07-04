"""
Unified AI provider adapters for the Coach feature.
Supports: OpenAI, Claude, Gemini, Ollama, HuggingFace, Custom (OpenAI-compatible).
All providers implement async streaming via chat_stream().
"""

import json
import logging
from abc import ABC, abstractmethod
from typing import AsyncGenerator, Optional

import httpx

logger = logging.getLogger("fitness.ai")


class AIProvider(ABC):
    """Base class for AI provider adapters."""

    def __init__(self, api_key: Optional[str] = None, model: str = "", endpoint: Optional[str] = None):
        self.api_key = api_key
        self.model = model
        self.endpoint = endpoint

    @abstractmethod
    async def chat_stream(
        self, messages: list[dict], system_prompt: str
    ) -> AsyncGenerator[str, None]:
        """Stream chat completion tokens. Yields text chunks."""
        ...  # pragma: no cover

    async def validate(self) -> tuple[bool, str]:
        """Test that the provider is reachable and the key is valid."""
        try:
            chunks = []
            async for chunk in self.chat_stream(
                [{"role": "user", "content": "Say 'ok' and nothing else."}],
                system_prompt="You are a test assistant.",
            ):
                chunks.append(chunk)
                if len(chunks) > 5:
                    break
            return True, "Connection successful"
        except Exception as e:
            return False, str(e)


class OpenAIProvider(AIProvider):
    """OpenAI GPT models (gpt-4o, gpt-4o-mini, etc.)."""

    DEFAULT_ENDPOINT = "https://api.openai.com/v1/chat/completions"

    async def chat_stream(
        self, messages: list[dict], system_prompt: str
    ) -> AsyncGenerator[str, None]:
        url = self.endpoint or self.DEFAULT_ENDPOINT
        full_messages = [{"role": "system", "content": system_prompt}] + messages

        async with httpx.AsyncClient(timeout=120) as client:
            async with client.stream(
                "POST",
                url,
                headers={
                    "Authorization": f"Bearer {self.api_key}",
                    "Content-Type": "application/json",
                },
                json={
                    "model": self.model or "gpt-4o",
                    "messages": full_messages,
                    "stream": True,
                    "temperature": 0.7,
                    "max_tokens": 2048,
                },
            ) as resp:
                resp.raise_for_status()
                async for line in resp.aiter_lines():
                    if not line.startswith("data: "):
                        continue
                    data = line[6:]
                    if data == "[DONE]":
                        break
                    try:
                        chunk = json.loads(data)
                        delta = chunk["choices"][0].get("delta", {})
                        if "content" in delta and delta["content"]:
                            yield delta["content"]
                    except (json.JSONDecodeError, KeyError, IndexError):
                        continue


class ClaudeProvider(AIProvider):
    """Anthropic Claude models (claude-sonnet, claude-haiku, etc.)."""

    DEFAULT_ENDPOINT = "https://api.anthropic.com/v1/messages"

    async def chat_stream(
        self, messages: list[dict], system_prompt: str
    ) -> AsyncGenerator[str, None]:
        url = self.endpoint or self.DEFAULT_ENDPOINT

        async with httpx.AsyncClient(timeout=120) as client:
            async with client.stream(
                "POST",
                url,
                headers={
                    "x-api-key": self.api_key,
                    "anthropic-version": "2023-06-01",
                    "Content-Type": "application/json",
                },
                json={
                    "model": self.model or "claude-sonnet-4-20250514",
                    "system": system_prompt,
                    "messages": messages,
                    "stream": True,
                    "max_tokens": 2048,
                    "temperature": 0.7,
                },
            ) as resp:
                resp.raise_for_status()
                async for line in resp.aiter_lines():
                    if not line.startswith("data: "):
                        continue
                    try:
                        chunk = json.loads(line[6:])
                        if chunk.get("type") == "content_block_delta":
                            text = chunk.get("delta", {}).get("text", "")
                            if text:
                                yield text
                    except (json.JSONDecodeError, KeyError):
                        continue


class GeminiProvider(AIProvider):
    """Google Gemini models (gemini-pro, gemini-flash, etc.)."""

    DEFAULT_ENDPOINT = "https://generativelanguage.googleapis.com/v1beta/models"

    async def chat_stream(
        self, messages: list[dict], system_prompt: str
    ) -> AsyncGenerator[str, None]:
        model = self.model or "gemini-2.0-flash"
        base = self.endpoint or self.DEFAULT_ENDPOINT
        url = f"{base}/{model}:streamGenerateContent?alt=sse"

        # Convert OpenAI-style messages to Gemini format
        contents = []
        for msg in messages:
            role = "model" if msg["role"] == "assistant" else "user"
            contents.append({"role": role, "parts": [{"text": msg["content"]}]})

        async with httpx.AsyncClient(timeout=120) as client:
            async with client.stream(
                "POST",
                url,
                headers={
                    "Content-Type": "application/json",
                    "x-goog-api-key": self.api_key or "",
                },
                json={
                    "contents": contents,
                    "systemInstruction": {"parts": [{"text": system_prompt}]},
                    "generationConfig": {
                        "temperature": 0.7,
                        "maxOutputTokens": 2048,
                    },
                },
            ) as resp:
                resp.raise_for_status()
                async for line in resp.aiter_lines():
                    if not line.startswith("data: "):
                        continue
                    try:
                        chunk = json.loads(line[6:])
                        for candidate in chunk.get("candidates", []):
                            for part in candidate.get("content", {}).get("parts", []):
                                if "text" in part and part["text"]:
                                    yield part["text"]
                    except (json.JSONDecodeError, KeyError):
                        continue


class OllamaProvider(AIProvider):
    """Local Ollama server — runs any GGUF model, no API key needed."""

    DEFAULT_ENDPOINT = "http://localhost:11434"

    async def chat_stream(
        self, messages: list[dict], system_prompt: str
    ) -> AsyncGenerator[str, None]:
        base = self.endpoint or self.DEFAULT_ENDPOINT
        url = f"{base}/api/chat"
        full_messages = [{"role": "system", "content": system_prompt}] + messages

        async with httpx.AsyncClient(timeout=300) as client:
            async with client.stream(
                "POST",
                url,
                json={
                    "model": self.model or "llama3.1:8b",
                    "messages": full_messages,
                    "stream": True,
                    "options": {"temperature": 0.7, "num_predict": 2048},
                },
            ) as resp:
                resp.raise_for_status()
                async for line in resp.aiter_lines():
                    if not line:
                        continue
                    try:
                        chunk = json.loads(line)
                        content = chunk.get("message", {}).get("content", "")
                        if content:
                            yield content
                        if chunk.get("done"):
                            break
                    except json.JSONDecodeError:
                        continue


class HuggingFaceProvider(AIProvider):
    """HuggingFace Inference API — point to any model repo."""

    DEFAULT_ENDPOINT = "https://api-inference.huggingface.co/models"

    async def chat_stream(
        self, messages: list[dict], system_prompt: str
    ) -> AsyncGenerator[str, None]:
        model = self.model or "meta-llama/Llama-3.1-8B-Instruct"
        base = self.endpoint or self.DEFAULT_ENDPOINT
        url = f"{base}/{model}/v1/chat/completions"
        full_messages = [{"role": "system", "content": system_prompt}] + messages

        async with httpx.AsyncClient(timeout=120) as client:
            async with client.stream(
                "POST",
                url,
                headers={
                    "Authorization": f"Bearer {self.api_key}",
                    "Content-Type": "application/json",
                },
                json={
                    "model": model,
                    "messages": full_messages,
                    "stream": True,
                    "temperature": 0.7,
                    "max_tokens": 2048,
                },
            ) as resp:
                resp.raise_for_status()
                async for line in resp.aiter_lines():
                    if not line.startswith("data: "):
                        continue
                    data = line[6:]
                    if data == "[DONE]":
                        break
                    try:
                        chunk = json.loads(data)
                        delta = chunk["choices"][0].get("delta", {})
                        if "content" in delta and delta["content"]:
                            yield delta["content"]
                    except (json.JSONDecodeError, KeyError, IndexError):
                        continue


class CustomProvider(AIProvider):
    """Any OpenAI-compatible endpoint (OpenRouter, Together, Groq, vLLM, LM Studio)."""

    async def chat_stream(
        self, messages: list[dict], system_prompt: str
    ) -> AsyncGenerator[str, None]:
        if not self.endpoint:
            raise ValueError("Custom provider requires an endpoint URL")

        url = self.endpoint.rstrip("/")
        if not url.endswith("/chat/completions"):
            url = f"{url}/v1/chat/completions"

        full_messages = [{"role": "system", "content": system_prompt}] + messages
        headers = {"Content-Type": "application/json"}
        if self.api_key:
            headers["Authorization"] = f"Bearer {self.api_key}"

        async with httpx.AsyncClient(timeout=120) as client:
            async with client.stream(
                "POST",
                url,
                headers=headers,
                json={
                    "model": self.model or "default",
                    "messages": full_messages,
                    "stream": True,
                    "temperature": 0.7,
                    "max_tokens": 2048,
                },
            ) as resp:
                resp.raise_for_status()
                async for line in resp.aiter_lines():
                    if not line.startswith("data: "):
                        continue
                    data = line[6:]
                    if data == "[DONE]":
                        break
                    try:
                        chunk = json.loads(data)
                        delta = chunk["choices"][0].get("delta", {})
                        if "content" in delta and delta["content"]:
                            yield delta["content"]
                    except (json.JSONDecodeError, KeyError, IndexError):
                        continue


# Provider registry
PROVIDERS = {
    "openai": OpenAIProvider,
    "claude": ClaudeProvider,
    "gemini": GeminiProvider,
    "ollama": OllamaProvider,
    "huggingface": HuggingFaceProvider,
    "custom": CustomProvider,
}

# Default models per provider
DEFAULT_MODELS = {
    "openai": ["gpt-4o", "gpt-4o-mini", "gpt-4.1", "gpt-4.1-mini"],
    "claude": ["claude-sonnet-4-20250514", "claude-haiku-4-20250414", "claude-opus-4-20250514"],
    "gemini": ["gemini-2.0-flash", "gemini-2.5-pro", "gemini-2.5-flash"],
    "ollama": ["llama3.1:8b", "llama3.1:70b", "mistral:7b", "phi4:latest", "deepseek-r1:8b"],
    "huggingface": ["meta-llama/Llama-3.1-8B-Instruct", "mistralai/Mistral-7B-Instruct-v0.3"],
    "custom": [],
}


def get_provider(
    provider_name: str,
    api_key: Optional[str] = None,
    model: Optional[str] = None,
    endpoint: Optional[str] = None,
) -> AIProvider:
    """Factory: create a provider instance from settings."""
    cls = PROVIDERS.get(provider_name)
    if not cls:
        raise ValueError(f"Unknown provider: {provider_name}. Available: {list(PROVIDERS.keys())}")
    return cls(api_key=api_key, model=model or "", endpoint=endpoint)
