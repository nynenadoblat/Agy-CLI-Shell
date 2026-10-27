#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Antigravity Desktop GUI Launcher (Python Tkinter)
Графическая оболочка для запуска и взаимодействия с Antigravity CLI (agy.exe).
Использует только стандартную библиотеку Python (не требует сторонних pip-зависимостей).
Поддерживает управление сессиями, выбор и продолжение диалогов, поиск и предпросмотр.
"""

import os
import sys
import re
import json
import shutil
import datetime
import subprocess
import threading
import queue
import tkinter as tk
from tkinter import ttk, filedialog, messagebox, simpledialog


def find_agy_executable():
    """Поиск пути к agy.exe."""
    local_app_data = os.environ.get("LOCALAPPDATA", "")
    candidate = os.path.join(local_app_data, "agy", "bin", "agy.exe")
    if os.path.isfile(candidate):
        return candidate
    in_path = shutil.which("agy.exe") or shutil.which("agy")
    if in_path:
        return in_path
    return candidate


def get_session_meta_path():
    """Путь к файлу sessions_meta.json в папке лаунчера."""
    return os.path.join(os.path.dirname(os.path.abspath(__file__)), "sessions_meta.json")


def get_launcher_config_path():
    """Путь к файлу конфигурации launcher_config.json в папке лаунчера."""
    return os.path.join(os.path.dirname(os.path.abspath(__file__)), "launcher_config.json")


def load_launcher_config():
    """Чтение настроек лаунчера из launcher_config.json."""
    config_path = get_launcher_config_path()
    if os.path.isfile(config_path):
        try:
            with open(config_path, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            return {}
    return {}


def save_launcher_config(data):
    """Сохранение настроек лаунчера в launcher_config.json."""
    config_path = get_launcher_config_path()
    current = load_launcher_config()
    current.update(data)
    try:
        with open(config_path, "w", encoding="utf-8") as f:
            json.dump(current, f, ensure_ascii=False, indent=2)
    except Exception:
        pass


def save_session_metadata(conversation_id, workspace="", title=""):
    """Сохранение метаданных сессии в sessions_meta.json."""
    if not conversation_id:
        return
    meta_path = get_session_meta_path()
    data = {}
    if os.path.isfile(meta_path):
        try:
            with open(meta_path, "r", encoding="utf-8") as f:
                data = json.load(f)
        except Exception:
            data = {}

    existing = data.get(conversation_id, {})
    clean_title = title.split("\n")[0].strip() if title else f"Диалог {conversation_id}"
    if len(clean_title) > 120:
        clean_title = clean_title[:117] + "..."

    data[conversation_id] = {
        "workspace": workspace or existing.get("workspace", ""),
        "title": clean_title if (clean_title and clean_title != f"Диалог {conversation_id}") else existing.get("title", f"Диалог {conversation_id}"),
        "timestamp": int(datetime.datetime.now().timestamp() * 1000)
    }
    try:
        with open(meta_path, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
    except Exception:
        pass


def get_antigravity_conversations():
    """Сбор и структурирование списка всех разговоров Antigravity."""
    home_dir = os.path.expanduser("~")
    brain_dir = os.path.join(home_dir, ".gemini", "antigravity-cli", "brain")
    history_path = os.path.join(home_dir, ".gemini", "antigravity-cli", "history.jsonl")
    meta_path = get_session_meta_path()

    local_meta = {}
    if os.path.isfile(meta_path):
        try:
            with open(meta_path, "r", encoding="utf-8") as f:
                local_meta = json.load(f)
        except Exception:
            pass

    hist_map = {}
    if os.path.isfile(history_path):
        try:
            with open(history_path, "r", encoding="utf-8", errors="ignore") as f:
                for line in f:
                    line = line.strip()
                    if line:
                        try:
                            obj = json.loads(line)
                            cid = obj.get("conversationId")
                            ws = obj.get("workspace")
                            if cid and ws:
                                hist_map[cid] = ws
                        except Exception:
                            pass
        except Exception:
            pass

    conversations = []
    if os.path.isdir(brain_dir):
        try:
            for entry in os.scandir(brain_dir):
                if entry.is_dir():
                    cid = entry.name
                    tpath = os.path.join(entry.path, ".system_generated", "logs", "transcript.jsonl")
                    title = "Новый диалог"
                    workspace = ""
                    msg_count = 0
                    mtime = entry.stat().st_mtime

                    # 1. Из локального кэша
                    if cid in local_meta:
                        workspace = local_meta[cid].get("workspace", "")
                        title = local_meta[cid].get("title", "Новый диалог")

                    # 2. Из history.jsonl
                    if not workspace and cid in hist_map:
                        workspace = hist_map[cid]

                    # 3. Из transcript.jsonl
                    if os.path.isfile(tpath):
                        try:
                            with open(tpath, "r", encoding="utf-8", errors="ignore") as f:
                                line_num = 0
                                for line in f:
                                    line = line.strip()
                                    if not line:
                                        continue
                                    line_num += 1
                                    if line_num == 1 and title == "Новый диалог":
                                        try:
                                            step = json.loads(line)
                                            content = step.get("content", "")
                                            if "<USER_REQUEST>" in content:
                                                start = content.find("<USER_REQUEST>") + len("<USER_REQUEST>")
                                                end = content.find("</USER_REQUEST>")
                                                if end > start:
                                                    title = content[start:end].strip()
                                                else:
                                                    title = content[start:].strip()
                                            else:
                                                title = content.strip()
                                        except Exception:
                                            pass
                                    if not workspace and line_num < 15:
                                        import re
                                        m = re.search(r'(?i)(?<![A-Za-z0-9])([A-Za-z]:\\\\(?:[^"\'\r\n\\]+\\\\)*?IGROSTROY(?:\\\\([^\r\n"\'\\]+))?)', line)
                                        if m:
                                            workspace = m.group(1).replace("\\\\", "\\")
                                msg_count = line_num
                        except Exception:
                            pass

                    first_line_title = title.split("\n")[0].strip()
                    if len(first_line_title) > 75:
                        first_line_title = first_line_title[:72] + "..."

                    project_name = os.path.basename(workspace) if workspace else "—"
                    date_display = datetime.datetime.fromtimestamp(mtime).strftime("%d.%m.%Y %H:%M")

                    conversations.append({
                        "id": cid,
                        "short_id": cid[:8] if len(cid) > 8 else cid,
                        "title": first_line_title,
                        "full_title": title,
                        "workspace": workspace,
                        "project_name": project_name,
                        "date_display": date_display,
                        "last_modified": mtime,
                        "message_count": msg_count
                    })
        except Exception:
            pass

    conversations.sort(key=lambda x: x["last_modified"], reverse=True)
    return conversations


def get_model_context_limit(model_name: str) -> int:
    """Возвращает максимальный размер контекстного окна для указанной модели."""
    if not model_name:
        return 1048576
    m = model_name.lower()
    if "gemini" in m:
        return 1048576
    if "claude" in m:
        return 200000
    if "gpt-oss" in m:
        return 128000
    return 1048576


def format_token_count(tokens: int) -> str:
    """Форматирует количество токенов в компактную строку (128, 89.2k, 1.0M)."""
    if tokens < 1000:
        return str(tokens)
    if tokens < 1000000:
        val = round(tokens / 1000.0, 1)
        return f"{val:g}k"
    val_m = round(tokens / 1000000.0, 1)
    return f"{val_m:g}M"


def get_conversation_context_stats(conv_id: str, model_name: str = "gemini-3.8-flash-high") -> dict:
    """Считывает последние метрики токенов из транскрипта и рассчитывает заполненность контекста."""
    max_limit = get_model_context_limit(model_name)
    default_res = {
        "conversation_id": conv_id or "",
        "total_tokens": 0,
        "input_tokens": 0,
        "cache_tokens": 0,
        "output_tokens": 0,
        "max_limit": max_limit,
        "percent": 0.0,
        "formatted_total": "0",
        "formatted_max": format_token_count(max_limit),
        "formatted_in": "0",
        "formatted_cache": "0",
        "formatted_out": "0",
        "rem_tokens": max_limit,
        "formatted_rem": format_token_count(max_limit),
        "rem_percent": 100.0,
        "model_name": model_name,
        "display_text": f"🧠 Контекст: 0 / {format_token_count(max_limit)} (0%)",
        "color": "#4EC9B0",
    }
    if not conv_id:
        return default_res

    brain_dir = os.path.expanduser(r"~/.gemini/antigravity-cli/brain")
    transcript_path = os.path.join(brain_dir, conv_id, ".system_generated", "logs", "transcript.jsonl")
    if not os.path.isfile(transcript_path):
        alt = os.path.join(brain_dir, conv_id, "transcript.jsonl")
        if os.path.isfile(alt):
            transcript_path = alt
        else:
            return default_res

    try:
        file_size = os.path.getsize(transcript_path)
        if file_size == 0:
            return default_res

        read_size = min(file_size, 262144)
        with open(transcript_path, "rb") as f:
            f.seek(-read_size, os.SEEK_END)
            chunk = f.read().decode("utf-8", errors="replace")
        lines = chunk.splitlines()

        input_tokens = 0
        cache_tokens = 0
        output_tokens = 0
        found = False

        for l in reversed(lines):
            if l and '"PLANNER_RESPONSE"' in l:
                try:
                    parsed = json.loads(l)
                    if parsed.get("type") == "PLANNER_RESPONSE":
                        input_tokens = int(parsed.get("input_tokens") or 0)
                        cache_tokens = int(parsed.get("cache_read_tokens") or 0)
                        output_tokens = int(parsed.get("output_tokens") or 0)
                        found = True
                        break
                except Exception:
                    pass

        total_tokens = input_tokens + cache_tokens
        pct = round((total_tokens / float(max_limit)) * 100.0, 1) if max_limit > 0 else 0.0

        if pct >= 80.0:
            color = "#F85149"
        elif pct >= 60.0:
            color = "#E2C08D"
        else:
            color = "#4EC9B0"

        fmt_total = format_token_count(total_tokens)
        fmt_max = format_token_count(max_limit)
        fmt_in = format_token_count(input_tokens)
        fmt_cache = format_token_count(cache_tokens)
        fmt_out = format_token_count(output_tokens)
        rem_tokens = max(0, max_limit - total_tokens)
        fmt_rem = format_token_count(rem_tokens)
        rem_pct = round((rem_tokens / float(max_limit)) * 100.0, 1) if max_limit > 0 else 0.0

        return {
            "conversation_id": conv_id,
            "total_tokens": total_tokens,
            "input_tokens": input_tokens,
            "cache_tokens": cache_tokens,
            "output_tokens": output_tokens,
            "max_limit": max_limit,
            "percent": pct,
            "formatted_total": fmt_total,
            "formatted_max": fmt_max,
            "formatted_in": fmt_in,
            "formatted_cache": fmt_cache,
            "formatted_out": fmt_out,
            "rem_tokens": rem_tokens,
            "formatted_rem": fmt_rem,
            "rem_percent": rem_pct,
            "model_name": model_name,
            "display_text": f"🧠 Контекст: {fmt_total} / {fmt_max} ({pct}%)",
            "color": color,
        }
    except Exception:
        return default_res


def get_conversation_preview_text(conversation_id):
    """Формирование подробного текстового предпросмотра диалога."""
    home_dir = os.path.expanduser("~")
    tpath = os.path.join(home_dir, ".gemini", "antigravity-cli", "brain", conversation_id, ".system_generated", "logs", "transcript.jsonl")
    if not os.path.isfile(tpath):
        return "История диалога пуста или файл transcript.jsonl не найден."

    user_prompts = []
    agent_responses = []

    try:
        with open(tpath, "r", encoding="utf-8", errors="ignore") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    step = json.loads(line)
                    stype = step.get("type")
                    content = step.get("content", "")
                    if stype == "USER_INPUT" and content:
                        if "<USER_REQUEST>" in content:
                            start = content.find("<USER_REQUEST>") + len("<USER_REQUEST>")
                            end = content.find("</USER_REQUEST>")
                            if end > start:
                                content = content[start:end].strip()
                            else:
                                content = content[start:].strip()
                        user_prompts.append(content.strip())
                    elif stype == "PLANNER_RESPONSE" and content:
                        agent_responses.append(content.strip())
                except Exception:
                    pass
    except Exception:
        pass

    c_stats = get_conversation_context_stats(conversation_id)
    lines = [
        f"ID: {conversation_id}",
        f"Всего запросов пользователя: {len(user_prompts)}",
        f"Всего ответов агента: {len(agent_responses)}",
    ]
    if c_stats and c_stats["total_tokens"] > 0:
        pct = c_stats["percent"]
        bar_w = 20
        filled = min(bar_w, max(0, int(round((pct / 100.0) * bar_w))))
        unfilled = bar_w - filled
        uni_bar = "█" * filled + "░" * unfilled
        fmt_total = c_stats.get("formatted_total") or format_token_count(c_stats["total_tokens"])
        fmt_max = c_stats.get("formatted_max") or format_token_count(c_stats["max_limit"])
        fmt_in = c_stats.get("formatted_in") or format_token_count(c_stats["input_tokens"])
        fmt_cache = c_stats.get("formatted_cache") or format_token_count(c_stats["cache_tokens"])
        fmt_out = c_stats.get("formatted_out") or format_token_count(c_stats["output_tokens"])
        lines.append(f"Контекстное окно: [{uni_bar}] {pct}% ({fmt_total} / {fmt_max})")
        lines.append(f"                 Вход: {fmt_in} | Кэш: {fmt_cache} | Ответ: {fmt_out}")
    lines.append("")
    if user_prompts:
        lines.append("--- ПЕРВЫЙ ЗАПРОС ---")
        p0 = user_prompts[0]
        if len(p0) > 350:
            p0 = p0[:347] + "..."
        lines.append(p0 + "\n")

    if len(user_prompts) > 1:
        lines.append("--- ПОСЛЕДНИЙ ЗАПРОС ---")
        p_last = user_prompts[-1]
        if len(p_last) > 350:
            p_last = p_last[:347] + "..."
        lines.append(p_last + "\n")

    if agent_responses:
        lines.append("--- ПОСЛЕДНИЙ ОТВЕТ АГЕНТА ---")
        a_last = agent_responses[-1]
        if len(a_last) > 600:
            a_last = a_last[:597] + "..."
        lines.append(a_last)

    return "\n".join(lines)


def parse_system_message_text(text: str):
    """Извлекает блоки <SYSTEM_MESSAGE>...</SYSTEM_MESSAGE> или форматирует текст как системное сообщение."""
    results = []
    if not text:
        return results
    pattern = r'(?s)<SYSTEM_MESSAGE>\s*(.*?)\s*</SYSTEM_MESSAGE>'
    matches = re.findall(pattern, text)
    if matches:
        for body in matches:
            body = body.strip()
            summary = ""
            m_content = re.search(r'content=([^\r\n]+)', body)
            if m_content:
                summary = m_content.group(1).strip()
            else:
                lines = [ln.strip() for ln in body.splitlines() if ln.strip()]
                summary = lines[0] if lines else "Системное уведомление"
            summary = re.sub(r'Task id "[0-9a-fA-F\-]{20,}/(task-\d+)"', r'Task id "\1"', summary)
            if len(summary) > 75:
                summary = summary[:72] + "..."
            results.append({"summary": summary, "body": body})
    else:
        body = text.strip()
        lines = [ln.strip() for ln in body.splitlines() if ln.strip()]
        summary = lines[0] if lines else "Системное уведомление"
        summary = re.sub(r'Task id "[0-9a-fA-F\-]{20,}/(task-\d+)"', r'Task id "\1"', summary)
        if len(summary) > 75:
            summary = summary[:72] + "..."
        results.append({"summary": summary, "body": body})
    return results


def load_conversation_transcript(conversation_id):
    """Загрузка сообщений диалога для отображения в основном окне чата."""
    home_dir = os.path.expanduser("~")
    tpath = os.path.join(home_dir, ".gemini", "antigravity-cli", "brain", conversation_id, ".system_generated", "logs", "transcript.jsonl")
    if not os.path.isfile(tpath):
        return []

    items = []
    items.append(("system", f"[ИНФО] Загружена история диалога ({conversation_id})\n\n"))

    turns = []
    current_turn = None

    try:
        with open(tpath, "r", encoding="utf-8", errors="ignore") as f:
            for line in f:
                line = line.strip()
                if not line or ('"USER_INPUT"' not in line and '"PLANNER_RESPONSE"' not in line and '"SYSTEM_MESSAGE"' not in line and 'SYSTEM_MESSAGE' not in line):
                    continue
                try:
                    step = json.loads(line)
                    stype = step.get("type")
                    if stype == "SYSTEM_MESSAGE":
                        raw_sys = step.get("content", "")
                        sys_list = parse_system_message_text(raw_sys)
                        if not current_turn:
                            time_str = ""
                            created_at = step.get("created_at", "")
                            if created_at:
                                try:
                                    dt = datetime.datetime.fromisoformat(created_at.replace("Z", "+00:00"))
                                    time_str = dt.astimezone().strftime("%H:%M:%S")
                                except Exception:
                                    pass
                            current_turn = {
                                "user_time": time_str,
                                "user_badges": "",
                                "user_text": "",
                                "items": []
                            }
                        for sm in sys_list:
                            current_turn["items"].append({"type": "SYSTEM_MESSAGE", "summary": sm["summary"], "body": sm["body"]})
                    elif stype == "USER_INPUT":
                        if current_turn:
                            turns.append(current_turn)
                        raw = step.get("content", "")
                        embedded_sys = []
                        if "<SYSTEM_MESSAGE>" in raw:
                            embedded_sys = parse_system_message_text(raw)
                            raw = re.sub(r'(?s)(?:The following is a <SYSTEM_MESSAGE>[\s\S]*?attention to\.[\s\r\n]*)?<SYSTEM_MESSAGE>[\s\S]*?</SYSTEM_MESSAGE>', '', raw).strip()
                        if "<ADDITIONAL_METADATA>" in raw:
                            raw = re.sub(r'(?s)<ADDITIONAL_METADATA>[\s\S]*?</ADDITIONAL_METADATA>', '', raw).strip()
                        if "<USER_SETTINGS_CHANGE>" in raw:
                            raw = re.sub(r'(?s)<USER_SETTINGS_CHANGE>[\s\S]*?</USER_SETTINGS_CHANGE>', '', raw).strip()

                        # Выделение значков вложений и очистка текста запроса
                        badges = ""
                        clean_text = raw
                        attach_match = re.search(r'\[Прикрепленные изображения:\s*([\s\S]*?)\]', raw)
                        if attach_match:
                            img_section = attach_match.group(1)
                            files = []
                            for m in re.finditer(r'^\s*-\s*(?:file:///)?([^\r\n]+)', img_section, re.MULTILINE):
                                fpath = m.group(1).strip().replace('/', os.sep)
                                fname = os.path.basename(fpath)
                                if fname:
                                    files.append(f"🖼️ {fname}")
                            if files:
                                badges = "[" + ", ".join(files) + "]"
                            clean_text = re.sub(r'\[Прикрепленные изображения:[\s\S]*?\]\s*(?:Внимание агенту:[^\r\n]*\r?\n*)?', '', raw).strip()

                        if "<USER_REQUEST>" in clean_text:
                            start = clean_text.find("<USER_REQUEST>") + len("<USER_REQUEST>")
                            end = clean_text.find("</USER_REQUEST>")
                            if end > start:
                                clean_text = clean_text[start:end].strip()
                            else:
                                clean_text = clean_text[start:].strip()

                        time_str = ""
                        created_at = step.get("created_at", "")
                        if created_at:
                            try:
                                dt = datetime.datetime.fromisoformat(created_at.replace("Z", "+00:00"))
                                time_str = dt.astimezone().strftime("%H:%M:%S")
                            except Exception:
                                pass

                        current_turn = {
                            "user_time": time_str,
                            "user_badges": badges,
                            "user_text": clean_text,
                            "items": []
                        }
                        for sm in embedded_sys:
                            current_turn["items"].append({"type": "SYSTEM_MESSAGE", "summary": sm["summary"], "body": sm["body"]})
                    elif stype == "PLANNER_RESPONSE" and current_turn:
                        active_tools = []
                        for tc in step.get("tool_calls", []):
                            tname = tc.get("name", "tool")
                            args = tc.get("args") or {}
                            summary = ""
                            if isinstance(args, dict):
                                summary = args.get("toolSummary", "") or args.get("CommandLine", "")
                                if not summary and args.get("Path"):
                                    p = str(args["Path"]).replace('/', os.sep)
                                    summary = os.path.basename(p)
                                elif not summary and args.get("query"):
                                    summary = str(args["query"])
                                if len(summary) > 40:
                                    summary = summary[:37] + "..."
                            active_tools.append({"name": tname, "summary": summary})
                        if active_tools:
                            current_turn["items"].append({"type": "TOOLS", "tools": active_tools})
                        content = step.get("content", "")
                        if content:
                            current_turn["items"].append({"type": "AGENT_TEXT", "text": content})
                except Exception:
                    pass
        if current_turn:
            turns.append(current_turn)
    except Exception:
        pass

    for t in turns:
        if t["user_text"] or t["user_badges"]:
            header = f"[Вы ({t['user_time']})]:" if t["user_time"] else "[Вы]:"
            items.append(("user_header", f"\n{header} "))
            if t["user_badges"]:
                items.append(("badge", f"{t['user_badges']} "))
            items.append(("user_text", f"{t['user_text']}\n\n"))

        agent_header_added = False
        for it in t.get("items", []):
            itype = it.get("type")
            if itype == "TOOLS":
                if not agent_header_added:
                    items.append(("agent_header", "[Antigravity]:\n"))
                    agent_header_added = True
                items.append(("tool_group", it["tools"]))
            elif itype == "AGENT_TEXT":
                if not agent_header_added:
                    items.append(("agent_header", "[Antigravity]:\n"))
                    agent_header_added = True
                items.append(("agent_text", f"{it['text']}\n\n"))
            elif itype == "SYSTEM_MESSAGE":
                items.append(("system_card", {"summary": it["summary"], "body": it["body"]}))

    return items


def set_conversation_title(conv_id: str, new_title: str) -> bool:
    """Устанавливает новое пользовательское название разговора в sessions_meta.json."""
    if not conv_id or not new_title:
        return False
    clean_title = new_title.splitlines()[0].strip() if new_title else ""
    if not clean_title:
        return False
    if len(clean_title) > 120:
        clean_title = clean_title[:117] + "..."

    meta_path = get_session_meta_path()
    try:
        data = {}
        if os.path.isfile(meta_path):
            with open(meta_path, "r", encoding="utf-8") as f:
                data = json.load(f)
        if conv_id in data:
            data[conv_id]["title"] = clean_title
            data[conv_id]["timestamp"] = int(datetime.datetime.now().timestamp() * 1000)
        else:
            data[conv_id] = {
                "workspace": "",
                "title": clean_title,
                "timestamp": int(datetime.datetime.now().timestamp() * 1000)
            }
        with open(meta_path, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
        return True
    except Exception as e:
        print(f"Ошибка сохранения названия диалога: {e}")
        return False


def remove_antigravity_conversation(conv_id: str) -> bool:
    """Удаляет директорию разговора с диска и очищает запись в локальном кэше sessions_meta.json."""
    if not conv_id or not re.match(r"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", conv_id):
        return False
    user_home = Path.home() if "Path" in globals() else os.path.expanduser("~")
    target_dir = os.path.join(str(user_home), ".gemini", "antigravity-cli", "brain", conv_id)
    success = False
    if os.path.isdir(target_dir):
        try:
            shutil.rmtree(target_dir)
            success = True
        except Exception as e:
            print(f"Ошибка удаления директории разговора {target_dir}: {e}")
            return False

    meta_path = get_session_meta_path()
    if os.path.isfile(meta_path):
        try:
            with open(meta_path, "r", encoding="utf-8") as f:
                data = json.load(f)
            if conv_id in data:
                del data[conv_id]
                with open(meta_path, "w", encoding="utf-8") as f:
                    json.dump(data, f, ensure_ascii=False, indent=2)
        except Exception:
            pass

    return success


class ConversationHistoryDialog(tk.Toplevel):
    """Модальное окно просмотра списка разговоров и выбора сессии для продолжения."""
    def __init__(self, parent, on_select_callback):
        super().__init__(parent)
        self.title("💬 Список и выбор разговоров Antigravity")
        self.geometry("960x620")
        self.minsize(750, 450)
        self.transient(parent)
        self.grab_set()

        self.parent = parent
        self.on_select_callback = on_select_callback
        self.all_conversations = []

        self.configure(bg="#181818")
        icon_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "app_icon.ico")
        if os.path.isfile(icon_path):
            try:
                self.iconbitmap(icon_path)
            except Exception:
                pass
        self._create_widgets()
        self._load_conversations()

    def _create_widgets(self):
        container = tk.Frame(self, bg="#181818", padx=12, pady=12)
        container.pack(fill=tk.BOTH, expand=True)

        # 1. Верхняя панель поиска
        top_bar = tk.Frame(container, bg="#181818")
        top_bar.pack(fill=tk.X, pady=(0, 10))

        tk.Label(top_bar, text="🔍 Поиск разговоров:", bg="#181818", fg="#D4D4D4", font=("Segoe UI", 10, "bold")).pack(side=tk.LEFT, padx=(0, 8))
        self.var_search = tk.StringVar()
        self.var_search.trace_add("write", lambda *args: self._apply_filter())
        self.ent_search = tk.Entry(top_bar, textvariable=self.var_search, bg="#252526", fg="#FFFFFF", insertbackground="#007ACC", relief=tk.FLAT, bd=1, highlightthickness=1, highlightbackground="#3E3E42", font=("Segoe UI", 10))
        self.ent_search.pack(side=tk.LEFT, fill=tk.X, expand=True, padx=(0, 8), ipady=3)

        btn_refresh = ttk.Button(top_bar, text="🔄 Обновить", command=self._load_conversations)
        btn_refresh.pack(side=tk.LEFT)

        # 2. Центральная панель: Список слева, предпросмотр справа
        mid_paned = ttk.PanedWindow(container, orient=tk.HORIZONTAL)
        mid_paned.pack(fill=tk.BOTH, expand=True, pady=(0, 10))

        # Левая часть: Таблица
        left_frame = tk.Frame(mid_paned, bg="#1E1E1E")
        mid_paned.add(left_frame, weight=3)

        columns = ("date", "project", "messages", "title")
        self.tree = ttk.Treeview(left_frame, columns=columns, show="headings", selectmode="browse")
        self.tree.heading("date", text="Дата и время")
        self.tree.heading("project", text="Проект")
        self.tree.heading("messages", text="Ходов")
        self.tree.heading("title", text="Тема / Первый запрос")

        self.tree.column("date", width=130, minwidth=110, stretch=False)
        self.tree.column("project", width=140, minwidth=100, stretch=False)
        self.tree.column("messages", width=60, minwidth=50, stretch=False)
        self.tree.column("title", width=250, minwidth=150, stretch=True)

        scroll_tree_y = ttk.Scrollbar(left_frame, orient=tk.VERTICAL, command=self.tree.yview)
        self.tree.configure(yscrollcommand=scroll_tree_y.set)
        scroll_tree_y.pack(side=tk.RIGHT, fill=tk.Y)
        self.tree.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)

        self.tree.bind("<<TreeviewSelect>>", self._on_tree_select)
        self.tree.bind("<Double-1>", self._on_tree_double_click)

        # Правая часть: Предпросмотр
        right_frame = tk.Frame(mid_paned, bg="#1E1E1E", padx=8, pady=8)
        mid_paned.add(right_frame, weight=2)

        tk.Label(right_frame, text="Предпросмотр диалога:", bg="#1E1E1E", fg="#007ACC", font=("Segoe UI", 10, "bold")).pack(anchor=tk.W, pady=(0, 6))
        self.txt_preview = tk.Text(right_frame, bg="#141414", fg="#CCCCCC", font=("Consolas", 9), wrap=tk.WORD, relief=tk.FLAT, bd=0, padx=6, pady=6)
        scroll_prev_y = ttk.Scrollbar(right_frame, orient=tk.VERTICAL, command=self.txt_preview.yview)
        self.txt_preview.configure(yscrollcommand=scroll_prev_y.set)
        scroll_prev_y.pack(side=tk.RIGHT, fill=tk.Y)
        self.txt_preview.pack(fill=tk.BOTH, expand=True)

        # 3. Нижняя панель действий
        bottom_bar = tk.Frame(container, bg="#181818")
        bottom_bar.pack(fill=tk.X)

        self.lbl_count = tk.Label(bottom_bar, text="Всего разговоров: 0", bg="#181818", fg="#888888", font=("Segoe UI", 9))
        self.lbl_count.pack(side=tk.LEFT, padx=(0, 10))

        btn_copy_id = ttk.Button(bottom_bar, text="📋 Скопировать ID", command=self._copy_id)
        btn_copy_id.pack(side=tk.LEFT, padx=(0, 6))

        btn_rename = ttk.Button(bottom_bar, text="✏️ Переименовать", command=self._rename_conv)
        btn_rename.pack(side=tk.LEFT, padx=(0, 6))

        btn_delete = ttk.Button(bottom_bar, text="🗑️ Удалить", command=self._delete_conv)
        btn_delete.pack(side=tk.LEFT)

        btn_cancel = ttk.Button(bottom_bar, text="Закрыть", command=self.destroy)
        btn_cancel.pack(side=tk.RIGHT, padx=(6, 0))

        btn_select = ttk.Button(bottom_bar, text="▶️ Продолжить этот диалог", style="Primary.TButton", command=self._select_and_close)
        btn_select.pack(side=tk.RIGHT, padx=(6, 0))

        btn_tui = ttk.Button(bottom_bar, text="🖥️ Открыть в TUI", command=self._launch_in_tui)
        btn_tui.pack(side=tk.RIGHT)

    def _load_conversations(self):
        self.all_conversations = get_antigravity_conversations()
        self._apply_filter()

    def _apply_filter(self):
        query = self.var_search.get().strip().lower()
        for item in self.tree.get_children():
            self.tree.delete(item)

        matched = []
        for c in self.all_conversations:
            if not query or (query in c["title"].lower() or query in c["project_name"].lower() or query in c["id"].lower() or query in c["date_display"]):
                matched.append(c)

        for c in matched:
            self.tree.insert("", tk.END, iid=c["id"], values=(c["date_display"], c["project_name"], c["message_count"], c["title"]))

        self.lbl_count.config(text=f"Найдено: {len(matched)} из {len(self.all_conversations)}")
        if matched:
            target_id = self.parent.conversation_id if self.parent.conversation_id in [m["id"] for m in matched] else matched[0]["id"]
            if self.tree.exists(target_id):
                self.tree.selection_set(target_id)
                self.tree.see(target_id)
        else:
            self.txt_preview.delete("1.0", tk.END)
            self.txt_preview.insert(tk.END, f"Разговоры не найдены по запросу '{query}'.")

    def _get_selected_conversation(self):
        sel = self.tree.selection()
        if not sel:
            return None
        cid = sel[0]
        for c in self.all_conversations:
            if c["id"] == cid:
                return c
        return None

    def _on_tree_select(self, event=None):
        c = self._get_selected_conversation()
        if c:
            self.txt_preview.delete("1.0", tk.END)
            self.txt_preview.insert(tk.END, get_conversation_preview_text(c["id"]))

    def _on_tree_double_click(self, event=None):
        self._select_and_close()

    def _select_and_close(self):
        c = self._get_selected_conversation()
        if c:
            self.on_select_callback(c)
            self.destroy()

    def _copy_id(self):
        c = self._get_selected_conversation()
        if c:
            self.clipboard_clear()
            self.clipboard_append(c["id"])
            messagebox.showinfo("Успешно", f"ID скопирован в буфер обмена:\n{c['id']}")

    def _rename_conv(self):
        c = self._get_selected_conversation()
        if not c:
            messagebox.showinfo("Уведомление", "Сначала выберите разговор из списка для переименования.", parent=self)
            return

        cid = c["id"]
        old_title = c.get("title", "")
        new_title = simpledialog.askstring("✏️ Переименование разговора", "Введите новое название разговора:", initialvalue=old_title, parent=self)
        if new_title and new_title.strip() and new_title.strip() != old_title:
            if set_conversation_title(cid, new_title.strip()):
                c["title"] = new_title.strip()
                self._load_conversations()
                self.parent._refresh_conversations_combo()
                messagebox.showinfo("Готово", "Название разговора успешно обновлено.", parent=self)

    def _delete_conv(self):
        c = self._get_selected_conversation()
        if not c:
            messagebox.showinfo("Уведомление", "Сначала выберите разговор из списка для удаления.")
            return

        cid = c["id"]
        title = c["title"]
        if len(title) > 60:
            title = title[:57] + "..."

        if not messagebox.askyesno(
            "Подтверждение удаления",
            f"Вы уверены, что хотите удалить выбранный разговор?\n\nТема: {title}\nID: {cid}\nДата: {c['date_display']}\n\nДанные диалога будут безвозвратно удалены с диска.",
            icon="warning"
        ):
            return

        ok = remove_antigravity_conversation(cid)
        if ok:
            if getattr(self.parent, "conversation_id", None) == cid:
                self.parent._reset_to_new_chat()
            self._load_conversations()
            self.parent._refresh_conversations_combo()
            self.txt_preview.delete("1.0", tk.END)
            messagebox.showinfo("Готово", "Разговор успешно удален.")
        else:
            messagebox.showerror("Ошибка", "Не удалось удалить директорию разговора.")

    def _launch_in_tui(self):
        c = self._get_selected_conversation()
        if c:
            ws = c["workspace"] if c["workspace"] and os.path.isdir(c["workspace"]) else self.parent.var_workspace.get()
            model = self.parent.var_model.get()
            mode = self.parent.var_mode.get()
            effort = self.parent.var_effort.get()
            effort_arg = f'--effort "{effort}"' if effort != "auto" else ""
            skip = "--dangerously-skip-permissions" if self.parent.var_skip_perms.get() else ""
            conv_arg = f'--conversation "{c["id"]}"'

            if sys.platform == "win32":
                cmd = f'cd /d "{ws}" && "{self.parent.agy_path}" --model "{model}" --mode "{mode}" {effort_arg} {skip} {conv_arg}'
                subprocess.Popen(f'start cmd /k "{cmd}"', shell=True)
            else:
                args = [self.parent.agy_path, "--model", model, "--mode", mode, "--conversation", c["id"]]
                if effort != "auto":
                    args.extend(["--effort", effort])
                subprocess.Popen(args, cwd=ws)


class CollapsibleToolCard(tk.Frame):
    """Интерактивная сворачиваемая карточка группы вызовов инструментов в чате Tkinter."""
    def __init__(self, parent_text, bg_card="#252526", bg_header="#2D2D30", border_col="#3E3E42"):
        super().__init__(parent_text, bg=bg_card, bd=1, relief=tk.SOLID, highlightbackground=border_col, highlightthickness=1)
        self.parent_text = parent_text
        self.is_collapsed = False
        self.tool_count = 0
        self.total_seconds = 0.0
        self.pending_items = {}

        # Шапка / кнопка сворачивания
        self.header_frame = tk.Frame(self, bg=bg_header, cursor="hand2")
        self.header_frame.pack(fill=tk.X)

        self.lbl_title = tk.Label(
            self.header_frame,
            text="⚙️ Вызовы инструментов (выполняется...)",
            fg="#CE9178",
            bg=bg_header,
            font=("Consolas", 10, "bold"),
            padx=8,
            pady=4
        )
        self.lbl_title.pack(side=tk.LEFT)

        self.lbl_toggle = tk.Label(
            self.header_frame,
            text="▼ Свернуть",
            fg="#858585",
            bg=bg_header,
            font=("Consolas", 9),
            padx=8,
            pady=4
        )
        self.lbl_toggle.pack(side=tk.RIGHT)

        # Тело со списком вызовов
        self.body_frame = tk.Frame(self, bg="#1E1E1E", padx=8, pady=6)
        self.body_frame.pack(fill=tk.X)

        for w in (self.header_frame, self.lbl_title, self.lbl_toggle):
            w.bind("<Button-1>", self.toggle)

    def toggle(self, event=None):
        if self.is_collapsed:
            self.body_frame.pack(fill=tk.X)
            self.lbl_toggle.config(text="▼ Свернуть")
            self.is_collapsed = False
        else:
            self.body_frame.pack_forget()
            self.lbl_toggle.config(text=f"▶ Развернуть ({self.tool_count})")
            self.is_collapsed = True

    def add_start(self, tool_name):
        lbl = tk.Label(
            self.body_frame,
            text=f"  ⏳ ⚙️ [{tool_name}] — выполняется...",
            fg="#E2C08D",
            bg="#1E1E1E",
            font=("Consolas", 9),
            anchor="w"
        )
        lbl.pack(fill=tk.X, pady=1)
        self.pending_items[tool_name] = lbl
        self.lbl_title.config(text=f"⚙️ Выполняется: {tool_name}...")

    def add_done(self, tool_name, duration):
        self.tool_count += 1
        self.total_seconds += duration
        if tool_name in self.pending_items:
            lbl = self.pending_items.pop(tool_name)
            lbl.config(text=f"  ✔️ ⚙️ [{tool_name}] — выполнен за {duration} сек", fg="#4EC9B0")
        else:
            lbl = tk.Label(
                self.body_frame,
                text=f"  ✔️ ⚙️ [{tool_name}] — выполнен за {duration} сек",
                fg="#4EC9B0",
                bg="#1E1E1E",
                font=("Consolas", 9),
                anchor="w"
            )
            lbl.pack(fill=tk.X, pady=1)
        self.lbl_title.config(text=f"⚙️ Вызовы инструментов ({self.tool_count}) • {round(self.total_seconds, 2)} сек")

    def finalize(self):
        for tname, lbl in list(self.pending_items.items()):
            lbl.config(text=f"  ✔️ ⚙️ [{tname}] — завершено", fg="#4EC9B0")
            self.tool_count += 1
        self.pending_items.clear()
        dur_str = f" • {round(self.total_seconds, 2)} сек" if self.total_seconds > 0 else ""
        self.lbl_title.config(text=f"⚙️ Вызовы инструментов ({self.tool_count} операций){dur_str}")
        self.body_frame.pack_forget()
        self.lbl_toggle.config(text=f"▶ Развернуть ({self.tool_count})")
        self.is_collapsed = True


class CollapsibleSystemMessageCard(tk.Frame):
    """Интерактивная сворачиваемая карточка системного уведомления (<SYSTEM_MESSAGE>) в Tkinter."""
    def __init__(self, parent_text, summary, body, bg_card="#1F2428", bg_header="#21262D", border_col="#388BFD"):
        super().__init__(parent_text, bg=bg_card, bd=1, relief=tk.SOLID, highlightbackground=border_col, highlightthickness=1)
        self.parent_text = parent_text
        self.is_collapsed = True
        self.summary = summary
        self.body = body

        # Шапка / кнопка сворачивания
        self.header_frame = tk.Frame(self, bg=bg_header, cursor="hand2")
        self.header_frame.pack(fill=tk.X)

        title_text = f"🔔 Системное уведомление: {summary}"
        self.lbl_title = tk.Label(
            self.header_frame,
            text=title_text,
            fg="#58A6FF",
            bg=bg_header,
            font=("Consolas", 10, "bold"),
            padx=8,
            pady=4,
            anchor="w"
        )
        self.lbl_title.pack(side=tk.LEFT, fill=tk.X, expand=True)

        self.lbl_toggle = tk.Label(
            self.header_frame,
            text="▶ Развернуть",
            fg="#C9D1D9",
            bg="#30363D",
            font=("Consolas", 9, "bold"),
            padx=8,
            pady=2,
            bd=1,
            relief=tk.SOLID
        )
        self.lbl_toggle.pack(side=tk.RIGHT, padx=4, pady=3)

        # Тело сообщения
        self.body_frame = tk.Frame(self, bg="#161B22", padx=8, pady=6)
        num_lines = min(12, max(3, len(body.splitlines())))
        self.txt_body = tk.Text(
            self.body_frame,
            bg="#161B22",
            fg="#C9D1D9",
            font=("Consolas", 9),
            wrap=tk.WORD,
            bd=0,
            padx=4,
            pady=4,
            height=num_lines,
            relief=tk.FLAT
        )
        self.txt_body.insert(tk.END, body)
        self.txt_body.config(state=tk.DISABLED)
        self.txt_body.pack(fill=tk.BOTH, expand=True)

        for w in (self.header_frame, self.lbl_title, self.lbl_toggle):
            w.bind("<Button-1>", self.toggle)

    def toggle(self, event=None):
        if self.is_collapsed:
            self.body_frame.pack(fill=tk.X)
            self.lbl_toggle.config(text="▼ Свернуть")
            self.is_collapsed = False
        else:
            self.body_frame.pack_forget()
            self.lbl_toggle.config(text="▶ Развернуть")
            self.is_collapsed = True


class AntigravityGUI(tk.Tk):
    def __init__(self):
        super().__init__()

        self.title("⚡ Antigravity Agent Launcher (Python)")
        self.geometry("1060x760")
        self.minsize(860, 600)
        icon_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "app_icon.ico")
        if os.path.isfile(icon_path):
            try:
                self.iconbitmap(icon_path)
            except Exception:
                pass

        # Переменные состояния
        self.agy_path = find_agy_executable()
        self.default_workspace = os.path.abspath(r"C:\Users\Olden\Desktop\IGROSTROY")
        if not os.path.isdir(self.default_workspace):
            self.default_workspace = os.getcwd()

        self.conversation_id = None
        self.current_process = None
        self.is_running = False
        self.event_queue = queue.Queue()
        self.last_sent_prompt = ""
        self.suppress_conv_event = False
        self.recent_conversations = []
        self.attached_images = []
        self.preview_images_cache = []
        self.active_tool_card = None

        # Масштабирование шрифта и персистентность
        self.default_font_size = 10
        self.min_font_size = 7
        self.max_font_size = 30
        self.min_win_width = 860
        self.min_win_height = 600

        saved_cfg = load_launcher_config()
        saved_size = saved_cfg.get("fontSize")
        if isinstance(saved_size, (int, float)) and self.min_font_size <= saved_size <= self.max_font_size:
            self.current_font_size = int(round(saved_size))
        else:
            self.current_font_size = self.default_font_size

        # Восстановление сохраненных размеров окна
        saved_w = saved_cfg.get("windowWidth")
        saved_h = saved_cfg.get("windowHeight")
        if isinstance(saved_w, (int, float)) and isinstance(saved_h, (int, float)):
            w = max(self.min_win_width, int(saved_w))
            h = max(self.min_win_height, int(saved_h))
            self.geometry(f"{w}x{h}")

        if saved_cfg.get("isMaximized") is True:
            try:
                self.state("zoomed")
            except Exception:
                pass

        self._init_theme()
        self._create_widgets()
        self._apply_zoom(self.current_font_size, save=False)
        self._populate_projects()
        self._refresh_conversations_combo()
        self._check_queue_loop()
        self.protocol("WM_DELETE_WINDOW", self._on_window_closing)

    def _on_window_closing(self):
        """Сохранение конфигурации при закрытии приложения."""
        is_zoomed = False
        try:
            is_zoomed = (self.state() == "zoomed")
        except Exception:
            pass

        win_data = {
            "fontSize": self.current_font_size,
            "isMaximized": is_zoomed
        }
        try:
            w = self.winfo_width()
            h = self.winfo_height()
            if w >= self.min_win_width:
                win_data["windowWidth"] = w
            if h >= self.min_win_height:
                win_data["windowHeight"] = h
        except Exception:
            pass

        save_launcher_config(win_data)
        self.destroy()

    def _init_theme(self):
        """Настройка темной темы (VS Code Dark)."""
        self.bg_main = "#181818"
        self.bg_panel = "#202020"
        self.bg_input = "#252526"
        self.fg_main = "#D4D4D4"
        self.fg_bright = "#FFFFFF"
        self.accent_blue = "#0E639C"
        self.accent_green = "#2E7D32"
        self.accent_red = "#C62828"
        self.border_col = "#3E3E42"

        self.configure(bg=self.bg_main)

        style = ttk.Style(self)
        style.theme_use("clam")

        style.configure("TLabel", background=self.bg_panel, foreground=self.fg_main, font=("Segoe UI", 10))
        style.configure("Header.TLabel", background=self.bg_panel, foreground=self.fg_bright, font=("Segoe UI", 10, "bold"))
        style.configure("TFrame", background=self.bg_main)
        style.configure("Panel.TFrame", background=self.bg_panel)
        
        style.configure("TButton", background="#2D2D30", foreground=self.fg_bright, bordercolor=self.border_col, font=("Segoe UI", 9))
        style.map("TButton", background=[("active", "#3E3E42"), ("disabled", "#1F1F1F")])

        style.configure("Primary.TButton", background=self.accent_blue, foreground=self.fg_bright, font=("Segoe UI", 10, "bold"))
        style.map("Primary.TButton", background=[("active", "#1177BB"), ("disabled", "#1E3547")])

        style.configure("Stop.TButton", background=self.accent_red, foreground=self.fg_bright, font=("Segoe UI", 9, "bold"))
        style.map("Stop.TButton", background=[("active", "#E53935"), ("disabled", "#3A1E1E")])

        style.configure("NewChat.TButton", background=self.accent_green, foreground=self.fg_bright, font=("Segoe UI", 9, "bold"))
        style.map("NewChat.TButton", background=[("active", "#388E3C")])

        style.configure("TCheckbutton", background=self.bg_panel, foreground=self.fg_main, font=("Segoe UI", 9))
        style.map("TCheckbutton", background=[("active", self.bg_panel)])

        style.configure("TCombobox", fieldbackground=self.bg_input, background="#2D2D30", foreground=self.fg_bright, darkcolor=self.border_col, lightcolor=self.border_col)
        style.map("TCombobox",
                  fieldbackground=[("readonly", self.bg_input)],
                  foreground=[("readonly", self.fg_bright)],
                  selectbackground=[("readonly", "#0E639C")],
                  selectforeground=[("readonly", "#FFFFFF")])

        # Настройка выпадающего списка попапа ComboBox в темной теме
        self.option_add("*TCombobox*Listbox.background", "#222222")
        self.option_add("*TCombobox*Listbox.foreground", "#F1F1F1")
        self.option_add("*TCombobox*Listbox.selectBackground", "#0E639C")
        self.option_add("*TCombobox*Listbox.selectForeground", "#FFFFFF")

    def _create_widgets(self):
        """Создание всех элементов интерфейса."""
        # Главный контейнер
        main_box = tk.Frame(self, bg=self.bg_main, padx=14, pady=12)
        main_box.pack(fill=tk.BOTH, expand=True)

        # 1. Верхняя панель настроек
        top_panel = tk.Frame(main_box, bg=self.bg_panel, bd=1, relief=tk.SOLID, padx=12, pady=10)
        top_panel.pack(fill=tk.X, pady=(0, 10))

        # Строка 1: Рабочая папка
        row1 = tk.Frame(top_panel, bg=self.bg_panel)
        row1.pack(fill=tk.X, pady=(0, 8))

        lbl_ws = ttk.Label(row1, text="Рабочая папка:", style="Header.TLabel")
        lbl_ws.pack(side=tk.LEFT, padx=(0, 8))

        self.var_workspace = tk.StringVar(value=self.default_workspace)
        self.ent_workspace = tk.Entry(row1, textvariable=self.var_workspace, bg=self.bg_input, fg=self.fg_bright, insertbackground="#007ACC", relief=tk.FLAT, bd=1, highlightthickness=1, highlightbackground=self.border_col, font=("Segoe UI", 10))
        self.ent_workspace.pack(side=tk.LEFT, fill=tk.X, expand=True, padx=(0, 6), ipady=3)

        btn_browse = ttk.Button(row1, text="Обзор...", command=self._browse_workspace)
        btn_browse.pack(side=tk.LEFT, padx=(0, 8))

        self.var_project_choice = tk.StringVar(value="— Быстрый выбор проекта —")
        self.cmb_projects = ttk.Combobox(row1, textvariable=self.var_project_choice, state="readonly", width=30)
        self.cmb_projects.pack(side=tk.LEFT)
        self.cmb_projects.bind("<<ComboboxSelected>>", self._on_project_selected)

        # Строка 2: Модель, режим, мышление, чекбоксы
        row2 = tk.Frame(top_panel, bg=self.bg_panel)
        row2.pack(fill=tk.X, pady=(0, 8))

        ttk.Label(row2, text="Модель:").pack(side=tk.LEFT, padx=(0, 4))
        self.var_model = tk.StringVar(value="gemini-3.8-flash-high")
        models = [
            "gemini-3.8-flash-high",
            "gemini-3.8-flash-medium",
            "gemini-3.8-flash-low",
            "claude-sonnet-4-6",
            "claude-opus-4-6-thinking",
            "gpt-oss-120b-medium"
        ]
        self.cmb_model = ttk.Combobox(row2, textvariable=self.var_model, values=models, state="readonly", width=22)
        self.cmb_model.pack(side=tk.LEFT, padx=(0, 14))

        ttk.Label(row2, text="Режим:").pack(side=tk.LEFT, padx=(0, 4))
        self.var_mode = tk.StringVar(value="auto")
        self.cmb_mode = ttk.Combobox(row2, textvariable=self.var_mode, values=["auto", "plan", "accept-edits"], state="readonly", width=12)
        self.cmb_mode.pack(side=tk.LEFT, padx=(0, 14))

        ttk.Label(row2, text="Рассуждение:").pack(side=tk.LEFT, padx=(0, 4))
        self.var_effort = tk.StringVar(value="auto")
        self.cmb_effort = ttk.Combobox(row2, textvariable=self.var_effort, values=["auto", "high", "medium", "low"], state="readonly", width=9)
        self.cmb_effort.pack(side=tk.LEFT, padx=(0, 14))

        self.var_skip_perms = tk.BooleanVar(value=True)
        self.chk_skip_perms = ttk.Checkbutton(row2, text="Авто-подтверждение (--dangerously-skip-permissions)", variable=self.var_skip_perms)
        self.chk_skip_perms.pack(side=tk.LEFT)

        # Строка 3: Разговоры и сессии
        row3 = tk.Frame(top_panel, bg=self.bg_panel)
        row3.pack(fill=tk.X)

        ttk.Label(row3, text="Разговор:", style="Header.TLabel").pack(side=tk.LEFT, padx=(0, 8))
        self.var_conv_choice = tk.StringVar(value="➕ [Новый диалог]")
        self.cmb_conversations = ttk.Combobox(row3, textvariable=self.var_conv_choice, state="readonly")
        self.cmb_conversations.pack(side=tk.LEFT, fill=tk.X, expand=True, padx=(0, 6))
        self.cmb_conversations.bind("<<ComboboxSelected>>", self._on_conv_selected)

        btn_manage_convs = ttk.Button(row3, text="💬 Все диалоги...", command=self._open_conversations_dialog)
        btn_manage_convs.pack(side=tk.LEFT, padx=(0, 6))

        btn_new_chat = ttk.Button(row3, text="➕ Новый диалог", style="NewChat.TButton", command=self._start_new_chat)
        btn_new_chat.pack(side=tk.LEFT, padx=(0, 6))

        btn_launch_tui = ttk.Button(row3, text="🖥️ Открыть TUI", command=self._launch_terminal_tui)
        btn_launch_tui.pack(side=tk.LEFT)

        # 2. Центральная область чата
        chat_frame = tk.Frame(main_box, bg=self.bg_panel, bd=1, relief=tk.SOLID)
        chat_frame.pack(fill=tk.BOTH, expand=True, pady=(0, 10))

        self.txt_chat = tk.Text(
            chat_frame,
            bg="#1E1E1E",
            fg=self.fg_main,
            insertbackground="#007ACC",
            font=("Consolas", 10),
            wrap=tk.WORD,
            relief=tk.FLAT,
            bd=0,
            padx=10,
            pady=10,
            spacing1=2,
            spacing2=4,
            spacing3=3
        )
        scroll_chat = ttk.Scrollbar(chat_frame, orient=tk.VERTICAL, command=self.txt_chat.yview)
        self.txt_chat.configure(yscrollcommand=scroll_chat.set)

        scroll_chat.pack(side=tk.RIGHT, fill=tk.Y)
        self.txt_chat.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)

        # Теги стилей чата с гармоничной палитрой
        self.txt_chat.tag_configure("user_header", foreground="#4FC1FF", font=("Consolas", 10, "bold"))
        self.txt_chat.tag_configure("user_text", foreground="#F1F1F1", font=("Consolas", 10))
        self.txt_chat.tag_configure("badge", foreground="#E2C08D", font=("Consolas", 10))
        self.txt_chat.tag_configure("agent_header", foreground="#C586C0", font=("Consolas", 10, "bold"))
        self.txt_chat.tag_configure("agent_text", foreground="#D4D4D4", font=("Consolas", 10))
        self.txt_chat.tag_configure("tool_start", foreground="#CE9178", font=("Consolas", 9, "italic"))
        self.txt_chat.tag_configure("tool_done", foreground="#4EC9B0", font=("Consolas", 9))
        self.txt_chat.tag_configure("system", foreground="#6A9955", font=("Consolas", 9))
        self.txt_chat.tag_configure("banner", foreground="#3E3E42", font=("Consolas", 10))
        self.txt_chat.tag_configure("error", foreground="#F85149", font=("Consolas", 10, "bold"))

        # Теги Markdown
        self.txt_chat.tag_configure("md_bold", foreground="#FFFFFF", font=("Consolas", 10, "bold"))
        self.txt_chat.tag_configure("md_italic", foreground="#DCDCDC", font=("Consolas", 10, "italic"))
        self.txt_chat.tag_configure("md_bolditalic", foreground="#FFFFFF", font=("Consolas", 10, "bold italic"))
        self.txt_chat.tag_configure("md_code", foreground="#CE9178", background="#28282B", font=("Consolas", 10))
        self.txt_chat.tag_configure("md_codeblock", foreground="#D4D4D4", background="#161618", font=("Consolas", 9))
        self.txt_chat.tag_configure("md_h1", foreground="#4FC1FF", font=("Consolas", 14, "bold"))
        self.txt_chat.tag_configure("md_h2", foreground="#4EC9B0", font=("Consolas", 12, "bold"))
        self.txt_chat.tag_configure("md_h3", foreground="#E2C08D", font=("Consolas", 11, "bold"))
        self.txt_chat.tag_configure("md_bullet", foreground="#569CD6", font=("Consolas", 10, "bold"))
        self.txt_chat.tag_configure("md_quote", foreground="#A0A0A0", font=("Consolas", 10, "italic"))
        self.txt_chat.tag_configure("md_hr", foreground="#3E3E42")

        # Алиасы совместимости
        self.txt_chat.tag_configure("user", foreground="#4FC1FF", font=("Consolas", 10, "bold"))
        self.txt_chat.tag_configure("agent", foreground="#C586C0", font=("Consolas", 10, "bold"))
        self.txt_chat.tag_configure("tool", foreground="#CE9178", font=("Consolas", 9, "italic"))

        # Начальный текст
        self.welcome_text = (
            "================================================================================\n"
            "  ⚡ Antigravity Agent Shell (Python Tkinter)\n"
            f"  Исполняемый файл: {self.agy_path}\n"
            "  Нажмите Enter для отправки, Shift+Enter для новой строки.\n"
            "================================================================================\n\n"
        )
        self._append_chat(self.welcome_text, "system")

        # 3. Панель прикрепленных изображений и вложений
        self.frame_attachments = tk.Frame(main_box, bg="#1C2128", bd=1, relief=tk.SOLID, padx=8, pady=6)
        # Изначально скрыта, пока нет вложений
        self.frame_attachments_list = tk.Frame(self.frame_attachments, bg="#1C2128")
        self.frame_attachments_list.pack(side=tk.LEFT, fill=tk.X, expand=True)
        btn_clear_att = ttk.Button(self.frame_attachments, text="Очистить все", command=self._clear_attachments)
        btn_clear_att.pack(side=tk.RIGHT, padx=(6, 0))

        # 4. Нижняя панель ввода
        input_frame = tk.Frame(main_box, bg=self.bg_main)
        input_frame.pack(fill=tk.X, pady=(0, 6))

        self.txt_prompt = tk.Text(
            input_frame,
            height=4,
            bg=self.bg_input,
            fg=self.fg_bright,
            insertbackground="#007ACC",
            font=("Segoe UI", 10),
            wrap=tk.WORD,
            relief=tk.FLAT,
            bd=1,
            highlightthickness=1,
            highlightbackground=self.border_col,
            padx=8,
            pady=6
        )
        self.txt_prompt.pack(side=tk.LEFT, fill=tk.X, expand=True, padx=(0, 8))
        self.txt_prompt.bind("<Return>", self._on_enter_pressed)
        self.txt_prompt.bind("<Control-Return>", lambda e: (self.send_prompt(), "break")[1])
        self.txt_prompt.bind("<Control-v>", self._on_paste_event)
        self.txt_prompt.bind("<Control-V>", self._on_paste_event)

        btn_box = tk.Frame(input_frame, bg=self.bg_main)
        btn_box.pack(side=tk.RIGHT, fill=tk.Y)

        self.btn_send = ttk.Button(btn_box, text="Отправить ↵", style="Primary.TButton", command=self.send_prompt)
        self.btn_send.pack(fill=tk.BOTH, expand=True, pady=(0, 3))

        self.btn_attach = ttk.Button(btn_box, text="📎 Картинка", command=self._pick_image_files)
        self.btn_attach.pack(fill=tk.X, pady=(0, 3))

        self.btn_stop = ttk.Button(btn_box, text="⏹ Стоп", style="Stop.TButton", command=self.stop_execution, state=tk.DISABLED)
        self.btn_stop.pack(fill=tk.X)

        # 5. Статус бар
        status_bar = tk.Frame(main_box, bg="#121212", bd=1, relief=tk.SOLID, padx=8, pady=4)
        status_bar.pack(fill=tk.X)

        self.lbl_status_dot = tk.Label(status_bar, text="●", fg="#4CAF50", bg="#121212", font=("Segoe UI", 11))
        self.lbl_status_dot.pack(side=tk.LEFT, padx=(0, 6))

        self.lbl_status_text = tk.Label(status_bar, text="Готов к работе", fg="#AAAAAA", bg="#121212", font=("Segoe UI", 9))
        self.lbl_status_text.pack(side=tk.LEFT)

        # Графический интерактивный виджет контекста
        self.frame_context = tk.Frame(status_bar, bg="#1C1F26", bd=1, relief=tk.SOLID, cursor="hand2", padx=6, pady=2)
        self.frame_context.pack(side=tk.LEFT, padx=(16, 0))

        self.lbl_context_icon = tk.Label(self.frame_context, text="🧠", fg="#FFFFFF", bg="#1C1F26", font=("Segoe UI", 9), cursor="hand2")
        self.lbl_context_icon.pack(side=tk.LEFT, padx=(0, 4))

        self.canvas_context_bar = tk.Canvas(self.frame_context, width=80, height=8, bg="#14161C", highlightthickness=1, highlightbackground="#252A34", cursor="hand2")
        self.canvas_context_bar.pack(side=tk.LEFT, padx=(0, 6))

        self.lbl_context_tokens = tk.Label(self.frame_context, text="0 / 1.0M", fg="#CCCCCC", bg="#1C1F26", font=("Consolas", 9), cursor="hand2")
        self.lbl_context_tokens.pack(side=tk.LEFT, padx=(0, 6))

        self.lbl_context_badge = tk.Label(self.frame_context, text="0%", fg="#4EC9B0", bg="#1B2F2B", font=("Segoe UI", 8, "bold"), padx=4, pady=0, cursor="hand2")
        self.lbl_context_badge.pack(side=tk.LEFT)

        # Сохраняем ссылку для обратной совместимости
        self.lbl_context = self.lbl_context_tokens

        for w in (self.frame_context, self.lbl_context_icon, self.canvas_context_bar, self.lbl_context_tokens, self.lbl_context_badge):
            w.bind("<Button-1>", lambda e: self._show_context_details_dialog())

        self.lbl_conv_id = tk.Label(status_bar, text="Диалог: Новый", fg="#888888", bg="#121212", font=("Segoe UI", 9), cursor="hand2")
        self.lbl_conv_id.pack(side=tk.RIGHT, padx=(10, 0))
        self.lbl_conv_id.bind("<Button-1>", lambda e: self._open_conversations_dialog())

        self.lbl_zoom = tk.Label(
            status_bar,
            text="🔍 100% (10pt)",
            fg="#888888",
            bg="#121212",
            font=("Segoe UI", 9),
            cursor="hand2"
        )
        self.lbl_zoom.pack(side=tk.RIGHT, padx=(10, 10))
        self.lbl_zoom.bind("<Button-1>", lambda e: self._zoom_reset())

        btn_clear = ttk.Button(status_bar, text="Очистить лог", command=self._clear_chat)
        btn_clear.pack(side=tk.RIGHT)

        # Привязка масштабирования шрифта
        self.bind_all("<MouseWheel>", self._on_mouse_wheel)
        self.bind_all("<Control-plus>", lambda e: self._zoom_in())
        self.bind_all("<Control-equal>", lambda e: self._zoom_in())
        self.bind_all("<Control-minus>", lambda e: self._zoom_out())
        self.bind_all("<Control-0>", lambda e: self._zoom_reset())

        self.var_model.trace_add("write", lambda *_: self._update_context_display())
        self._update_context_display()

    def _update_context_display(self, conv_id=None, model_name=None):
        """Обновляет индикатор заполненности контекста в статус-баре."""
        if conv_id is None:
            conv_id = self.conversation_id
        if model_name is None:
            model_name = self.var_model.get() if hasattr(self, "var_model") else "gemini-3.8-flash-high"
        stats = get_conversation_context_stats(conv_id, model_name)
        self.last_context_stats = stats

        fmt_total = stats.get("formatted_total", "0")
        fmt_max = stats.get("formatted_max", "1.0M")
        pct = stats.get("percent", 0.0)
        color = stats.get("color", "#4EC9B0")

        if hasattr(self, "lbl_context_tokens"):
            self.lbl_context_tokens.config(text=f"{fmt_total} / {fmt_max}")
        if hasattr(self, "lbl_context_badge"):
            badge_bg = "#381E20" if pct >= 80.0 else ("#332B1C" if pct >= 60.0 else "#1B2F2B")
            self.lbl_context_badge.config(text=f"{pct}%", fg=color, bg=badge_bg)
        if hasattr(self, "canvas_context_bar"):
            self.canvas_context_bar.delete("all")
            bar_w = 80
            fill_w = max(0, min(bar_w, int((pct / 100.0) * bar_w)))
            if fill_w > 0:
                self.canvas_context_bar.create_rectangle(0, 0, fill_w, 8, fill=color, outline="")

    def _show_context_details_dialog(self):
        """Открывает модальное диалоговое окно подробного анализа контекста."""
        stats = getattr(self, "last_context_stats", None)
        if not stats:
            stats = get_conversation_context_stats(
                self.conversation_id,
                self.var_model.get() if hasattr(self, "var_model") else "gemini-3.8-flash-high"
            )

        dlg = tk.Toplevel(self.root)
        dlg.title("🧠 Анализ контекстного окна модели")
        dlg.geometry("520x400")
        dlg.resizable(False, False)
        dlg.configure(bg="#181A20")
        dlg.transient(self.root)
        dlg.grab_set()

        try:
            dlg.update_idletasks()
            rx, ry = self.root.winfo_x(), self.root.winfo_y()
            rw, rh = self.root.winfo_width(), self.root.winfo_height()
            x = rx + max(0, (rw - 520) // 2)
            y = ry + max(0, (rh - 400) // 2)
            dlg.geometry(f"+{x}+{y}")
        except Exception:
            pass

        main_f = tk.Frame(dlg, bg="#181A20", padx=20, pady=20)
        main_f.pack(fill=tk.BOTH, expand=True)

        # 1. Шапка
        top_f = tk.Frame(main_f, bg="#181A20")
        top_f.pack(fill=tk.X, pady=(0, 14))

        title_f = tk.Frame(top_f, bg="#181A20")
        title_f.pack(side=tk.LEFT)
        tk.Label(title_f, text="🧠 Заполненность контекста", font=("Segoe UI", 15, "bold"), fg="#FFFFFF", bg="#181A20").pack(anchor=tk.W)
        model_name = stats.get("model_name", "gemini-3.8-flash-high")
        max_fmt = stats.get("formatted_max", "1.0M")
        tk.Label(title_f, text=f"Модель: {model_name} (Лимит: {max_fmt} токенов)", font=("Segoe UI", 9), fg="#8B949E", bg="#181A20").pack(anchor=tk.W, pady=(2, 0))

        pct = stats.get("percent", 0.0)
        color = stats.get("color", "#4EC9B0")
        badge_bg = "#381E20" if pct >= 80.0 else ("#332B1C" if pct >= 60.0 else "#1E242B")
        badge_f = tk.Frame(top_f, bg=badge_bg, bd=1, relief=tk.SOLID, padx=8, pady=4)
        badge_f.pack(side=tk.RIGHT)
        tk.Label(badge_f, text=f"{pct}%", font=("Segoe UI", 14, "bold"), fg=color, bg=badge_bg).pack()

        # 2. Графическая шкала
        prog_f = tk.Frame(main_f, bg="#181A20")
        prog_f.pack(fill=tk.X, pady=(0, 16))

        cv_prog = tk.Canvas(prog_f, height=12, bg="#101216", highlightthickness=1, highlightbackground="#262A34")
        cv_prog.pack(fill=tk.X, pady=(0, 6))
        cv_prog.update_idletasks()
        cw = 475
        fill_w = max(0, min(cw, int((pct / 100.0) * cw)))
        if fill_w > 0:
            cv_prog.create_rectangle(0, 0, fill_w, 12, fill=color, outline="")

        info_bar = tk.Frame(prog_f, bg="#181A20")
        info_bar.pack(fill=tk.X)
        fmt_total = stats.get("formatted_total", "0")
        fmt_rem = stats.get("formatted_rem", "1.0M")
        rem_pct = stats.get("rem_percent", 100.0)
        tk.Label(info_bar, text=f"Занято: {fmt_total} токенов", font=("Segoe UI", 9), fg="#AAAAAA", bg="#181A20").pack(side=tk.LEFT)
        tk.Label(info_bar, text=f"Свободно: {fmt_rem} ({rem_pct}%)", font=("Segoe UI", 9), fg="#8B949E", bg="#181A20").pack(side=tk.RIGHT)

        # 3. Карточки раскладки (4 штуки)
        cards_f = tk.Frame(main_f, bg="#181A20")
        cards_f.pack(fill=tk.X, pady=(0, 14))

        card_defs = [
            ("⚡ КЭШ", stats.get("formatted_cache", "0"), "предыстория", "#58A6FF", "#1C212B"),
            ("📥 ВХОД", stats.get("formatted_in", "0"), "новый запрос", "#3FB950", "#1C2622"),
            ("📤 ОТВЕТ", stats.get("formatted_out", "0"), "генерация", "#BC8CFF", "#242129"),
            ("🛡️ ЗАПАС", fmt_rem, f"{rem_pct}% свободно", "#79C0FF", "#191F26"),
        ]

        for i, (hdr, val, sub, hdr_col, bg_col) in enumerate(card_defs):
            cf = tk.Frame(cards_f, bg=bg_col, bd=1, relief=tk.SOLID, padx=8, pady=6)
            cf.pack(side=tk.LEFT, fill=tk.BOTH, expand=True, padx=(0 if i == 0 else 4, 0 if i == 3 else 4))
            tk.Label(cf, text=hdr, font=("Segoe UI", 8, "bold"), fg=hdr_col, bg=bg_col).pack(anchor=tk.W)
            tk.Label(cf, text=val, font=("Segoe UI", 12, "bold"), fg="#FFFFFF", bg=bg_col).pack(anchor=tk.W, pady=(2, 0))
            tk.Label(cf, text=sub, font=("Segoe UI", 8), fg="#8B949E", bg=bg_col).pack(anchor=tk.W)

        # 4. Рекомендация
        if pct >= 80.0:
            advice = f"⚠️ ВНИМАНИЕ: Контекстное окно заполнено на {pct}%! Дальнейшие запросы могут приводить к вытеснению инструкций или снижению качества кода. Рекомендуется выполнить команду /compact для сжатия диалога."
        elif pct >= 60.0:
            advice = f"ℹ️ ПРЕДУПРЕЖДЕНИЕ: Использовано {pct}% контекста. Система работает стабильно, однако рекомендуется соблюдать умеренность при одновременной передаче объемных файлов."
        elif stats.get("total_tokens", 0) == 0:
            advice = "✨ Диалог новый либо статистика использования токенов еще не поступила. При первом ответе модели здесь появится детальная раскладка."
        else:
            advice = f"✅ Отличное состояние: занято всего {pct}% контекстного окна ({fmt_total} из {max_fmt}). Модель удерживает полную историю и готова к масштабным задачам."

        adv_f = tk.Frame(main_f, bg="#161920", bd=1, relief=tk.SOLID, padx=12, pady=10)
        adv_f.pack(fill=tk.X, pady=(0, 16))
        tk.Label(adv_f, text=advice, font=("Segoe UI", 9), fg=color, bg="#161920", wraplength=460, justify=tk.LEFT).pack(anchor=tk.W)

        # 5. Кнопка Закрыть
        btn_close = tk.Button(main_f, text="Закрыть", command=dlg.destroy, bg="#21262D", fg="#FFFFFF", bd=0, padx=16, pady=5, font=("Segoe UI", 9, "bold"), cursor="hand2")
        btn_close.pack(side=tk.RIGHT)

    def _refresh_conversations_combo(self):
        """Обновление выпадающего списка недавних диалогов."""
        self.suppress_conv_event = True
        try:
            self.recent_conversations = get_antigravity_conversations()[:30]
            values = ["➕ [Новый диалог]"]
            for c in self.recent_conversations:
                date_part = c["date_display"][:10]
                proj_part = f"[{c['project_name']}] " if c["project_name"] and c["project_name"] != "—" else ""
                disp = f"{date_part} | {proj_part}{c['title']}"
                if len(disp) > 75:
                    disp = disp[:72] + "..."
                values.append(disp)

            self.cmb_conversations["values"] = values

            if self.conversation_id:
                found_idx = 0
                for idx, c in enumerate(self.recent_conversations):
                    if c["id"] == self.conversation_id:
                        found_idx = idx + 1
                        break
                self.cmb_conversations.current(found_idx)
            else:
                self.cmb_conversations.current(0)
        finally:
            self.suppress_conv_event = False

    def _on_conv_selected(self, event=None):
        """Обработка выбора диалога из комбобокса."""
        if self.suppress_conv_event:
            return
        idx = self.cmb_conversations.current()
        if idx <= 0:
            self._start_new_chat()
        else:
            conv = self.recent_conversations[idx - 1]
            self.select_conversation(conv)

    def select_conversation(self, conv):
        """Активация выбранного диалога и загрузка его истории."""
        if not conv:
            return
        self.conversation_id = conv["id"]
        self.lbl_conv_id.config(text=f"Диалог: {conv['short_id']}")

        if conv.get("workspace") and os.path.isdir(conv["workspace"]):
            self.var_workspace.set(conv["workspace"])

        self.txt_chat.delete("1.0", tk.END)
        self._append_chat(f"⏳ Загрузка диалога: {conv.get('title', conv['id'])}...\nСчитывание истории и форматирование сообщений...\n\n", "system")
        self.lbl_status_text.config(text="Загрузка диалога...")
        self.lbl_status_dot.config(fg="#FFA500")

        conv_id = conv["id"]
        def _load_worker():
            history_items = load_conversation_transcript(conv_id)
            self.after(0, lambda: self._apply_loaded_transcript(conv_id, history_items))

        threading.Thread(target=_load_worker, daemon=True).start()

    def _apply_loaded_transcript(self, conv_id, history_items):
        """Отрисовка загруженной истории сообщений диалога."""
        if self.conversation_id != conv_id:
            return
        self.txt_chat.delete("1.0", tk.END)
        if history_items:
            for item in history_items:
                tag = item[0]
                val = item[1]
                if tag == "tool_group":
                    card = CollapsibleToolCard(self.txt_chat)
                    for tc in val:
                        tname = tc.get("name", "tool") if isinstance(tc, dict) else str(tc)
                        summary = tc.get("summary", "") if isinstance(tc, dict) else ""
                        disp = f"{tname} ({summary})" if summary else tname
                        card.add_done(disp, 0.0)
                    card.finalize()
                    self.txt_chat.window_create(tk.END, window=card)
                    self.txt_chat.insert(tk.END, "\n")
                elif tag == "system_card":
                    card = CollapsibleSystemMessageCard(self.txt_chat, summary=val.get("summary", ""), body=val.get("body", ""))
                    self.txt_chat.window_create(tk.END, window=card)
                    self.txt_chat.insert(tk.END, "\n")
                elif tag in ("user_text", "agent_text"):
                    self._append_markdown(val, tag)
                else:
                    self._append_chat(val, tag)
        else:
            self._append_chat(f"\n[ИНФО] Выбран диалог: {conv_id}\n\n", "system")

        self.txt_chat.see(tk.END)
        self.after(50, lambda: self.txt_chat.yview_moveto(1.0))
        self.lbl_status_text.config(text="Диалог загружен, готов к продолжению")
        self.lbl_status_dot.config(fg="#4CAF50")
        self._refresh_conversations_combo()
        self._update_context_display(conv_id=conv_id)

    def _open_conversations_dialog(self):
        """Открытие модального окна со списком разговоров."""
        ConversationHistoryDialog(self, on_select_callback=self.select_conversation)

    def _apply_zoom(self, new_size, save=True):
        """Применение нового размера шрифта и сохранение в конфигурацию."""
        self.current_font_size = max(self.min_font_size, min(self.max_font_size, new_size))
        self.txt_chat.configure(font=("Consolas", self.current_font_size))
        self.txt_prompt.configure(font=("Segoe UI", self.current_font_size))
        self.txt_chat.tag_configure("user_header", font=("Consolas", self.current_font_size, "bold"))
        self.txt_chat.tag_configure("user_text", font=("Consolas", self.current_font_size))
        self.txt_chat.tag_configure("badge", font=("Consolas", self.current_font_size))
        self.txt_chat.tag_configure("agent_header", font=("Consolas", self.current_font_size, "bold"))
        self.txt_chat.tag_configure("agent_text", font=("Consolas", self.current_font_size))
        self.txt_chat.tag_configure("tool_start", font=("Consolas", max(self.min_font_size, self.current_font_size - 1), "italic"))
        self.txt_chat.tag_configure("tool_done", font=("Consolas", max(self.min_font_size, self.current_font_size - 1)))
        self.txt_chat.tag_configure("system", font=("Consolas", max(self.min_font_size, self.current_font_size - 1)))
        self.txt_chat.tag_configure("banner", font=("Consolas", self.current_font_size))
        self.txt_chat.tag_configure("error", font=("Consolas", self.current_font_size, "bold"))
        self.txt_chat.tag_configure("user", font=("Consolas", self.current_font_size, "bold"))
        self.txt_chat.tag_configure("agent", font=("Consolas", self.current_font_size, "bold"))
        self.txt_chat.tag_configure("tool", font=("Consolas", max(self.min_font_size, self.current_font_size - 1), "italic"))
        self.txt_chat.tag_configure("md_bold", font=("Consolas", self.current_font_size, "bold"))
        self.txt_chat.tag_configure("md_italic", font=("Consolas", self.current_font_size, "italic"))
        self.txt_chat.tag_configure("md_bolditalic", font=("Consolas", self.current_font_size, "bold italic"))
        self.txt_chat.tag_configure("md_code", font=("Consolas", self.current_font_size))
        self.txt_chat.tag_configure("md_codeblock", font=("Consolas", max(self.min_font_size, self.current_font_size - 1)))
        self.txt_chat.tag_configure("md_h1", font=("Consolas", self.current_font_size + 4, "bold"))
        self.txt_chat.tag_configure("md_h2", font=("Consolas", self.current_font_size + 2, "bold"))
        self.txt_chat.tag_configure("md_h3", font=("Consolas", self.current_font_size + 1, "bold"))
        self.txt_chat.tag_configure("md_bullet", font=("Consolas", self.current_font_size, "bold"))
        self.txt_chat.tag_configure("md_quote", font=("Consolas", self.current_font_size, "italic"))
        pct = round((self.current_font_size / self.default_font_size) * 100)
        if hasattr(self, "lbl_zoom"):
            self.lbl_zoom.configure(text=f"🔍 {pct}% ({self.current_font_size}pt)")
        if save:
            save_launcher_config({"fontSize": self.current_font_size})

    def _zoom_in(self):
        self._apply_zoom(self.current_font_size + 1)

    def _zoom_out(self):
        self._apply_zoom(self.current_font_size - 1)

    def _zoom_reset(self):
        self._apply_zoom(self.default_font_size)

    def _on_mouse_wheel(self, event):
        """Обработка масштабирования при зажатой клавише Control."""
        if event.state & 4:
            if event.delta > 0:
                self._zoom_in()
            elif event.delta < 0:
                self._zoom_out()
            return "break"

    def _populate_projects(self):
        """Заполнение списка проектов."""
        project_names = ["— Быстрый выбор проекта —"]
        if os.path.isdir(self.default_workspace):
            try:
                for entry in os.scandir(self.default_workspace):
                    if entry.is_dir() and not entry.name.startswith(".") and entry.name != "AntigravityLauncher":
                        project_names.append(entry.name)
            except Exception:
                pass
        self.cmb_projects["values"] = project_names
        self.cmb_projects.current(0)

    def _on_project_selected(self, event=None):
        sel = self.var_project_choice.get()
        if sel and sel != "— Быстрый выбор проекта —":
            target = os.path.join(self.default_workspace, sel)
            if os.path.isdir(target):
                self.var_workspace.set(target)

    def _browse_workspace(self):
        init_dir = self.var_workspace.get() if os.path.isdir(self.var_workspace.get()) else self.default_workspace
        chosen = filedialog.askdirectory(initialdir=init_dir, title="Выберите рабочую папку проекта")
        if chosen:
            self.var_workspace.set(chosen)

    def _start_new_chat(self):
        """Сброс сессии диалога."""
        if self.active_tool_card:
            self.active_tool_card.finalize()
            self.active_tool_card = None
        self.conversation_id = None
        self.lbl_conv_id.config(text="Диалог: Новый")
        self._update_context_display(conv_id=None)
        self.txt_chat.delete("1.0", tk.END)
        self._append_chat(self.welcome_text, "system")
        self._append_chat("--- [Новый диалог начат] ---\n\n", "system")
        self.suppress_conv_event = True
        try:
            self.cmb_conversations.current(0)
        finally:
            self.suppress_conv_event = False

    def _clear_chat(self):
        if self.active_tool_card:
            self.active_tool_card.finalize()
            self.active_tool_card = None
        self.txt_chat.delete("1.0", tk.END)

    def _launch_terminal_tui(self):
        """Запуск полноценной TUI-консоли agy в отдельном окне."""
        ws = self.var_workspace.get()
        model = self.var_model.get()
        mode = self.var_mode.get()
        effort = self.var_effort.get()
        effort_arg = f'--effort "{effort}"' if effort != "auto" else ""
        skip = "--dangerously-skip-permissions" if self.var_skip_perms.get() else ""
        conv_arg = f'--conversation "{self.conversation_id}"' if self.conversation_id else ""

        if sys.platform == "win32":
            cmd = f'cd /d "{ws}" && "{self.agy_path}" --model "{model}" --mode "{mode}" {effort_arg} {skip} {conv_arg}'
            subprocess.Popen(f'start cmd /k "{cmd}"', shell=True)
        else:
            args = [self.agy_path, "--model", model, "--mode", mode]
            if effort != "auto":
                args.extend(["--effort", effort])
            if self.conversation_id:
                args.extend(["--conversation", self.conversation_id])
            subprocess.Popen(args, cwd=ws)

    def _append_chat(self, text, tag=None):
        if tag:
            self.txt_chat.insert(tk.END, text, tag)
        else:
            self.txt_chat.insert(tk.END, text)
        self.txt_chat.see(tk.END)

    def _append_markdown(self, text, base_tag="agent_text"):
        """Построчный рендеринг базовой Markdown-разметки в Tkinter Text."""
        if not text:
            return
        lines = text.splitlines()
        in_code_block = False
        code_lines = []
        code_lang = ""

        pattern = re.compile(
            r'(?P<codeblock>`[^`\r\n]+`)|'
            r'(?P<bolditalic>\*\*\*[^*]+?\*\*\*|___[^_]+?___)|'
            r'(?P<bold>\*\*[^*]+?\*\*|__[^_]+?__)|'
            r'(?P<italic>\*[^*]+?\*|(?<=\s|^)_[^_]+?_(?=\s|$|[.,!?:;]))|'
            r'(?P<strike>~~[^~]+?~~)'
        )

        for line in lines:
            if line.startswith("```"):
                if not in_code_block:
                    in_code_block = True
                    code_lang = line[3:].strip()
                    code_lines = []
                    continue
                else:
                    in_code_block = False
                    lang_label = f"--- [{code_lang or 'code'}] ---\n"
                    self.txt_chat.insert(tk.END, lang_label, "banner")
                    code_str = "\n".join(code_lines) + "\n"
                    self.txt_chat.insert(tk.END, code_str, "md_codeblock")
                    self.txt_chat.insert(tk.END, "------------------------\n", "banner")
                    continue

            if in_code_block:
                code_lines.append(line)
                continue

            if re.match(r'^(---|___|\*\*\*)\s*$', line):
                self.txt_chat.insert(tk.END, "--------------------------------------------------------------------------------\n", "md_hr")
                continue

            h_match = re.match(r'^(#{1,6})\s+(.*)$', line)
            if h_match:
                level = len(h_match.group(1))
                h_text = h_match.group(2) + "\n"
                tag = "md_h1" if level == 1 else ("md_h2" if level == 2 else "md_h3")
                self.txt_chat.insert(tk.END, h_text, tag)
                continue

            q_match = re.match(r'^>\s?(.*)$', line)
            if q_match:
                q_text = "  ▎ " + q_match.group(1) + "\n"
                self.txt_chat.insert(tk.END, q_text, "md_quote")
                continue

            b_match = re.match(r'^(\s*)([-*+])\s+(.*)$', line)
            if b_match:
                indent = b_match.group(1)
                b_text = b_match.group(3)
                self.txt_chat.insert(tk.END, f"{indent}  • ", "md_bullet")
                self._insert_inlines(b_text, base_tag, pattern)
                self.txt_chat.insert(tk.END, "\n")
                continue

            n_match = re.match(r'^(\s*)(\d+)\.\s+(.*)$', line)
            if n_match:
                indent = n_match.group(1)
                num = n_match.group(2)
                n_text = n_match.group(3)
                self.txt_chat.insert(tk.END, f"{indent}  {num}. ", "md_bullet")
                self._insert_inlines(n_text, base_tag, pattern)
                self.txt_chat.insert(tk.END, "\n")
                continue

            if not line.strip():
                self.txt_chat.insert(tk.END, "\n")
                continue

            self._insert_inlines(line, base_tag, pattern)
            self.txt_chat.insert(tk.END, "\n")

        if in_code_block and code_lines:
            self.txt_chat.insert(tk.END, "\n".join(code_lines) + "\n", "md_codeblock")

        self.txt_chat.see(tk.END)

    def _insert_inlines(self, line_text, base_tag, pattern):
        last_idx = 0
        for m in pattern.finditer(line_text):
            if m.start() > last_idx:
                self.txt_chat.insert(tk.END, line_text[last_idx:m.start()], base_tag)
            val = m.group(0)
            if m.group("codeblock"):
                self.txt_chat.insert(tk.END, f" {val[1:-1]} ", "md_code")
            elif m.group("bolditalic"):
                self.txt_chat.insert(tk.END, val[3:-3], "md_bolditalic")
            elif m.group("bold"):
                self.txt_chat.insert(tk.END, val[2:-2], "md_bold")
            elif m.group("italic"):
                self.txt_chat.insert(tk.END, val[1:-1], "md_italic")
            elif m.group("strike"):
                self.txt_chat.insert(tk.END, val[2:-2], base_tag)
            last_idx = m.end()
        if last_idx < len(line_text):
            self.txt_chat.insert(tk.END, line_text[last_idx:], base_tag)

    def _get_attachments_dir(self):
        """Папка для сохранения скриншотов и вложений."""
        ws = self.var_workspace.get().strip()
        if os.path.isdir(ws):
            target = os.path.join(ws, ".antigravity", "attachments")
        else:
            target = os.path.join(os.path.dirname(os.path.abspath(__file__)), "attachments")
        os.makedirs(target, exist_ok=True)
        return target

    def _save_clipboard_image(self):
        """Сохранение изображения из буфера обмена Windows через PowerShell."""
        target_dir = self._get_attachments_dir()
        ts = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
        import random
        rand = random.randint(100, 999)
        dest = os.path.join(target_dir, f"screenshot_{ts}_{rand}.png")

        ps_cmd = f"Add-Type -AssemblyName System.Windows.Forms, System.Drawing; $img = [System.Windows.Forms.Clipboard]::GetImage(); if ($img) {{ $img.Save('{dest}', [System.Drawing.Imaging.ImageFormat]::Png); exit 0 }} else {{ exit 1 }}"
        try:
            res = subprocess.run(["powershell.exe", "-NoProfile", "-Command", ps_cmd], capture_output=True, timeout=5)
            if res.returncode == 0 and os.path.isfile(dest):
                return dest
        except Exception:
            pass
        return None

    def _pick_image_files(self):
        """Выбор файлов изображений через диалог."""
        files = filedialog.askopenfilenames(
            title="Выберите изображения",
            filetypes=[
                ("Изображения", "*.png;*.jpg;*.jpeg;*.webp;*.bmp;*.gif"),
                ("Все файлы", "*.*")
            ]
        )
        if files:
            for f in files:
                self._add_attached_file(f)
            self.txt_prompt.focus_set()

    def _add_attached_file(self, file_path):
        """Добавление файла в список вложений."""
        if not os.path.isfile(file_path):
            return
        ext = os.path.splitext(file_path)[1].lower()
        if ext not in [".png", ".jpg", ".jpeg", ".webp", ".bmp", ".gif"]:
            return

        fn = os.path.basename(file_path)
        sz_kb = round(os.path.getsize(file_path) / 1024)
        self.attached_images.append({
            "path": os.path.abspath(file_path),
            "name": fn,
            "info": f"{fn} ({sz_kb} KB)"
        })
        self._render_attachments()

    def _on_paste_event(self, event=None):
        """Обработка Ctrl+V: проверка наличия изображения в буфере обмена."""
        saved_img = self._save_clipboard_image()
        if saved_img:
            self._add_attached_file(saved_img)
            return "break"
        return None

    def _render_attachments(self):
        """Отрисовка панели прикрепленных изображений."""
        for widget in self.frame_attachments_list.winfo_children():
            widget.destroy()

        if not self.attached_images:
            self.frame_attachments.pack_forget()
            return

        self.frame_attachments.pack(fill=tk.X, pady=(0, 6), before=self.txt_prompt.master)

        for idx, item in enumerate(self.attached_images):
            card = tk.Frame(self.frame_attachments_list, bg="#252A30", bd=1, relief=tk.SOLID, padx=6, pady=4)
            card.pack(side=tk.LEFT, padx=(0, 6))

            lbl = tk.Label(card, text=f"🖼️ {item['info']}", fg="#E6EDF3", bg="#252A30", font=("Segoe UI", 9))
            lbl.pack(side=tk.LEFT, padx=(0, 4))

            btn_del = tk.Button(
                card,
                text="✖",
                fg="#F85149",
                bg="#252A30",
                bd=0,
                cursor="hand2",
                font=("Segoe UI", 9, "bold"),
                command=lambda i=idx: self._remove_attachment(i)
            )
            btn_del.pack(side=tk.LEFT)

    def _remove_attachment(self, idx):
        if 0 <= idx < len(self.attached_images):
            self.attached_images.pop(idx)
            self._render_attachments()

    def _clear_attachments(self):
        self.attached_images.clear()
        self._render_attachments()

    def _on_enter_pressed(self, event):
        if event.state & 0x0001:
            return None
        self.send_prompt()
        return "break"

    def send_prompt(self):
        """Отправка промпта агенту."""
        prompt = self.txt_prompt.get("1.0", tk.END).strip()
        has_attachments = len(self.attached_images) > 0
        if (not prompt and not has_attachments) or self.is_running:
            return

        if not prompt and has_attachments:
            prompt = "Пожалуйста, проанализируй прикрепленное изображение."

        ws = self.var_workspace.get().strip()
        if not os.path.isdir(ws):
            messagebox.showerror("Ошибка", f"Указанная рабочая папка не существует:\n{ws}")
            return

        if not os.path.isfile(self.agy_path):
            messagebox.showerror("Ошибка", f"Исполняемый файл agy.exe не найден:\n{self.agy_path}")
            return

        self.last_sent_prompt = prompt
        self.txt_prompt.delete("1.0", tk.END)

        full_prompt = prompt
        img_badge = ""
        if has_attachments:
            img_lines = ["[Прикрепленные изображения:"]
            for img in self.attached_images:
                p = img["path"].replace("\\", "/")
                img_lines.append(f" - file:///{p}")
            img_lines.append("]")
            img_lines.append("Внимание агенту: обязательно изучи прикрепленные изображения по указанным путям с помощью инструмента read_file.")
            full_prompt = "\n".join(img_lines) + "\n\n" + prompt

            badges = ", ".join(f"🖼️ {img['name']}" for img in self.attached_images)
            img_badge = f"[{badges}]"
            self._clear_attachments()

        if self.active_tool_card:
            self.active_tool_card.finalize()
            self.active_tool_card = None

        time_str = datetime.datetime.now().strftime("%H:%M:%S")
        self._append_chat(f"\n[Вы ({time_str})]: ", "user_header")
        if img_badge:
            self._append_chat(f"{img_badge} ", "badge")
        self._append_markdown(f"{prompt}\n\n", "user_text")
        self._append_chat("[Antigravity]:\n", "agent_header")
        
        self.is_running = True
        self.btn_send.config(state=tk.DISABLED)
        self.btn_stop.config(state=tk.NORMAL)
        self.lbl_status_dot.config(fg="#FFA000")
        self.lbl_status_text.config(text="Агент думает и выполняет задачи...")

        worker = threading.Thread(
            target=self._run_agent_thread,
            args=(full_prompt, ws, self.var_model.get(), self.var_mode.get(), self.var_effort.get(), self.var_skip_perms.get(), self.conversation_id),
            daemon=True
        )
        worker.start()

    def _run_agent_thread(self, prompt, workspace, model, mode, effort, skip_perms, conv_id):
        """Фоновый рабочий поток запуска agy.exe и чтения NDJSON."""
        try:
            cmd = [
                self.agy_path,
                "-p", prompt,
                "--output-format", "stream-json",
                "--model", model,
                "--mode", mode
            ]
            if effort and effort != "auto":
                cmd.extend(["--effort", effort])
            if skip_perms:
                cmd.append("--dangerously-skip-permissions")
            if conv_id:
                cmd.extend(["--conversation", conv_id])

            startupinfo = None
            if sys.platform == "win32":
                startupinfo = subprocess.STARTUPINFO()
                startupinfo.dwFlags |= subprocess.STARTF_USESHOWWINDOW

            proc = subprocess.Popen(
                cmd,
                cwd=workspace,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                encoding="utf-8",
                errors="replace",
                startupinfo=startupinfo,
                bufsize=1
            )
            self.current_process = proc

            # Асинхронный дренаж stderr в фоновом потоке во избежание переполнения системного буфера pipe (Deadlock)
            err_chunks = []
            def _drain_stderr():
                try:
                    for eline in iter(proc.stderr.readline, ""):
                        if eline:
                            err_chunks.append(eline)
                except Exception:
                    pass

            stderr_thread = threading.Thread(target=_drain_stderr, daemon=True)
            stderr_thread.start()

            turn_finished = False
            for line in iter(proc.stdout.readline, ""):
                if not line:
                    break
                line = line.strip()
                if not line:
                    continue
                try:
                    data = json.loads(line)
                    evt = data.get("event")
                    if evt == "init":
                        cid = data.get("conversation_id")
                        if cid:
                            self.event_queue.put(("conversation_id", cid))
                    elif evt == "step_update":
                        su = data.get("step_update", {})
                        stype = su.get("step_type")
                        if stype == "agent_response":
                            delta = su.get("text_delta")
                            if delta:
                                self.event_queue.put(("token", delta))
                        elif stype == "tool":
                            state = su.get("state")
                            tname = su.get("tool_name", "unknown")
                            if state == "ACTIVE":
                                self.event_queue.put(("tool_start", tname))
                            elif state == "DONE":
                                dur = round(float(su.get("duration_seconds", 0.0)), 2)
                                self.event_queue.put(("tool_done", (tname, dur)))
                    elif evt == "result":
                        res = data.get("result", {})
                        cid = res.get("conversation_id")
                        if cid:
                            self.event_queue.put(("conversation_id", cid))
                        turn_finished = True
                        break
                except Exception:
                    self.event_queue.put(("token", line + "\n"))

            try:
                proc.stdout.close()
            except Exception:
                pass

            try:
                ret_code = proc.wait(timeout=1.5)
            except Exception:
                try:
                    if os.name == 'nt':
                        subprocess.run(["taskkill", "/PID", str(proc.pid), "/T", "/F"], capture_output=True)
                    proc.kill()
                except Exception:
                    pass
                ret_code = 0

            stderr_thread.join(timeout=0.5)
            err_out = "".join(err_chunks).strip()
            try:
                proc.stderr.close()
            except Exception:
                pass

            if turn_finished:
                self.event_queue.put(("done", None))
            elif ret_code != 0 and err_out:
                self.event_queue.put(("error", err_out))
            else:
                self.event_queue.put(("done", None))

        except Exception as e:
            self.event_queue.put(("error", str(e)))
        finally:
            self.current_process = None

    def stop_execution(self):
        """Остановка запущенного процесса agy.exe и всех его дочерних процессов."""
        if self.current_process:
            try:
                if os.name == 'nt':
                    subprocess.run(["taskkill", "/PID", str(self.current_process.pid), "/T", "/F"], capture_output=True)
                self.current_process.terminate()
                self.event_queue.put(("system", "\n[Процесс принудительно остановлен пользователем]\n"))
                self.event_queue.put(("done", None))
            except Exception as e:
                self.event_queue.put(("error", f"Ошибка остановки: {e}"))

    def _check_queue_loop(self):
        """Периодическая обработка событий из фонового потока."""
        try:
            while True:
                evt_type, payload = self.event_queue.get_nowait()
                if evt_type == "token":
                    if self.active_tool_card:
                        self.active_tool_card.finalize()
                        self.active_tool_card = None
                    self._append_chat(payload, "agent_text")
                elif evt_type == "tool_start":
                    if not self.active_tool_card:
                        self.active_tool_card = CollapsibleToolCard(self.txt_chat)
                        self.txt_chat.window_create(tk.END, window=self.active_tool_card)
                        self.txt_chat.insert(tk.END, "\n")
                    self.active_tool_card.add_start(payload)
                    self.txt_chat.see(tk.END)
                elif evt_type == "tool_done":
                    tname, dur = payload
                    if not self.active_tool_card:
                        self.active_tool_card = CollapsibleToolCard(self.txt_chat)
                        self.txt_chat.window_create(tk.END, window=self.active_tool_card)
                        self.txt_chat.insert(tk.END, "\n")
                    self.active_tool_card.add_done(tname, dur)
                    self.txt_chat.see(tk.END)
                elif evt_type == "system":
                    if self.active_tool_card:
                        self.active_tool_card.finalize()
                        self.active_tool_card = None
                    if payload and ("<SYSTEM_MESSAGE>" in payload or "SYSTEM_MESSAGE" in payload):
                        sys_list = parse_system_message_text(payload)
                        for sm in sys_list:
                            card = CollapsibleSystemMessageCard(self.txt_chat, summary=sm["summary"], body=sm["body"])
                            self.txt_chat.window_create(tk.END, window=card)
                            self.txt_chat.insert(tk.END, "\n")
                    else:
                        self._append_chat(f"\n[ИНФО] {payload}\n", "system")
                elif evt_type == "conversation_id":
                    self.conversation_id = payload
                    short_id = payload[:12] + "..." if len(payload) > 12 else payload
                    self.lbl_conv_id.config(text=f"Диалог: {short_id}")
                    save_session_metadata(payload, self.var_workspace.get(), self.last_sent_prompt)
                    self._refresh_conversations_combo()
                elif evt_type == "done":
                    if self.active_tool_card:
                        self.active_tool_card.finalize()
                        self.active_tool_card = None
                    self.is_running = False
                    self.btn_send.config(state=tk.NORMAL)
                    self.btn_stop.config(state=tk.DISABLED)
                    self.lbl_status_dot.config(fg="#4CAF50")
                    self.lbl_status_text.config(text="Готов к работе")
                    self._append_chat("\n\n")
                    self._update_context_display()
                    self.txt_prompt.focus()
                elif evt_type == "error":
                    if self.active_tool_card:
                        self.active_tool_card.finalize()
                        self.active_tool_card = None
                    self.is_running = False
                    self._append_chat(f"\n❌ [ОШИБКА]: {payload}\n\n", "error")
                    self.btn_send.config(state=tk.NORMAL)
                    self.btn_stop.config(state=tk.DISABLED)
                    self.lbl_status_dot.config(fg="#F44336")
                    self.lbl_status_text.config(text="Ошибка выполнения")
        except queue.Empty:
            pass

        self.after(40, self._check_queue_loop)


if __name__ == "__main__":
    app = AntigravityGUI()
    app.mainloop()
