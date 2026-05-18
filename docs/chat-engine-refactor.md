# Chat Engine Refactor

## Goal

Move the chat runtime out of `lib/page/chat_page.dart` into a dedicated local-first messaging engine.

## Target Architecture

1. `ChatSessionTarget`
   Identifies a chat session by conversation id, product id, or user id.

2. `ChatSessionController`
   Orchestrates bootstrap, local-store hydration, realtime binding, polling fallback, and incremental state updates.

3. `ChatSessionState`
   Immutable runtime state consumed by the UI.

4. `ChatPage`
   Renders the state and emits user intents. It should stop owning synchronization rules.

## Migration Strategy

### Phase 1

- Introduce the reusable controller and state outside `chat_page`.
- Keep `chat_page` behavior unchanged while extracting orchestration logic.

### Phase 2

- Rewire `chat_page` to listen to `ChatSessionController`.
- Remove duplicate local-store and realtime subscriptions from the widget.
- Move initial load, reconnect, silent refresh, and pending-outbox sync into the controller.

### Phase 3

- Extract send, edit, delete, read, and delivery mutations into a dedicated command layer.
- Convert private `_ChatMessage` parsing into reusable public mappers.
- Add a single viewport policy component for pinned-bottom behavior.

### Phase 4

- Reduce polling to a low-frequency recovery path.
- Replace snapshot-oriented reconnects with cursor-based incremental sync when backend support exists.

## Non Goals For Phase 1

- No UI redesign.
- No backend protocol rewrite.
- No removal of existing `chat_page` code until the extracted controller fully covers the same behavior.

## Immediate Next Step

Wire `chat_page` to the new controller for bootstrap, local-store updates, realtime updates, and refresh. Keep message rendering as-is for the first migration pass.

## Maturity Roadmap

The current refactor improves architecture, but it does not yet put the messaging stack at the level of WhatsApp, Discord, or Teams. The roadmap below defines the next maturity targets.

### Stage 1: Reliable Core Runtime

- Solid offline guarantees and reliable resume after connection loss.
- Complete conflict handling and deterministic message ordering.
- Robust multi-device synchronization behavior.
- Delivery, seen, and typing pipeline validated under load.

Target outcome:
The engine behaves predictably across reconnects, duplicate events, delayed acknowledgements, and concurrent device activity.

### Stage 2: Runtime Validation In Real Conditions

- Pagination, cache behavior, scroll restoration, and uploads validated on real devices.
- Retry policies, recovery paths, and error handling formalized.
- Observability added for chat runtime, upload lifecycle, and sync failures.
- Logs and metrics added for reconnect loops, message duplication, ordering drift, and failed acknowledgements.

Target outcome:
Failures become diagnosable and recoverable instead of silent or UI-only issues.

### Stage 3: Backend Hardening And Verification

- Backend flows hardened for reconnect, duplication, idempotency, and event ordering.
- End-to-end tests added for send, edit, delete, seen, delivery, typing, uploads, and reconnect scenarios.
- Contract verification added between frontend state transitions and backend conversation snapshots.

Target outcome:
The backend becomes a stable synchronization authority rather than a best-effort transport layer.

### Stage 4: Scale And Performance

- Performance and stability validated on large conversations and heavy media traffic.
- Slow-path operations reduced for long histories and large local stores.
- High-volume chat scenarios exercised with realistic pagination, reconnect churn, and background resume behavior.

Target outcome:
The messaging stack remains responsive and stable under large history depth and sustained activity.

### Stage 5: Security And Product Maturity

- Security hardening across message transport, authorization, replay protection, and attachment handling.
- Global production hardening for a mature messaging product.
- Operational readiness added for incident analysis, rollback, and safe recovery procedures.

Target outcome:
The system reaches a mature production posture instead of only a good architecture.

## Execution Priority

1. Offline guarantees and resume reliability.
2. Conflict handling, ordering, and multi-device sync.
3. Delivery, seen, and typing validation under load.
4. Real-device validation for pagination, cache, scroll, and uploads.
5. Observability, logs, metrics, and retry/recovery policy.
6. Backend hardening and end-to-end verification.
7. Large-volume performance and stability.
8. Security and production hardening.

## Definition Of Done For This Roadmap

- Chat state is deterministic after reconnect, app restart, and concurrent device activity.
- Local-first behavior does not create duplicate, reordered, or ghost messages.
- Upload and message pipelines recover cleanly after transient failures.
- Scroll and pagination remain stable across long histories.
- Backend and frontend behavior are covered by end-to-end tests.
- Runtime failures are visible through logs and metrics.
- Security posture matches a production messaging surface.