# Plan: Streaming stdout/stderr in Runbook Execution UI

## Executive Summary

This document outlines options and recommendations for implementing continuous streaming of standard output and standard error in the runbook execution UI, and for addressing the timeout issue with long-running tasks. The goal is to preserve the current solid design while adding minimal complexity.

---

## Current State

### Architecture Overview

- **API** (`stage0_runbook_api`): Flask + Gunicorn (gevent workers). POST `/api/runbooks/{filename}/execute` is **synchronous**—it blocks until the script completes, then returns a JSON response with `stdout`, `stderr`, `return_code`, etc.
- **Script Executor**: Uses `subprocess.run(capture_output=True)`—all output is buffered until the process exits.
- **SPA** (`stage0_runbook_spa`): Execute dialog collects env vars, calls `api.executeRunbook()`, and on success/error closes the dialog and refetches runbook content to show the history section. **No live output is displayed during execution.**

### Root Cause of Timeout

1. **HTTP layer**: The execute request holds the connection open for the entire script duration. Timeouts can occur at:
   - **Nginx proxy** (SPA container): Default `proxy_read_timeout` is 60s; no explicit override in `nginx.conf.template`
   - **Gunicorn**: Default worker timeout is 30s (configurable)
   - **Browser fetch**: No explicit timeout; relies on underlying TCP/HTTP stack

2. **User experience**: When a timeout occurs, the SPA may surface an error or incomplete state. The API continues running the script in the background. When it finishes, the runbook file is updated with history. The user sees stale content until they manually refresh.

3. **Design gap**: The execute dialog does not show stdout/stderr at all—it only collects env vars and shows a loading spinner. Output appears only in the runbook history after completion.

---

## Options

### Option A: Server-Sent Events (SSE) with Streaming Execute

**Approach**: Add a streaming mode to the execute flow. When the client requests streaming (e.g., via `Accept: text/event-stream` or `?stream=true`), the API uses `subprocess.Popen` instead of `subprocess.run`, reads stdout/stderr as they become available, and streams SSE events over the same HTTP response.

**Flow**:
1. SPA: POST `/execute` with `Accept: text/event-stream` (or `?stream=true`)
2. API: Starts execution, returns `200` with `Content-Type: text/event-stream`, streams events:
   - `stdout: <chunk>`
   - `stderr: <chunk>`
   - `done: {"return_code": 0, "success": true}` (final event)
3. SPA: Uses `fetch` + `ReadableStream` or `EventSource`-like parsing to consume events and append to a live log in the dialog

**Pros**:
- True real-time streaming
- Single request/response; no new endpoints
- SSE is HTTP-based, works with existing proxies (with `proxy_buffering off` for nginx)
- Backward compatible: clients that don’t request streaming get the existing synchronous behavior

**Cons**:
- Requires API changes: streaming mode in script executor, generator/streaming response in Flask
- Nginx must be configured for streaming (`proxy_buffering off`, `proxy_read_timeout` increased for long runs)
- SPA needs new logic to handle streaming and display live output

**Complexity**: Medium

---

### Option B: Start + Poll (Async Execute with Status Endpoint)

**Approach**: Split into two phases: (1) start execution and return immediately with an execution ID; (2) poll a status endpoint for progress and final result.

**Flow**:
1. SPA: POST `/execute` → API returns `202 Accepted` with `execution_id`
2. API: Runs script in background (thread/worker), writes stdout/stderr to a temp file or in-memory buffer
3. SPA: Polls GET `/execute/{execution_id}/status` every 500ms–1s
4. Status response: `{ "status": "running"|"completed"|"failed", "stdout": "...", "stderr": "...", "return_code": null|int }`
5. On `completed`/`failed`, stop polling and close dialog

**Pros**:
- No streaming protocol; simple HTTP GET
- Avoids long-lived connections; no proxy timeout for the execute request
- Easier to implement than true streaming
- Works with all proxies and load balancers

**Cons**:
- Not true streaming—updates are batched by poll interval
- Requires execution state storage (in-memory dict keyed by `execution_id`, or Redis for multi-worker)
- New endpoints and execution lifecycle (cleanup of stale executions)
- Sub-runbook calls (curl) would need to change to support async (or keep sync path for non-UI clients)

**Complexity**: Medium–High (state management, cleanup)

---

### Option C: WebSockets

**Approach**: Use WebSockets for bidirectional communication. Client connects, sends execute request, receives stdout/stderr chunks over the socket.

**Pros**:
- Real-time, low latency
- Full duplex if needed later

**Cons**:
- New protocol and infrastructure
- More complex than SSE for one-way streaming
- Requires WebSocket support in nginx and possibly different deployment considerations
- Overkill for this use case

**Complexity**: High

---

### Option D: Chunked Transfer Encoding (Streaming JSON Lines)

**Approach**: Similar to Option A, but stream newline-delimited JSON (NDJSON) instead of SSE. Response is `Transfer-Encoding: chunked` with `Content-Type: application/x-ndjson`.

**Pros**:
- Simple format
- Single request
- Works with standard HTTP

**Cons**:
- Less standard than SSE for event streams
- Client must parse line-by-line
- Same proxy/nginx considerations as Option A

**Complexity**: Medium (similar to Option A)

---

### Option E: Minimal Change—Extend Timeouts + Show Output in Dialog After Completion

**Approach**: Do not add streaming. Instead:
1. Increase nginx `proxy_read_timeout` and Gunicorn `worker_timeout` for long-running scripts
2. Keep the execute dialog open until the request completes (no change)
3. On success/error, show stdout/stderr in the dialog before closing (or in an expandable section) instead of only in history

**Pros**:
- Minimal code changes
- No new protocols or endpoints
- Fixes the “no output in dialog” gap for short/medium runs

**Cons**:
- Does not fix timeout for very long runs (e.g., hours)—timeouts would need to be set impractically high
- No live streaming; user still waits with a spinner
- May hit limits of proxies/load balancers in some environments

**Complexity**: Low

---

## Recommendation

**Primary recommendation: Option A (SSE with streaming execute)**

Reasons:
1. **Aligns with the goal**: Continuous stream of stdout/stderr in the UI.
2. **Keeps the design simple**: One execute endpoint, optional streaming via `Accept` header or query param. Non-streaming clients (curl, sub-runbooks) keep current behavior.
3. **Fits the stack**: Gunicorn with gevent supports streaming responses; Flask can yield or use `Response(stream_with_context(...))`.
4. **Avoids timeout**: The response body is streamed, so the connection stays active as long as data flows. Proxies typically allow this with `proxy_buffering off`.
5. **Reasonable scope**: Script executor gains a streaming mode; route and SPA gain streaming handling. No new services or state stores.

**Fallback / phased approach**:
- **Phase 1**: Implement Option E (extend timeouts, show stdout/stderr in dialog on completion). Quick win, improves UX for typical runs.
- **Phase 2**: Implement Option A for true streaming. Option E’s dialog changes (showing output) can be reused and extended for live updates.

---

## Implementation Outline for Option A

### 1. API Changes

| Component | Change |
|-----------|--------|
| `script_executor.py` | Add `execute_script_streaming()` that uses `subprocess.Popen`, reads stdout/stderr via threads or `select`, and yields `(stream, chunk)` tuples |
| `runbook_service.py` | Add `execute_runbook_streaming()` that orchestrates validation, calls streaming executor, and yields SSE events |
| `runbook_routes.py` | When `Accept: text/event-stream` or `?stream=true`, return `Response(stream_with_context(...), mimetype='text/event-stream')` |
| `Config` | Optional: `EXECUTION_STREAMING_ENABLED` (default true) |

**SSE event format** (example):
```
event: stdout
data: <chunk, base64 or escaped>

event: stderr
data: <chunk>

event: done
data: {"return_code": 0, "success": true}
```

### 2. SPA Changes

| Component | Change |
|-----------|--------|
| `api/client.ts` | Add `executeRunbookStreaming(filename, envVars, onChunk)` that uses `fetch` with `Accept: text/event-stream`, reads `response.body` as a stream, parses SSE, and invokes `onChunk` for each event |
| `RunbookViewerPage.vue` | Extend execute dialog: add a scrollable log area (e.g., `<pre>`) that shows live stdout/stderr. When streaming, keep dialog open and append chunks; on `done` event, show final status and allow close |
| Execute flow | Use streaming when available (e.g., feature flag or always for UI). Fall back to non-streaming `executeRunbook` if streaming fails or is not supported |

### 3. Infrastructure

| Component | Change |
|-----------|--------|
| `nginx.conf.template` | For `/api/` (or a dedicated `/api/runbooks/.../execute` location): `proxy_buffering off; proxy_read_timeout 3600s;` (or similar) to support long-lived streaming |
| Gunicorn | Ensure `--timeout` is high enough for long scripts, or use a separate timeout for streaming requests |

### 4. Backward Compatibility

- **curl / sub-runbooks**: Do not send `Accept: text/event-stream`. They receive the existing synchronous JSON response.
- **OpenAPI**: Document the optional `Accept: text/event-stream` and the streaming response format. The primary contract remains the synchronous JSON response.

---

## Summary Table

| Option | Streaming | Timeout Fix | Complexity | Backward Compatible |
|--------|-----------|-------------|------------|----------------------|
| A: SSE | Yes | Yes | Medium | Yes |
| B: Poll | Quasi (poll interval) | Yes | Medium–High | Requires sync path for curl |
| C: WebSockets | Yes | Yes | High | New endpoint |
| D: NDJSON | Yes | Yes | Medium | Yes |
| E: Timeouts + output in dialog | No | Partial | Low | Yes |

**Recommended path**: Option A, with Option E as an optional Phase 1 if you want a quick improvement before full streaming.
