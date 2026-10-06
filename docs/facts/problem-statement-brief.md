# chat-orchestrator

## Persistent, knowledge-grounded conversations with decision models

**Problem statement and acceptance contract**  
**Document ID:** PSB-CHAT-001  
**Revision:** 3.0  
**Date:** 2026-10-04  
**Repository and service name:** `chat-orchestrator`  
**Implementation stack:** Go; PostgreSQL durable adapter  
**Delivery profile:** Single active writer; synchronous, non-streaming HTTP API

## 1. Purpose, scope and normative language

Build a Go backend service that maintains durable conversations and combines an external Knowledge Base (KB), a replaceable Decision Model and a replaceable large language model (LLM). A client can return to a stored session after a disconnect or process restart. The service admits up to 100 active turns by default, preserves order within each session and bounds waiting work. It reduces avoidable token consumption through context management, incremental summaries, idempotency and supported provider-native caching.

The service owns conversation semantics and orchestration, not the platforms implementing its external capabilities. This document is the complete product baseline; implementation choices are open only where the observable contract leaves them open. Project-specific defaults and selected integration profiles are design decisions, not claims about measured production demand or already deployed external services.

**R-DOC-01** The keywords MUST, MUST NOT, REQUIRED, SHOULD, SHOULD NOT and MAY in this document MUST be interpreted according to BCP 14, RFC 2119 and RFC 8174, only when capitalized [S1].

**R-DOC-02** Every normative requirement ID MUST remain traceable to implementation or configuration evidence and named acceptance tests.

**R-DOC-03** An implementation departure from a SHOULD requirement MUST have a recorded rationale and corresponding test expectations.

The descriptions, tables, algorithms and schemas governed by a requirement ID form part of that requirement. Examples illustrate those contracts; they do not supply real credentials, provider account access or an unverified KB protocol.

### 1.1 Service boundaries

| Capability | Ownership and initial delivery |
| --- | --- |
| Conversation API, state semantics, orchestration, scheduling and idempotency | Owned by this service. |
| Durable persistence | PostgreSQL is the selected pilot adapter behind application-owned persistence contracts. |
| Knowledge retrieval | Existing external KB; this service supplies the outbound adapter and protocol mapping, not a retrieval engine. |
| Typed decisions | TypeSafe AI Jev is the first real adapter; another provider can implement the same normalized contract. |
| Generation and summarization | Application-owned LLM contract; Anthropic Messages and OpenAI-compatible Chat Completions are the selected protocol adapters. |
| Provider-native prompt caching | Implemented and tested in each applicable LLM adapter. |
| Generic KB or infrastructure cache | Optional, behind a replaceable adapter. No Redis dependency is required. |
| Identity issuance and model hosting | External dependencies, not products built by this project. |

**R-SCOPE-01** The core workflow MUST depend on application-owned capability types rather than database or AI-provider wire types.

**R-SCOPE-02** The delivered service MUST include a working PostgreSQL adapter, a KB outbound adapter for the approved wire contract, a Jev adapter and the two selected LLM protocol adapters.

**R-SCOPE-03** A remote persistence, summary or cache integration, when selected, MUST provide an actual configured outbound client with a versioned protocol and conformance tests rather than only a Go interface.

**R-SCOPE-04** The pilot MUST NOT introduce an external KB implementation, model training/hosting platform, identity provider, UI, distributed work queue or additional microservice merely to implement this specification.

Streaming, WebSockets, asynchronous job delivery, automatic provider failover, autonomous tools, full-response/semantic caching and multi-writer scheduling are deferred. Guarding against an accidental second process is required; running multiple active service writers is not.

### 1.2 Terms and invariants

A **turn** is one user message and its conversational response. A **logical request** is identified by its authorized owner, session and request ID. An **attempt** is one admitted execution of that logical request. A **provider call** is one separately journaled outbound inference or other potentially chargeable operation.

**R-INV-01** At the default configuration the service MUST allow no more than 100 active turns and no more than one active turn per session.

**R-INV-02** A logical request MUST commit at most one user/assistant pair and one increment of the session's conversation version.

**R-INV-03** A successful chat response MUST be sent only after its complete conversational outcome is durably committed.

**R-INV-04** The next turn in a session MUST load the latest committed conversation state after its predecessor's outcome has been resolved.

**R-INV-05** Failed, cancelled or uncertain attempts MUST NOT appear as completed turns in the transcript.

**R-INV-06** Cache state, provider conversation handles and process memory MUST NOT be the authoritative record of a conversation.

Active processing begins when the session is eligible and a global slot is assigned. It includes state loading, context preparation, waits for dependency capacity, inference and finalization. Idle sessions and requests waiting for session/global admission hold no active slot. The 100-turn limit is not a requests-per-second promise or a guarantee of 100 parallel calls allowed by an external account.

## 2. Selected execution and integration profiles

### 2.1 Single-writer persistence profile

**R-PROFILE-01** The persistent deployment MUST use PostgreSQL with versioned migrations, a pinned supported database/toolchain profile and a documented backup/restore procedure.

**R-PROFILE-02** An in-memory store MUST be restricted to tests or explicitly labelled synthetic development mode and MUST NOT satisfy durable-persistence acceptance.

**R-PROFILE-03** Deployment MUST use one intended replica with a non-overlapping replacement strategy, such as Recreate, in addition to the runtime writer guard in Section 6.

### 2.2 Public authentication profile

The selected pilot boundary is a trusted gateway or issuer producing signed JWT bearer tokens. This is an application integration contract, not a claim that an existing gateway already emits these claims. JWT terminology follows RFC 7519 [S2].

**R-AUTH-01** Outside isolated synthetic development mode, the service MUST validate a bearer token's signature, pinned algorithm allowlist, issuer, audience, expiry and not-before time before accessing a session or request record.

**R-AUTH-02** The pilot JWT profile MUST use RS256 with a configured trusted key/JWKS source and normalize the claims below into an application-owned principal.

| Claim or field | Contract |
| --- | --- |
| `iss`, `aud`, `exp`, `iat`; optional `nbf` | Validated issuer, intended audience and validity interval. |
| `tenant_id` | Non-empty tenant identifier; maximum 128 UTF-8 bytes. |
| `sub` | Non-empty subject identifier; maximum 128 UTF-8 bytes. |
| `roles` | At most 32 allowlisted role strings, each at most 64 bytes. |
| `authz_version` | Optional trusted authorization revision; required by a deployment claiming revision-based revocation. |
| Normalized principal | `{tenant_id, subject, roles, authz_version}`. |

**R-AUTH-03** The service MUST derive session ownership from `(tenant_id, subject)` and MUST NOT accept owner, tenant or role overrides from client JSON or untrusted forwarded headers.

**R-AUTH-04** Unknown, deleted and other-owner resources MUST return the same 404 representation after authentication, without a resource-existence oracle.

**R-AUTH-05** Retrieval permissions MUST be derived server-side from trusted roles and authorization scope rather than from the session identifier.

**R-AUTH-06** The service MUST re-evaluate its trusted authorization snapshot before starting queued work and before returning history, status or a replay.

Token expiry while queued produces an authentication failure before paid work; renewing the token permits a safe same-key retry only when the idempotency/version rules permit it. Token validity at request start is not an indefinite authorization grant.

**R-AUTH-07** Offline authentication tests MUST use local signing keys and a local trusted-key fixture rather than network identity discovery.

Production issuer URLs, key rotation policy and the actual claim mapping remain environment inputs subject to the contract-closure rules in Section 20. An incompatible existing gateway needs an explicit verified mapping; the core principal model does not change silently.

## 3. Public HTTP API

### 3.1 Endpoints

**R-API-01** The service MUST implement the endpoint contract below as synchronous, non-streaming HTTP/JSON with a published OpenAPI specification.

| Endpoint | Observable result |
| --- | --- |
| `POST /v1/sessions` | 201; creates an empty owned session with server-generated ID and conversation version 0. |
| `POST /v1/chat` | 200 only for a committed `answer`, `ask_clarification` or `cannot_answer` outcome. |
| `GET /v1/sessions/{session_id}` | 200; authorized metadata, locale, retrieval scope and conversation version. |
| `GET /v1/sessions/{session_id}/messages` | 200; bounded, cursor-paginated committed messages in ascending sequence. |
| `GET /v1/sessions/{session_id}/requests/{request_id}` | 200; known request state and stored result/problem where available; 404 if unknown/inaccessible. |
| `DELETE /v1/sessions/{session_id}` | 204 after live application content is purged; 409 if busy; Section 16 defines races and recovery. |
| `GET /health/live` | Process liveness without paid dependency calls. |
| `GET /health/ready` | Whether configuration, storage, writer ownership and startup recovery permit admission. |

**R-API-02** `POST /v1/chat` MUST reject an unknown session with 404 rather than implicitly create one.

**R-API-03** Session creation MUST accept only the allowlisted locale, metadata and retrieval fields illustrated below.

```json
{
  "locale": "tr-TR",
  "metadata": {"product_id": "device-42", "product_version": "4.2"},
  "retrieval": {
    "corpus_ids": ["product-manuals"],
    "filters": {"product_id": "device-42", "product_version": "4.2"}
  }
}
```

The initial metadata/filter allowlist is `product_id` and `product_version`, each a string of at most 128 bytes. Up to eight corpus IDs of at most 128 bytes are accepted. Empty metadata/filters are valid. Unknown fields are rejected. These are query hints, not verified user facts or permission grants.

**R-API-04** Client retrieval preferences MUST only narrow the server-authorized scope and MUST be rejected with 403 `RETRIEVAL_SCOPE_FORBIDDEN` when they request an unauthorized corpus or filter value.

**R-API-05** Session locale and retrieval preferences MUST be immutable in the pilot; changed defaults require a new session, while a chat request may override only its response locale.

```json
{
  "request_id": "req-123",
  "session_id": "8a9c0944-3928-4ad7-bbb1-77884357794c",
  "question": "Peki aynı cihazın garantisi ne kadar?",
  "locale": "tr-TR"
}
```

**R-API-06** Every chat request MUST contain non-empty `request_id`, `session_id` and `question` fields.

**R-API-07** Request parsing MUST enforce a 32 KiB body limit, an 8 KiB UTF-8 question limit, a 128-byte request-ID limit and strict JSON/schema validation before admission.

Request IDs use ASCII letters, digits, hyphen and underscore; session IDs use the service's UUID format. Empty/whitespace-only questions, duplicate JSON keys, trailing JSON values, unknown properties and invalid UTF-8 are invalid. Oversized bodies use 413; field/schema violations use 400. Lower configured limits need matching published schemas.

**R-API-08** History pagination MUST default to 50 messages, cap pages at 100, bind opaque cursors to the session and return a stable ascending sequence under concurrent append.

**R-API-09** API responses MUST expose application-owned fields only, with a 64 KiB maximum chat-response body and no raw upstream errors, credentials or internal prompts.

### 3.2 Conversational outcomes

**R-API-10** A committed response MUST conform to this normalized envelope and the outcome table below.

```json
{
  "request_id": "req-123",
  "session_id": "8a9c0944-3928-4ad7-bbb1-77884357794c",
  "session_version": 8,
  "action": "answer",
  "reason_code": "grounded",
  "locale": "tr-TR",
  "answer": "Garanti süresi ... [S1]",
  "sources": [{
    "citation_id": "S1", "document_id": "doc-42",
    "chunk_id": "chunk-3", "revision": "rev-7"
  }],
  "message_refs": []
}
```

| Action and reason | Text and evidence contract |
| --- | --- |
| `answer / grounded` | Non-empty generated domain answer; at least one valid KB citation; `sources` contains exactly the cited KB subset. |
| `answer / conversation_meta` | Answer about this transcript, not a fresh domain assertion; `sources=[]`; supporting authorized message sequences appear in `message_refs`. |
| `answer / smalltalk` | Bounded localized acknowledgement; both reference arrays are empty. |
| `ask_clarification / needs_clarification`, `clarification_uncertain` or `intent_ambiguous` | Non-empty localized clarification request; both reference arrays empty; no unsupported factual answer. |
| `cannot_answer / no_evidence`, `conflicting`, `insufficient` or `uncertain` | Non-empty localized explanation of the limitation; both reference arrays empty. |
| `cannot_answer / out_of_scope`, `history_unavailable` or `provider_refusal` | Non-empty controlled explanation; both reference arrays empty. |

All three actions are successful conversational outcomes and increment the conversation version. Infrastructure errors do neither. Source titles/URIs/revisions are optional when not supplied by the KB; absent values are not invented. `message_refs` refers to transcript sequence numbers, never to another session.

**R-API-11** The response locale MUST resolve as request override, then session locale, then the configured default `tr-TR`, with `tr-TR` and `en-US` supported in the pilot.

Response language follows that explicit contract, not an undocumented language detector. A Turkish request with `tr-TR` remains Turkish when its evidence is English. Unsupported locales return 400. Source titles need not be translated.

## 4. Durable conversation and request data

### 4.1 Authoritative entities

**R-STATE-01** The store MUST retain sessions, immutable committed messages, request journals, provider-call journals, summary checkpoints and provenance sufficient to enforce the following data contract.

| Entity | Required logical data |
| --- | --- |
| Session | ID, owner, locale, retrieval settings, authorization fingerprint, conversation version, lifecycle state and retention timestamps. |
| Committed message | Session ID, increasing sequence, role, text, logical request, sources/message references and creation time. |
| Request journal | Logical key, fingerprint version/hash, admitted version, execution/retry version, attempt/admission sequence, owner epoch, state and saved result/problem. |
| Provider-call journal | Unique call/attempt ID, role/stage, input hash, model/config versions, dispatch intent, outcome, normalized reusable result when available and usage state. |
| Summary checkpoint | Session ID, `covered_seq`, optional partial-message coverage cursor, `summary_version`, bounded summary, source transcript hash, summarizer/procedure versions and writer epoch. |
| Reserved ID registry | Non-reusable session-ID digest and lifecycle allocation/tombstone status, separate from conversation content. |

**R-STATE-02** A committed turn MUST remain available after stopping and restarting the service against the same persistent store.

**R-STATE-03** Finalization MUST atomically write the user/assistant pair, source references, new conversation version and completed idempotency result.

**R-STATE-04** Finalization MUST check expected conversation version, logical-request uniqueness, live session status and current writer epoch within the same transaction.

**R-STATE-05** The implementation MUST NOT hold a session/database transaction lock across a KB or model network call.

**R-STATE-06** A lost database-commit acknowledgement MUST trigger authoritative result reconciliation before any inference is repeated.

A committed result wins over an expired HTTP connection. An unconfirmed commit is not proof of rollback. If the store is temporarily unreachable, status remains explicitly unavailable or pending reconciliation; the service does not invent a completed, retryable or uncertain result.

**R-STATE-07** Original transcript messages MUST remain accessible independently of summaries until the configured deletion/retention policy removes them.

**R-STATE-08** The PostgreSQL implementation MUST pass real-store conformance, migrations, restart, atomicity and backup/restore tests.

### 4.2 Summary checkpoints are derived state

**R-STATE-09** A valid summary checkpoint MUST be committed independently of the current chat turn without incrementing the conversation version.

**R-STATE-10** A checkpoint update MUST use coverage/version compare-and-swap and writer/session-lifecycle fencing so it cannot summarize uncommitted turns or survive deletion races.

This preserves paid summarization progress when later answer generation fails. Checkpoints contain derived data; they do not replace transcript authority and are not proof that the current user message has been answered.

## 5. Idempotency, retries and crash recovery

### 5.1 Logical identity and version binding

**R-IDEM-01** The logical key MUST be `(tenant_id, subject, session_id, request_id)`, with authentication and ownership checks preceding lookup or replay.

**R-IDEM-02** A repeated key with a different versioned semantic-input fingerprint MUST return 409 `IDEMPOTENCY_CONFLICT` without altering the existing request.

The fingerprint includes the exact accepted question, resolved locale and immutable retrieval/session configuration identity. It excludes transport timestamps, trace IDs and renewed token bytes. Security-policy changes are handled by authorization checks, not by pretending the user changed the question.

**R-IDEM-03** The service MUST claim a logical request atomically before execution and resolve concurrent duplicates without a check-then-insert race.

**R-IDEM-04** Pre-admission validation and overload rejections MUST NOT create durable in-progress requests or completed conversation turns.

**R-IDEM-05** Completed request keys and response bodies MUST remain replayable for the retained session lifetime, subject to current authorization and deletion policy.

A first attempt may wait behind earlier same-session work and then bind its execution version to the state it actually reads. Its admission-time version is not an execution precondition. A retry of an interrupted attempt is different: it has lost its original queue position.

**R-IDEM-06** A retryable request MUST rejoin the queue with a new admission sequence and pass its recorded retry-version guard when execution actually starts, not merely when re-enqueued.

**R-IDEM-07** The retry-version guard MUST equal the attempt's execution version when execution began, or its original admission-time version when execution never began.

**R-IDEM-08** If that guard differs from the current conversation version at retry execution, the service MUST return and retain 409 `STATE_CONFLICT` without a paid call.

Thus A1 cannot silently retry against a new context after A2 has committed. The client explicitly creates a new logical request when it intends a question to apply to changed conversation state.

### 5.2 Externally visible request states

**R-IDEM-09** Request status and same-key resubmission MUST implement this complete state table.

| Stored state | Meaning | Same-key `POST /v1/chat` |
| --- | --- | --- |
| `queued` | Admitted and waiting for session/global capacity. | 409 `REQUEST_IN_PROGRESS`; bounded `Retry-After`; no duplicate waiter. |
| `running` | Executing or performing bounded in-attempt recovery. | 409 `REQUEST_IN_PROGRESS`; no second execution. |
| `committing` | Final transaction or commit reconciliation is unresolved. | 409 `REQUEST_IN_PROGRESS`; status/reconciliation guidance. |
| `completed` | Durable turn and response exist. | 200 with saved response and `Idempotent-Replayed: true`; no new external calls. |
| `retryable` | Resumption can avoid an unresolved paid side effect and is allowed by the version guard. | Re-admit the same key, or reject overload/auth/version conflict; never duplicate a committed turn. |
| `uncertain` | An external call may have incurred cost and its usable outcome cannot be established. | 409 `OUTCOME_UNCERTAIN`; no automatic new attempt. |
| `failed_final` | Known non-retryable failure for this logical request. | Replay the saved status/problem with `Idempotent-Replayed: true`. |

`GET .../requests/{request_id}` returns a status envelope with `state`, `attempt`, timestamps, `result` or `problem`, and `next_action` (`wait`, `retry_same_id`, `use_new_id`, or `none`). A disconnected socket may prevent delivery of an error; the journal remains the reference.

**R-IDEM-10** A disconnect, queue deadline or shutdown before any unresolved potentially chargeable dispatch MUST produce `retryable`, not a permanent cancelled state.

**R-IDEM-11** A cancellation or deadline after a potentially accepted call with no durably recoverable result MUST produce `uncertain` after reconciliation fails.

A paid call that returned a durably saved usable result is not uncertain merely because money was spent. Resuming from that result can be safe. Conversely, even a read-only KB may be billable; its configured effect/billing class determines whether an unanswered dispatch is uncertain. Unknown billing semantics are treated conservatively.

### 5.3 Durable dispatch and outcome journal

**R-IDEM-12** Before each potentially chargeable outbound dispatch, the service MUST durably record a unique call ID, stage/input identity, writer epoch and `dispatch_intent` marker.

**R-IDEM-13** The service MUST NOT send the call when its dispatch marker cannot be durably written or current writer ownership cannot be established.

A marker means “may have been sent,” not “the provider definitely received it.” A crash between marker and send can therefore produce a conservative false uncertainty; claiming otherwise would require provider-side reconciliation.

**R-IDEM-14** Each provider result MUST be journaled as a known success with reusable normalized output, a verified rejection/no-effect, a known unusable result, or an unresolved outcome before a safe retry decision is made.

**R-IDEM-15** Saved stage outputs MUST be reused only when their input, model/policy, evidence snapshot, authorization and conversation-version identities still match.

A metadata-only log of a successful call is not a reusable result. When a required result was not saved, reissuing that successful paid call is not silently classified as free retry. Known unusable output is a final protocol/generation error, not an unknown outcome.

**R-IDEM-16** Application and SDK retry layers MUST share one bounded retry policy so nested retries cannot multiply paid requests.

**R-IDEM-17** `max_uncertain_model_retries` MUST accept only 0 or 1 and default to 0.

**R-IDEM-18** An opted-in uncertain-model retry MUST occur only within the still-connected original attempt, with unchanged session/input, valid writer ownership, sufficient deadline/cost budget and a separately journaled possible duplicate charge.

Cancellation, process restart, a changed model/policy and arbitrary new HTTP resubmission do not authorize that optional retry. It is not automatic provider failover. Documented provider idempotency/reconciliation may reduce uncertainty, but unsupported TypeSafe behaviour is never assumed.

### 5.4 Legal transitions and client protocol

**R-IDEM-19** The implementation MUST constrain transitions to `queued -> running -> committing -> completed`, exits from nonterminal states to `retryable`, `uncertain` or `failed_final`, and guarded `retryable -> queued` resubmission.

Commit reconciliation may resolve `committing` to `completed`, safe `retryable`, or `uncertain` according to actual stored evidence. A known aborted commit with a saved valid response can be retried without regeneration. `completed` is immutable; `failed_final` requires a new request ID. `uncertain` is not re-enqueued by clients under the same key. Authoritative late reconciliation can discover an already committed result or recover usable stage data; the latter becomes guarded `retryable` only when the original version still matches. It cannot append an old turn after a later version committed.

**R-IDEM-20** Startup recovery MUST inspect abandoned records only after exclusive writer ownership is acquired and MUST NOT automatically replay the old in-memory queue.

**R-IDEM-21** Recovery MUST resolve committed records first, mark never-dispatched abandoned work retryable and mark unreconciled dispatches uncertain before affected sessions accept new work.

Client recovery is: after a transport error, inspect the request-status endpoint; wait for active states; use the saved completed result; retry the same ID for `retryable`; use a new ID only after consciously accepting a state change, a final failure or possible duplicate model cost. A status 404 for the same authorized live session means no claim is known and permits resubmission with the original ID. A temporary 503 does not mean the request is absent.

**R-IDEM-22** Cancellation before finalization MUST NOT start a detached new turn commit; recoverable stage outputs permit a guarded client retry, not background conversation completion.

**Guarantee boundary:** at-most-one durable turn per logical key is required; exactly-one provider charge across arbitrary network failures is not promised.

## 6. Enforced single-writer ownership and fencing

**R-WRITER-01** Before recovery or accepting mutations, each process MUST acquire a service/database-scoped PostgreSQL session advisory lock on a dedicated connection.

**R-WRITER-02** A process that cannot acquire that lock MUST remain unready and MUST NOT recover requests, admit work or dispatch models.

PostgreSQL session advisory locks last until release or termination of the owning database session [S6]. They are not a TTL lease. This connection is not a pooled connection borrowed separately for each operation.

**R-WRITER-03** After obtaining the advisory lock, the process MUST allocate a monotonically increasing `instance_epoch` and publish it in a durable writer-control row before recovery.

**R-WRITER-04** Every mutation, dispatch-marker write and final commit MUST enforce the current epoch transactionally, with control-row locking or an equivalent mechanism that prevents a check/write race during ownership change.

For example, transactions hold a shared control-row lock while checking the epoch; a successor publishes its epoch using an exclusive update. Short transactions can then complete before takeover or be rejected as stale, rather than pass a detached epoch check.

**R-WRITER-05** Request claims and stage journals MUST identify their owning epoch, and recovery MUST leave records belonging to a verified current owner untouched.

**R-WRITER-06** Loss or unverifiability of the ownership connection MUST fail readiness, stop new dispatch/admission and cancel local work without automatically reconnecting as the same owner.

**R-WRITER-07** A replacement process MUST pass the second-process and stale-writer acceptance tests before single-writer safety is claimed.

Epoch fencing protects persistent mutations and coordinated dispatch permission. It cannot retract a request already accepted by an AI provider or atomically fence an external API lacking fencing support. In-flight calls during ownership loss remain subject to Section 5's uncertainty boundary; this is not a distributed exactly-once execution claim.

## 7. Bounded concurrency, admission and fairness

**R-SCHED-01** With non-throttling test dependencies and eligible principals, the scheduler MUST demonstrate 100 simultaneously active distinct sessions and never a 101st active turn.

**R-SCHED-02** Same-session FIFO MUST use successful server admission sequence, not client clocks or presumed network-send order.

**R-SCHED-03** Only the oldest waiting request of an idle session with available principal quota MUST be eligible for an active slot.

**R-SCHED-04** Eligible sessions MUST be selected FIFO, with a session's next request returning to the tail after its preceding turn terminates and its result is resolved.

**R-SCHED-05** Waiting work for a busy session or quota-exhausted principal MUST NOT reserve global active capacity or block other eligible sessions.

The initial limits are 100 active turns globally, 100 waiting requests globally, two waiting requests per session, ten active turns per principal and ten waiting requests per principal. All pre-execution waiting counts toward both queue capacity and queue time, including same-session waits. Principal quotas prevent one subject from using many sessions to consume the entire service; tenant-wide fairness is not separately guaranteed.

**R-SCHED-06** Admission MUST enforce the global, session and principal limits atomically with bounded temporary reservations and durable request claiming.

**R-SCHED-07** Session creation MUST enforce a per-principal token bucket of 30 creations per minute with burst 10 and a default maximum of 1,000 retained sessions per principal.

**R-SCHED-08** Admission MUST reject with 429 and `Retry-After` when capacity is full or its conservative estimated start delay exceeds the request's remaining queue/start budget.

Use a versioned scheduling estimate covering active residual work, earlier eligible work, same-session predecessors, principal quotas and observed dependency throttling. Cold-start estimated turn duration is 30 seconds; update conservatively from observed durations rather than assuming a queue bound guarantees acceptable latency. Under the simplifying 100-worker/30-second-turn estimate, a 60-second wait budget gives about 200 starts before applying headroom; the selected 100-waiter cap leaves headroom. This is a planning approximation, not a Little's-law latency guarantee.

**R-SCHED-09** Queue time MUST be capped at 60 seconds, including same-session waits, independently of the 180-second total attempt deadline.

**R-SCHED-10** The scheduler MUST remove cancelled or expired waiters without downstream work or leaked reservations.

**R-SCHED-11** A start-budget guard MUST refuse to start a turn when less than 60 seconds of processing budget remains after reserving finalization time.

The estimator can still be wrong; actual queue deadlines remain authoritative and expire to `retryable`. A per-session cap of two is an upper bound, not a promise to accept both when predicted waiting is too long.

**R-SCHED-12** Admission handlers, goroutines, queue records and idle session-coordination objects MUST be bounded and cleaned up without busy-waiting or ordering races.

## 8. Workflow and conversation-aware retrieval

The normal domain path is: authenticate and validate; claim/schedule; bind session version; prepare bounded history; classify intent with the Decision Model; retrieve authorized evidence; assess evidence with the Decision Model; generate when allowed; validate the response; atomically commit. Summary checkpoints may be persisted during context preparation. All inference shares journaling, budget and cancellation rules.

### 8.1 Knowledge capability contract

**R-KB-01** The KB capability MUST accept original question, resolved query, bounded conversation context, allowed corpus/filter scope, locale and optional authorized document hints.

**R-KB-02** A follow-up query MUST retain the relevant referent from committed conversation context rather than send only an isolated pronoun-based question.

The default query preparer is deterministic: combine the current question with relevant product/session facts and recent user references. Previously cited document IDs may be boost hints; they are not mandatory filters that prevent discovering newer or contradictory evidence. Extra LLM query rewriting is optional and charged/journaled explicitly.

**R-KB-03** Query preparation MUST preserve the user's question and distinguish original text from any resolved or translated query.

**R-KB-04** The KB adapter MUST normalize a bounded result into evidence items containing text, document ID, chunk ID and available revision/title/reference metadata.

**R-KB-05** Retrieval MUST cap result count at eight evidence items and enforce configured response-byte and model-specific evidence-token budgets before inference.

**R-KB-06** The adapter MUST distinguish an empty successful result, transport/timeout failure, upstream access failure and malformed/oversized evidence.

**R-KB-07** KB failure MUST NOT silently activate a general-knowledge answer path.

**R-KB-08** The current KB's wire protocol, authentication, authorization propagation, filters, version semantics, limits and error mapping MUST be approved and frozen before its implementation/contract tests are treated as Gate A evidence.

The application-owned request/response shape below is the required mapping target, not a claim that the existing KB uses these JSON fields or any particular URL:

```text
KnowledgeQuery {
  question, resolved_query, locale,
  conversation_context { summary, recent_turns, relevant_metadata },
  access_scope { tenant, subject, allowed_roles, authorization_revision },
  corpus_ids, filters, preferred_document_ids, max_results
}
KnowledgeResult {
  items [{ document_id, chunk_id, text, revision?, title?, reference_uri? }],
  corpus_revision?, authorization_revision?
}
```

The approved wire contract supplies actual HTTP method/path, credentials and field mapping. No fabricated `/query` endpoint is a substitute. If the external service cannot enforce required access scope, it needs a verified integration boundary before real data is used; model filtering is not authorization.

### 8.2 Evidence as data, not instructions

**R-KB-09** User content, KB passages and summaries MUST remain untrusted data and MUST NOT change credentials, endpoints, roles, policy, executable actions or system instructions.

**R-KB-10** Conversation facts MUST explain intent without replacing current KB evidence for fresh domain assertions.

**R-KB-11** The service MUST NOT fetch user-supplied URLs or execute model-selected tools in the pilot.

## 9. Decision Model contract and deterministic policy

### 9.1 Decision input and roles

**R-DEC-01** The first real Decision Model adapter MUST implement TypeSafe AI Jev through the pinned, tested `POST /v1/systemone` contract [S4].

**R-DEC-02** Every decision input MUST include the bounded conversational information needed to interpret the current question, not just the last sentence.

The common normalized state is:

```text
DecisionState {
  question, resolved_query?, locale,
  conversation { summary, summary_coverage, recent_complete_turns,
                 relevant_metadata, selected_transcript_references },
  evidence { retrieval_status, items, corpus_revision? },
  application_scope, policy_version
}
```

For intent classification, evidence is explicitly `not_requested`; for post-retrieval assessment it is `success`, including a possibly empty item list. Credentials, raw identity tokens and unnecessary personal identifiers are not model input. The same resolved query used for retrieval is included in the evidence-assessment state.

**R-DEC-03** The service MUST perform a bounded intent classification into `domain`, `conversation_meta`, `smalltalk` or `out_of_scope` before domain retrieval.

**R-DEC-04** Ambiguous intent MUST produce `ask_clarification / intent_ambiguous` without guessing a domain workflow.

The first Jev evaluation uses Choice for intent. The default intent-confidence policy accepts a choice only when its top probability is at least 0.70 and its margin over the second choice is at least 0.20. These are uncalibrated project starting thresholds, not vendor accuracy guarantees; Gate C validates the pinned policy before release.

**R-DEC-05** A domain request with successful retrieval MUST receive three independent assessments: `needs_clarification`, `evidence_sufficient` and `evidence_conflicting`.

Jev uses one batched evaluation of three atomic Noul questions over the complete shared state. TypeSafe describes questions in one call as independently evaluated against that state; they do not consume each other's newly produced answers [S3]. The second evaluation follows retrieval, so it can legitimately use earlier application results in its supplied state.

**R-DEC-06** The normalized assessment contract MUST distinguish `yes`, `no` and `uncertain` for each judgment and preserve any raw probability separately.

For the Jev pilot profile, `needs_clarification` and `evidence_conflicting` map p <= 0.20 to `no`, p >= 0.80 to `yes`, and the interval between to `uncertain`. `evidence_sufficient` maps p <= 0.20 to `no`, p >= 0.85 to `yes`, and intermediate values to `uncertain`. Boundaries are inclusive as stated. Another provider can supply equivalent typed verdicts without inventing a probability it does not report.

**R-DEC-07** Thresholds, question text, normalization rules and action precedence MUST be versioned together in a provider/model-specific policy profile.

### 9.2 Complete action precedence

**R-POLICY-01** The domain workflow MUST apply the following first-match policy after cross-cutting authentication, budget and outcome-reconciliation checks.

| Priority | Condition | Result |
| --- | --- | --- |
| 1 | KB transport, access or protocol error | No turn; mapped 502/503/504 problem; retry classification follows actual call-side-effect evidence. |
| 2 | Decision transport error, invalid/missing assessment or unsupported model result | No turn; mapped dependency error or 502 `DECISION_INVALID`; no permissive generation fallback. |
| 3 | `needs_clarification=yes` | Commit `ask_clarification / needs_clarification`. |
| 4 | `needs_clarification=uncertain` | Commit `ask_clarification / clarification_uncertain`. |
| 5 | Retrieval succeeded with zero evidence items | Commit `cannot_answer / no_evidence`. |
| 6 | `evidence_conflicting=yes` | Commit `cannot_answer / conflicting`. |
| 7 | `evidence_conflicting=uncertain` | Commit `cannot_answer / uncertain`. |
| 8 | `evidence_sufficient=no` | Commit `cannot_answer / insufficient`. |
| 9 | `evidence_sufficient=uncertain` | Commit `cannot_answer / uncertain`. |
| 10 | Clarification=no, conflict=no, sufficiency=yes and evidence non-empty | Generate and validate `answer / grounded`. |

Contradictory assessments therefore have one result: clarification precedes missing/conflicting evidence, and conflict precedes sufficiency. “Uncertain” is derived from the normalized assessment, not asked as a redundant fourth class. Evidence explanations do not automatically expand into a product feature that presents disputed factual claims.

**R-POLICY-02** `smalltalk` MUST use a bounded localized response without a KB call or unrestricted domain generation.

**R-POLICY-03** `conversation_meta` MUST answer only from authorized transcript material and label references as conversation history rather than current KB authority.

Common meta cases, such as the first user question, use deterministic transcript selection. A bounded LLM may phrase a meta answer when needed. If the required material cannot be retrieved within the defined bounds, return `cannot_answer / history_unavailable` rather than fabricate history.

**R-POLICY-04** `out_of_scope` MUST produce the localized `cannot_answer / out_of_scope` outcome without KB retrieval or a general-knowledge fallback.

### 9.3 Provider validity and model pinning

**R-DEC-08** The Jev adapter MUST validate expected answer names, primitive types, enum membership, finite 0..1 probabilities and applicable probability-distribution consistency.

Missing or malformed output is not uncertainty that can be acted upon; it is `DECISION_INVALID`. A Noul's absence of a separate confidence field is valid. TypeSafe defines a Noul probability and documents an optional derived distance `abs(2p - 1)` [S5].

**R-DEC-09** Any derived confidence-style metric MUST carry its derivation/version label and MUST NOT be presented as a provider-reported confidence value.

**R-DEC-10** A live decision profile MUST identify an approved concrete returned model ID and MUST reject unapproved model drift before acting on its judgments.

TypeSafe requires a model in the request, allows authenticated model discovery and can return an identifier different from a requested alias [S4]. Discovery is a provisioning step, not a normal gate prerequisite. Where only a moving alias is available, an approved expected returned-ID set and recorded limitation are required; an alias alone is not a reproducible model pin. Drift yields 503 `MODEL_PROFILE_MISMATCH`, an operational alert and no successful turn.

**R-DEC-11** The Jev capability profile MUST declare a verified or explicitly conservative engineering input cap, its evidence/provenance and unknown operational behaviours rather than infer limits from an LLM.

The reviewed public OpenAPI does not define a token-counting endpoint, state-size ceiling, provider idempotency key or complete 429/5xx response schema [S4]. These remain contract/integration verification items. An unanswered dispatch is uncertain unless actual evidence establishes rejection or a recoverable result; a timeout alone does not prove that it reached the provider.

**R-DEC-12** A second deterministic decision implementation MUST pass the same core conformance tests without requiring a second paid decision provider.

## 10. LLM adapters, output validation and citations

**R-LLM-01** Generation and summarization MUST use application-owned input/output contracts independent of provider SDKs.

**R-LLM-02** The pilot MUST implement Anthropic Messages and OpenAI-compatible Chat Completions as two distinct protocol adapters with a shared conformance suite.

The second protocol is selected to allow a separately operated compatible local endpoint as well as hosted providers. Compatibility is endpoint/model-specific; it does not promise identical caching, structured output, usage fields or pricing. A local server is not automatically installed, credential-free or capable of 100 model calls merely because the protocol is compatible. Running that model server remains outside this repository's product scope.

**R-LLM-03** Each `(provider, endpoint, API version, model)` profile MUST declare input/output limits, tokenizer/estimator, finish/refusal mapping, structured-output method, caching controls and usage semantics.

**R-LLM-04** Unsupported mandatory capabilities MUST fail configuration rather than be silently ignored.

**R-LLM-05** The generator MUST receive the exact evidence set and application policy selected by the orchestrator and MUST NOT override the chosen action.

**R-LLM-06** The normalized generation result MUST include non-empty bounded text, referenced citation IDs, completion status and reported-or-unknown usage.

Adapters may use native structured output or a bounded validated application envelope. Free-form model text never supplies database operations, authorization decisions or arbitrary tools. Hidden chain-of-thought is not requested or persisted as conversation content.

**R-LLM-07** A generated domain answer MUST reference only evidence items supplied to that call and MUST cite at least one item before it can be committed as `answer / grounded`.

**R-LLM-08** An invalid, fabricated or missing required reference MUST fail the turn with 502 `CITATION_INVALID` rather than be silently dropped into an apparently valid answer.

`source` membership validation is not semantic entailment. Gate C separately evaluates whether cited evidence actually supports the answer. The service does not promise that reference validation alone eliminates hallucinations.

**R-LLM-09** `sources` MUST contain exactly the deduplicated cited subset, in first-citation order, rather than every retrieved document.

**R-LLM-10** A length-truncated answer MUST fail with 502 `GENERATION_TRUNCATED` and MUST NOT be committed as a complete answer.

No hidden regeneration or continuation request is made by default. A known refusal is different from transport/protocol failure.

**R-LLM-11** A valid provider refusal MUST produce the controlled `cannot_answer / provider_refusal` outcome without a second provider or prompt-bypass attempt.

**R-LLM-12** A provider/model change MUST rebuild context from application state and revalidate limits without depending on the previous provider's session or cache handles.

## 11. Bounded context and incremental summaries

### 11.1 Context structure and budgets

**R-CTX-01** Generation context MUST preserve the ordered structure of stable instructions, a bounded summary, complete turns since that summary, current evidence and the current question.

The unsummarized tail is append-only between summary checkpoints, rather than a sliding last-K window that changes the prefix on every request. Older content is compacted when thresholds are reached. Selective evidence and the new question remain after reusable conversation segments. Stable formatting does not authorize adding irrelevant text or exceeding a model window.

**R-CTX-02** Each decision, summary and generation call MUST fit that role's independently configured input/output/byte budgets before dispatch.

```text
estimated_input + reserved_output + safety_margin <= usable_window
```

For a byte-limited API, enforce its byte cap as well. Cached tokens remain input context and count toward the window. Jev's cap is not inferred from the generation model. Summarization input is not assumed to fit merely because generation context does.

**R-CTX-03** Startup validation MUST check that the maximum accepted question, required instructions, minimum useful evidence/context, output reserve and safety margin can fit every applicable role profile.

**R-CTX-04** The service MUST NOT silently truncate the current question or mandatory instructions to make a call fit.

**R-CTX-05** When a tokenizer is unavailable, the configured estimator MUST declare a conservative method, byte guard and safety margin validated against the selected profile.

The default safety reserve is the larger of 10% of the configured usable window or 256 estimated tokens, unless profile-specific evidence justifies a different value. A missing model limit is a configuration error, not permission for unbounded input.

### 11.2 Incremental catch-up summarization

**R-CTX-06** Summary work MUST trigger from configured role budgets and MUST NOT run unconditionally on every user message.

**R-CTX-07** Each summary pass MUST consume a bounded forward chunk of unsummarized committed history and advance its monotonic coverage cursor or return an explicit failure.

**R-CTX-08** Summaries MUST be bounded to 4 KiB UTF-8 text and to the tighter role-specific token budget used by their consumers.

The pilot allows at most two summarizer calls per chat attempt by default. A chunk plus previous summary, instructions and output allowance fits the summarizer's own window. A single long historical message may be processed through deterministic UTF-8-safe subchunks. `covered_seq` remains the last fully covered message; an optional `{message_seq, byte_offset}` cursor records partial coverage. Progress compares the pair monotonically, so a partial-message checkpoint is not mistaken for a fully summarized turn. The public transcript remains unchanged.

**R-CTX-09** Partial summary progress MUST be durably checkpointed and reused when later preparation or generation fails.

**R-CTX-10** When more catch-up is required after the per-attempt summary budget, the service MUST return `CONTEXT_PREPARING` as a safe retryable state only when durable coverage advanced and further progress is demonstrably possible.

**R-CTX-11** A context that cannot make bounded progress MUST return final 422 `SESSION_CONTEXT_EXHAUSTED` rather than repeat an indefinitely retryable error.

An unresolved paid summary call still follows `uncertain` handling; a convenient context-error label cannot hide that cost uncertainty. A failed summary may be bypassed only when an existing safe context already fits and the call outcome is known.

**R-CTX-12** Summary provenance MUST distinguish user-provided statements, prior assistant assertions, cited KB facts, unresolved questions and preserved user constraints.

**R-CTX-13** The implementation MUST retain summary coverage/source hashes and procedure/model versions so checkpoints can be validated after restart or model changes.

Summary quality is measured, not asserted lossless. Critical annotated facts and constraints are assessed in Gate C. Regeneration from original history remains possible when a summary policy changes; checkpoints do not rewrite history.

## 12. Provider-native caching and optional caches

### 12.1 Cache intent and privacy constraints

**R-CACHE-01** Native prompt caching MUST be implemented for the selected supported LLM profiles rather than represented only by an unused interface.

**R-CACHE-02** Correct answers, authorization and session continuity MUST remain independent of a cache hit, miss, eviction or restart.

**R-CACHE-03** The cache contract MUST distinguish `auto`, `prefer_reuse` and `no_explicit_cache` from a separate hard `require_no_prompt_cache` constraint.

`no_explicit_cache` means that the adapter adds no explicit cache creation/reuse directives; automatic provider caching may still occur. `require_no_prompt_cache` prohibits prompt-cache reads and writes and is satisfiable only by a verified endpoint/model capability. Neither mode alone promises no abuse-monitoring logs, no provider storage or a particular legal transfer basis.

**R-CACHE-04** A hard cache/retention/privacy constraint that a selected endpoint cannot verify or satisfy MUST fail configuration before private content is sent.

**R-CACHE-05** Cache retention, storage options and applicable provider/account policy MUST be explicitly configured or explicitly documented as immutable/unsupported rather than inherited without verification.

### 12.2 Deterministic reusable context

**R-CACHE-06** Cacheable prompt segments MUST serialize deterministically across requests and process restarts for identical application state and profile versions.

**R-CACHE-07** Request IDs, timestamps and unstable iteration order MUST NOT enter reusable prompt prefixes unless semantically necessary.

Use ordered structures or deterministic serialization settings and byte-level golden tests. Go's `encoding/json` v1 sorts map keys, while the documented v2 semantics differ [S8]; therefore the requirement is tested byte stability of the actual serialization path, not a blanket assertion that every Go JSON map is random.

**R-CACHE-08** Adapters SHOULD place supported breakpoints after stable instructions, summary and the completed-conversation tail while keeping changing evidence and the current question after reusable boundaries.

A new summary legitimately changes part of the prefix. Cross-session reuse is limited to non-private common instructions; session content is not assembled into a shared application cache entry. A provider's block limits or request schema may require fewer boundaries, with that mapping tested.

**R-CACHE-09** Application cache identity MUST include authorization equivalence, tenant, profile/model and relevant content versions, with subject/session scope added for private conversation material.

Provider routing keys are not proof of provider-enforced tenant isolation. Private prefixes need a documented provider isolation boundary; opaque routing keys contain no raw personal identifiers.

### 12.3 Endpoint-specific behaviours

**R-CACHE-10** The capability matrix MUST pin and test actual endpoint/model cache controls, thresholds, TTL semantics and read/write usage accounting.

OpenAI's current guide distinguishes earlier implicit-only models from newer explicit/implicit controls; on the documented newer path, explicit mode without breakpoints disables prompt-cache reads/writes. Its reported read/write token fields are subdivisions of total input, not extra input to add again [S10]. These controls are not automatically assumed present on every OpenAI-compatible endpoint.

Anthropic documents exact-prefix matching, cache-creation/read counters, workspace-dependent isolation, model-specific minimum lengths and optional zero-output pre-warming [S11]. Cold concurrent requests need not all benefit from the first write; startup cache warmth is not assumed.

Google's Interactions API documents implicit caching, not the explicit cache-object interface [S12]. A future adapter cannot claim hard no-cache support from the absence of explicit cache directives; an unsupported or unverified hard constraint is rejected.

**R-CACHE-11** Optional pre-warming MUST use a declared adapter capability, a bounded non-sensitive prefix and journaled usage without blocking readiness or becoming a required recurring background service.

A profile may use supported `max_tokens: 0` pre-warming where verified. Unsupported endpoints do not receive invented parameters. Cache-write charges and uncertain warm-up outcomes are recorded even when no text is generated.

### 12.4 Optional infrastructure caching

**R-CACHE-12** Optional KB-result cache keys MUST include query/context identity, authorization scope, filters and available corpus revision, with an explicit TTL/invalidation policy.

**R-CACHE-13** The KB cache MUST be bypassed when freshness or authorization equivalence cannot be established.

**R-CACHE-14** Optional cache failures MUST degrade to uncached operation within the original resource/deadline limits.

Complete-answer and semantic caching are not enabled in the pilot. Idempotent replay of one completed logical request is durable request recovery, not an answer cache shared across questions or users.

## 13. Durable usage, provenance and cost controls

**R-USAGE-01** Each inference attempt, including intent/evidence decisions, summaries, generation, retries and pre-warming, MUST have a durable uniquely keyed usage record.

**R-USAGE-02** Usage records MUST distinguish `reported`, `estimated` and `unknown` values and MUST NOT convert missing usage or uncertain billing to zero.

**R-USAGE-03** Normalization MUST preserve provider field semantics and prevent double-counting cached input.

For the applicable OpenAI profile, total input already includes reported cache-read/write subsets. For Anthropic's documented convention, uncached input, cache creation and cache reads are separate categories whose sum gives input processed [S10, S11]. TypeSafe's reviewed schema reports billable input and output usage, with output currently described as free; price assumptions remain versioned configuration rather than permanent constants [S4]. Unsupported fields remain unknown.

**R-USAGE-04** Operational provenance MUST record configured/returned model IDs, endpoint profile, prompt/question/policy versions, summary coverage, KB revision and normalized decision verdicts/probabilities where reported.

**R-USAGE-05** Content-bearing provenance and saved stage outputs MUST have access, encryption and deletion protections equivalent to conversation data.

**R-USAGE-06** Estimated cost MUST use a dated price profile and separately show reported charges, estimates and unresolved possible charges.

**R-USAGE-07** The service MUST enforce configured per-attempt call/output budgets, including optional retries and summaries, before dispatching another paid operation.

The default domain attempt permits one intent call, one evidence-assessment call, at most two summary calls and one generation call. An opted-in uncertain retry adds at most one call across the whole attempt, not one per stage. Shared endpoint/account rate limits still apply. Real-price ceilings, if enabled, require complete price profiles; unknown pricing cannot yield a false monetary guarantee.

**R-USAGE-08** Session deletion MUST remove linked per-request content/provenance while preserving only approved non-content aggregates that cannot link back to the deleted conversation.

Aggregates can include date, provider/model, token totals and cost estimates; they exclude request/session IDs, subject IDs, prompt/evidence hashes and individual probability vectors. Small or identifiable cohorts require aggregation/suppression under the retention policy. Pseudonymous event rows are not automatically anonymous aggregates.

## 14. Errors, deadlines and cancellation

### 14.1 One error format

**R-ERR-01** Every HTTP error MUST use RFC 9457 `application/problem+json` with `type`, `title`, `status`, safe `detail`, `instance`, `code`, `request_id` where known, `request_state` where admitted and `retryable` [S7].

The problem `type` may use `about:blank` for HTTP-defined semantics; the stable application `code` gives the specific condition. `retryable=true` means another attempt with the same logical key may be allowed after the stated condition clears; it never overrides authentication, version or capacity checks. `Retry-After` is a bounded integer-second hint, not a promised completion time.

**R-ERR-02** Error/status mapping MUST follow this catalog, with uncertainty and authoritative commit reconciliation taking precedence over optimistic retry labels.

| HTTP / code | Meaning and request-state rule |
| --- | --- |
| 400 `INVALID_REQUEST`, `UNSUPPORTED_LOCALE` | Invalid schema/field; no claim; correct input before sending. |
| 401 `UNAUTHENTICATED` | Missing/invalid/expired identity; no initial claim, or safe retryable pre-dispatch interruption for admitted work. |
| 403 `RETRIEVAL_SCOPE_FORBIDDEN` | Authorized owner requested impermissible retrieval scope; no paid call. |
| 404 `RESOURCE_NOT_FOUND` | Unknown/deleted/other-owner session, message cursor scope or request; indistinguishable resource response. |
| 409 `IDEMPOTENCY_CONFLICT` | Same key, different semantic input; existing record unchanged. |
| 409 `REQUEST_IN_PROGRESS` | Existing queued/running/committing request; `Retry-After` and status guidance. |
| 409 `STATE_CONFLICT` | Retry execution version changed; saved `failed_final`; new logical decision required. |
| 409 `OUTCOME_UNCERTAIN` | Unreconciled potentially charged dispatch; stored `uncertain`; no silent same-key execution. |
| 409 `SESSION_BUSY` | Delete raced with active/queued/reserved work; no deletion. |
| 409 `SESSION_AUTHORIZATION_CHANGED` | Current trusted authorization differs from protected session snapshot; no history/replay/model access. |
| 413 `REQUEST_TOO_LARGE` | Body size exceeded; no claim. |
| 422 `CONTEXT_LIMIT`, `SESSION_CONTEXT_EXHAUSTED` | Valid input/session cannot fit or make bounded progress; saved `failed_final`. |
| 429 `QUEUE_FULL`, `PRINCIPAL_LIMIT`, `ADMISSION_BUDGET_EXCEEDED` | Rejected before claim; `Retry-After`; same ID may be submitted later. |
| 502 `KB_INVALID`, `DECISION_INVALID`, `GENERATION_INVALID`, `CITATION_INVALID`, `GENERATION_TRUNCATED` | Known invalid upstream result; saved `failed_final`; no partial conversation. |
| 503 `KB_UNAVAILABLE`, `DECISION_UNAVAILABLE`, `LLM_UNAVAILABLE`, `UPSTREAM_RATE_LIMITED` | Retryable only with proven safe resume/rejection; otherwise `OUTCOME_UNCERTAIN` semantics apply. |
| 503 `STORE_UNAVAILABLE`, `WRITER_UNAVAILABLE`, `SERVICE_DRAINING` | No admission or safely journaled interruption; unresolved commit status is reconciled, never guessed. |
| 503 `MODEL_PROFILE_MISMATCH` | Unapproved model/capability drift; no successful turn; operator action required. |
| 503 `CONTEXT_PREPARING` | Coverage advanced but more catch-up is needed; `retryable` only under Section 11's progress rule. |
| 504 `QUEUE_TIMEOUT`, `START_BUDGET_EXHAUSTED` | No execution/paid side effect; stored `retryable`. |
| 504 `DEPENDENCY_TIMEOUT`, `REQUEST_DEADLINE` | Safe retryable only before unresolved dispatch or with fully reusable results; otherwise return/report `OUTCOME_UNCERTAIN`. |
| 500 `INTERNAL_ERROR` | Safe generic problem; request state follows journal evidence, not the status alone. |

A client disconnect has no invented HTTP success/error delivery. Its state and `CLIENT_DISCONNECTED` diagnostic appear in the journal/status response. A valid provider refusal is a 200 controlled conversational outcome, not an infrastructure error.

**R-ERR-03** Same-key replay of a completed response or final problem MUST preserve the original application outcome and add `Idempotent-Replayed: true`.

### 14.2 One bounded timeout chain

**R-TIME-01** Every attempt MUST have an absolute 180-second total deadline starting at handler entry, a 60-second pre-execution queue cap and a reserved five-second finalization budget.

**R-TIME-02** Before each stage the service MUST verify that its capped execution plus required remaining stages/finalization can fit the remaining deadline.

**R-TIME-03** KB, decision, summary, generation, storage and provider-capacity waits MUST use cancellable bounded contexts rather than independent unbounded deadlines.

Default dependency caps are KB 10 seconds, each decision call 10 seconds, each summary call 25 seconds, generation 60 seconds and finalization five seconds. These are caps within one absolute budget, not cumulative entitlements. A cold domain path with two summaries fits within the 180-second budget only when actual queue/stage times permit it; the start guard and stage guards decide before dispatch.

**R-TIME-04** Caller cancellation MUST remove waiting work and propagate to in-flight calls without being interpreted as evidence that provider work or billing was undone.

Go cancels an incoming request context on connection closure or request cancellation [S9]. The external outcome still depends on actual dispatch/result evidence.

**R-TIME-05** Once commit has begun, a detached finalization/reconciliation context MAY outlive the HTTP connection by at most five seconds while retaining the active/session slot until its outcome is resolved.

**R-TIME-06** SDK backoff/retries MUST respect remaining absolute time, configured attempt limits, applicable upstream retry hints and jitter, without retrying authentication/schema errors.

### 14.3 Dependency isolation and deployment alignment

**R-TIME-07** Each dependency/account MUST have bounded in-flight and rate-limit controls shared across all roles using that account.

Decision intent/evidence, summaries and generation do not bypass limits through separate clients. These limits are independently configurable from the 100-turn scheduler. An endpoint's throttling consumes active-turn time and informs admission estimates.

**R-TIME-08** Gateway/load-balancer timeouts MUST be at least the service deadline plus possible finalization overrun and transport margin; the pilot value is 200 seconds.

**R-TIME-09** The HTTP server MUST configure `ReadHeaderTimeout=5s`, bounded body reads and a `WriteTimeout` of at least 200 seconds for this deployment profile.

**R-TIME-10** Graceful shutdown MUST stop admission, fail readiness, safely remove queued work and drain active work for at most 185 seconds before releasing writer ownership.

**R-TIME-11** Deployment termination grace MUST cover pre-stop work plus drain and a safety margin; the supplied pilot value is 200 seconds with pre-stop at most five seconds.

Kubernetes documents grace-period and pre-stop interactions; defaults are not sufficient evidence that this application's drain contract is met [S16]. Forced termination remains recoverable through the journal but cannot guarantee completion of every active response.

## 15. Security, data processing and authorization changes

### 15.1 Content and credential protection

**R-SEC-01** Network calls carrying private content MUST use authenticated encrypted transport to configured, allowlisted endpoints, except explicit isolated local test connections.

**R-SEC-02** Secrets MUST be supplied through approved runtime secret mechanisms and MUST NOT enter Git, prompts, public responses, fixtures or logs.

**R-SEC-03** Conversation and content-bearing journal storage MUST use an approved at-rest encryption and restricted-access configuration.

**R-SEC-04** Logs and metrics MUST exclude raw tokens, full transcripts, KB passages and sensitive prompt content by default.

**R-SEC-05** Input, output, journal and diagnostic handling MUST enforce byte/count limits and sanitize untrusted source metadata without fetching arbitrary source URLs.

A citation URL is provenance supplied by an authorized KB, not permission for server-side fetching. Renderers consuming this API also need their own safe link/markup handling.

### 15.2 Current identity versus historical authorization

**R-SEC-06** The session MUST store an authorization fingerprint of trusted owner, normalized roles, retrieval scope and available authorization revision.

**R-SEC-07** A changed trusted fingerprint MUST block historical content, replay and model-context reuse with `SESSION_AUTHORIZATION_CHANGED`, while still permitting authorized deletion.

**R-SEC-08** A deployment MUST document whether historical answers are snapshots of formerly authorized evidence or require current document-level reauthorization.

The pilot does not implement retroactive document-level redaction of every historical answer, summary and replay. Blocking changed roles/revisions catches signalled changes, not an ACL change the KB/issuer does not expose. A previously permitted passage can remain in old conversation content when the trusted authorization fingerprint stays unchanged. Synthetic-data pilot use can accept this limitation explicitly. Sensitive production use requires either reliable authorization-revision propagation and invalidation or a separately approved historical-access policy; it is not silently treated as solved by fresh retrieval.

**R-SEC-09** A release that requires immediate historical revocation MUST remain blocked until its identity/KB contract can enforce that requirement.

### 15.3 Data-processing and transfer profile

**R-PRIV-01** Before real personal/confidential data is enabled, the deployment MUST have an approved data-classification and processor inventory covering KB, decision, generation, summarization, storage, logs and cache providers.

**R-PRIV-02** The inventory MUST record data categories/purposes, processing and storage locations, subprocessors where relevant, retention/deletion settings, training-use terms and the permitted deployment classification.

**R-PRIV-03** The responsible privacy/legal owner MUST approve the applicable processing and international-transfer basis, including KVKK Article 9 and GDPR Chapter V where relevant, before such transfers are enabled [S14, S15].

Whether a transfer is cross-border depends on actual locations and processing arrangements, not the word “API.” Hosting only the LLM locally does not eliminate transfers to a remote decision or summary service. These requirements are release controls, not a legal determination that any provider is compliant.

**R-PRIV-04** The adapter/deployment profile MUST separately verify prompt-cache behaviour, application-state storage and provider logging/retention instead of equating `store=false` or no explicit cache with zero retention.

OpenAI distinguishes application state, monitoring logs, account controls and endpoint-specific retention [S13]. A short cache TTL is not necessarily a maximum retention guarantee. Other providers require their own documented evidence; this project does not infer TypeSafe retention from another provider's terms.

**R-PRIV-05** When a required data-location or retention property is unknown or unsupported, real-data activation MUST fail closed while isolated synthetic tests may remain available.

## 16. Deletion, retention and lifecycle races

**R-DELETE-01** Session deletion MUST use the same per-session lifecycle/admission synchronization as request creation and execution.

**R-DELETE-02** Deletion MUST return 409 `SESSION_BUSY` while any accepted active, queued, committing or admission-reserved work exists for the session.

**R-DELETE-03** For an inactive session, deletion MUST first atomically tombstone it so concurrent admission, summary writes and turn commits cannot resurrect it.

**R-DELETE-04** Successful 204 deletion MUST remove live transcript, summaries, metadata, request results and linked content-bearing stage/provenance records, with optional local caches invalidated.

If purge fails after tombstoning, the session remains unavailable for chat and reads. An authorized repeated DELETE or startup purge-recovery operation can finish the cleanup; it does not reactivate the session. Backup expiry and provider-side deletion are separate documented controls, not implied by live-store 204.

**R-DELETE-05** Session IDs MUST be server-generated UUIDs with cryptographic randomness and checked against a durable reserved-ID registry before allocation.

**R-DELETE-06** The registry MUST retain a protected digest of allocated/deleted IDs so the implementation does not rely only on collision probability when promising non-reuse.

The registry contains no conversation, owner or content fields after completed purge. Digest-key/version migration preserves non-reuse checks. This minimal anti-reuse record still belongs in the data inventory; hashing alone is not asserted to anonymize all data.

**R-DELETE-07** Retention cleanup MUST use the same busy checks and tombstone/purge semantics as explicit deletion.

**R-DELETE-08** Real-data deployment MUST explicitly configure inactivity retention, backup retention, deletion processing and any legally required exceptions before readiness permits real-data use.

The synthetic pilot may explicitly set automatic expiry to disabled; no production retention period is fabricated here. Status polling and duplicate replays do not indefinitely extend retention unless the approved retention policy explicitly says so.

**R-DELETE-09** Startup recovery MUST finish interrupted tombstone purges without reintroducing removed request keys or leaking deleted content into summaries or model calls.

**R-DELETE-10** New content/status reads after tombstoning MUST return 404, with authorized DELETE recovery handled separately from ordinary content access.

## 17. Configuration and operational observability

### 17.1 Engineering defaults

**R-CONFIG-01** The service MUST implement the following named defaults and validate their combined consistency at startup.

| Setting | Initial value or selected rule |
| --- | --- |
| Repository / process name | `chat-orchestrator` |
| Intended active writers | 1, enforced by PostgreSQL ownership and epoch fencing |
| `max_active_requests` | 100 |
| `max_queued_requests` | 100, including same-session waits |
| `max_queued_per_session` | 2 |
| `max_active_per_principal` / `max_queued_per_principal` | 10 / 10 |
| Session creation / retained sessions per principal | 30 per minute, burst 10 / 1,000 |
| `max_queue_wait` / `request_deadline` | 60 seconds / 180 seconds |
| `minimum_start_budget` / `finalization_budget` | 60 seconds / 5 seconds |
| Cold admission duration estimate | 30 seconds per turn; conservative observed update |
| Dependency caps | KB 10s; each decision 10s; each summary 25s; generation 60s |
| `max_summary_calls_per_attempt` | 2 |
| `max_uncertain_model_retries` | 0; permitted configured values 0 or 1 |
| HTTP body / question / chat-response limits | 32 KiB / 8 KiB / 64 KiB |
| Maximum normalized KB items | 8; total evidence bytes/tokens additionally profile-bounded |
| Summary text limit | 4 KiB and tighter applicable role token cap |
| History page size | 50 default; 100 maximum |
| Supported locales / default locale | `tr-TR`, `en-US` / `tr-TR` |
| Gateway / server write timeout | 200s / at least 200s |
| Header read timeout | 5s; body read timeout bounded to 10s |
| Drain / termination grace | 185s / 200s with pre-stop <= 5s |
| Native cache intent | `prefer_reuse`, subject to approved privacy/capability profile |
| Pre-warm / generic KB cache / full-response cache | Disabled / optional disabled / deferred |
| Live external tests | Opt-in, separate from Gate A |
| Production retention and prices | Explicit approved configuration; no assumed legal period or current price |

These are initial engineering choices, not production capacity measurements. Increasing one limit requires revalidating queue delay, provider quotas, database connections, memory, HTTP timeout chain and model budgets. The 100-concurrency acceptance workload uses enough distinct principals to respect the default principal cap; a single-principal test can explicitly override its cap.

**R-CONFIG-02** Provider endpoints, credentials, model profiles, protocol versions, limits, policies and storage configuration MUST be runtime/configuration artifacts rather than scattered business-logic constants.

**R-CONFIG-03** Startup MUST reject incompatible deadlines, missing model caps, invalid threshold orderings, unknown mandatory capabilities and incomplete non-synthetic privacy/authentication profiles.

**R-CONFIG-04** Toolchain, dependencies, database image and fixture versions MUST be pinned in reproducible project artifacts rather than obtained through unpinned downloads during the gate.

### 17.2 Diagnostics and health

**R-OBS-01** Structured lifecycle logs MUST make request/attempt state, admission sequence, conversation version, writer epoch, stage timing, decision action and error category diagnosable without raw content.

**R-OBS-02** Metrics MUST cover active/waiting work, admission rejections, queue delay, principal saturation, dependency rate limits, summary progress, retries, usage uncertainty and cache reads/writes using bounded-cardinality labels.

**R-OBS-03** Request IDs, session IDs and individual subject IDs MUST NOT be metric label values.

**R-OBS-04** Readiness MUST require valid configuration, usable store, current writer ownership and completed relevant recovery without making paid model calls on probes.

**R-OBS-05** Transient queue saturation MUST produce admission errors/metrics rather than independently make the entire service unready.

**R-OBS-06** A dependency or model-profile drift alert MUST identify the affected endpoint/profile without exposing keys or private prompt content.

## 18. Deterministic acceptance and traceability

### 18.1 Test environment

**R-TEST-01** Gate A MUST execute without outbound internet, production credentials or hidden paid API calls, while allowing loopback test infrastructure.

**R-TEST-02** Core tests MUST use deterministic fakes, protocol tests MUST use local HTTP fixtures, and persistence/ownership tests MUST use real locally provisioned PostgreSQL.

**R-TEST-03** Concurrency and timeout tests MUST use barriers, observable states and controlled clocks where practical rather than depend only on sleeps.

**R-TEST-04** Gate preparation MUST supply vendored modules or an equivalently sealed dependency cache, a pinned Go toolchain, cgo, a suitable C compiler and a preloaded PostgreSQL image or local instance.

Go's race detector requires cgo and, on the selected Linux test platform, a C compiler [S17]. Provisioning can use the network before the offline boundary; gate execution cannot silently pull modules/images. `go mod vendor` is the selected dependency preparation path unless a documented sealed alternative is tested.

**R-TEST-05** The required gate MUST include formatting, compilation, `go vet`, unit/contract/store/e2e tests and race detection with failures propagated to its exit status.

```sh
# Executed inside a pre-provisioned, network-restricted test environment.
set -euo pipefail
export GOTOOLCHAIN=local
export GOPROXY=off
export GOSUMDB=off
export GOFLAGS=-mod=vendor
export CGO_ENABLED=1

format_report=$(mktemp)
trap 'rm -f "$format_report"' EXIT
git ls-files -z -- '*.go' ':!:vendor/**' |
  xargs -0 -r gofmt -l >"$format_report"
test ! -s "$format_report"
go build ./...
go vet ./...
go test ./...
go test -race ./...
```

The repository's gate script handles checked file enumeration and local database lifecycle robustly. A formatting check includes generated Go files where tracked, but not vendored third-party code. Missing prerequisites or skipped mandatory tests fail as setup/test failures; neither is a passing result.

### 18.2 Acceptance families

**R-TEST-06** The implementation MUST satisfy every applicable acceptance family below, with named subtests for individual normative requirements.

| ID | Required proof |
| --- | --- |
| A01 | Normal domain turn: history load, intent, authorized KB, three decisions, generation, citation validation and one atomic committed response. |
| A02 | Process restart preserves transcript/version and a contextual follow-up uses the prior referent; cold cache does not change continuity. |
| A03 | Budgeted summary checkpoints preserve transcript, coverage and provenance; generation failure does not discard already paid summary progress. |
| A04 | Barrier test reaches 100 active eligible sessions, never 101; the 101st starts only after release; idle sessions consume no slots. |
| A05 | Server admission FIFO within sessions; A2 waiting behind A1 cannot block B1; ready-session tail reinsertion and principal-cap skipping preserve progress. |
| A06 | Global/session/principal queue bounds, estimated-start rejection, start guard and queue expiry; no claim for pre-admission overload and no downstream call for cancelled waiters. |
| A07 | Concurrent same-key claims, completed replay, changed-payload conflict, semantic fingerprint and retained-key behaviour. |
| A08 | Crashes before marker, between marker/send, after provider response and before result save, and after final commit; recovery uses evidence and never silently replays an uncertain call. |
| A09 | Atomic user/assistant/request/version commit; version collision; lost commit acknowledgement; saved-result reconciliation without regeneration. |
| A10 | Every policy-table row, contradictory judgments, empty evidence, exact probability boundaries and malformed-decision precedence. |
| A11 | Jev wire mapping, required model, answer-name/type/range validation, Noul without confidence, labelled derived metrics and returned-model drift. |
| A12 | Anthropic and OpenAI-compatible adapters pass shared conformance; unsupported mandatory capabilities fail without core changes. |
| A13 | Native cache request mapping; byte-identical reusable prefix across restarts; partial invalidation on summary update; misses/expiry and optional pre-warm limits. |
| A14 | Durable usage for Jev intent/evidence, summary, generation, retries and pre-warm; provider-specific read/write accounting and unknown usage. |
| A15 | Dependency bulkheads, 429s, retry-layer limits, cancellation, deadlines and resource release at every stage, including finalization. |
| A16 | JWT validation and renewal; same-owner/other-owner separation; 404 indistinguishability; changed authorization blocks history/status/replay/context. |
| A17 | Ordered bounded pagination; cursor scope; active DELETE 409; admission/delete/checkpoint races; interrupted purge recovery and ID non-reuse. |
| A18 | Two-process startup and old-owner recovery isolation; advisory-lock loss; stale epoch mutation; control-row check/write race; no model call from non-owner. |
| A19 | Real PostgreSQL migrations, conformance, restart persistence, transaction failure and documented backup/restore drill. |
| A20 | Offline gate from prepared dependencies; missing compiler/image/module fails; no hidden test skips, network access or committed credentials. |
| A21 | OpenAPI and error-envelope compliance; 400/401/403/404/409/413/422/429/502/503/504 paths, size bounds, saved problems and replay headers. |
| A22 | Cancelled/expired pre-dispatch attempts retry with the same ID; execution-time version guard rejects A1 after A2 commits; first-attempt FIFO is not incorrectly version-rejected. |
| A23 | Uncertain retry disabled/enabled (0/1); no retry after disconnect/restart; one total extra call; reusable-stage identity checks and possible duplicate-charge ledger. |
| A24 | Historical backlog exceeds summarizer window; chunked catch-up makes durable progress; same-key continuation succeeds; no-progress state returns terminal context error. |
| A25 | Thanks/smalltalk bypasses KB; first-question/meta answer uses transcript; out-of-scope and ambiguous intent have deterministic controlled outcomes. |
| A26 | Fabricated/no citations, cited-subset ordering, wrong-session message references, empty output, length truncation and provider refusal mapping. |
| A27 | Turkish response from English KB evidence, explicit locale precedence, immutable session defaults and authorized metadata/filter narrowing. |
| A28 | Gateway/server/total-deadline alignment; disconnected commit reconciliation; readiness/drain/termination chain and recovery after forced shutdown. |
| A29 | Hard no-cache/no-retention incompatibility fails before dispatch; synthetic versus real-data activation and approved processing-profile checks. |
| A30 | Startup window/byte/threshold/deadline validation for all roles; cache-hit tokens still count; no silent question truncation after model switch. |
| A31 | One subject cannot exhaust all active slots through many sessions; per-principal queue/create/retained-session quotas and bounded admission bookkeeping. |
| A32 | Session deletion removes content-bearing usage/provenance; permitted non-linkable aggregates survive; log redaction and metric-label bounds. |
| A33 | Missing or incompatible KB/identity contract blocks applicable Gate A completion; missing credentials blocks live gates without fake-backed success claims. |
| A34 | Live scripted native-cache reuse records at least one provider-reported positive cache read for each claimed live cache profile; otherwise cache remains unverified. |
| A35 | Quality harness, frozen labelled set, non-abstention baseline, grounding/citation/continuity/locale reports and release thresholds in Section 19. |
| A36 | Complete requirement-to-test mapping, configuration/source pins, delivery evidence and separation of repository bootstrap from product/integration acceptance. |
| A37 | Untrusted KB/summary instructions cannot alter configured endpoint, owner, policy or execute tools; live content-following behaviour is additionally measured in Gate C. |
| A38 | Provider/model/profile change rebuilds context, validates checkpoints and cache identity, respects budgets and never uses a prior provider's session handle as history. |

A34 is live Gate B evidence and A35 includes live Gate C evaluation; their harnesses and failure-reporting are tested offline. A20/A36 validate the gate machinery, not circularly claim the gate passed because a document says so.

### 18.3 Machine-readable coverage

**R-TRACE-01** The repository MUST maintain `docs/tests/traceability.json` with one entry per normative requirement ID and explicit acceptance IDs, named test cases, evidence paths and status.

```json
{
  "document_id": "PSB-CHAT-001",
  "revision": "3.0",
  "requirements": [{
    "id": "R-IDEM-12",
    "acceptance_ids": ["A08", "A23"],
    "test_cases": [],
    "evidence_paths": [],
    "status": "planned"
  }]
}
```

**R-TRACE-02** CI MUST reject duplicate/unknown IDs, unmapped normative requirements, missing mandatory test names and evidence that labels an unexecuted or skipped test as passed.

**R-TRACE-03** Live-gate statuses MUST distinguish `passed`, `failed`, `blocked` and `unverified` from the pre-implementation `planned` state.

**R-TRACE-04** Quality thresholds and acceptance assertions MUST be versioned before evaluation and MUST NOT be weakened after observing failures without an explicit reviewed baseline change.

## 19. Model-quality baseline — Gate C

Software tests alone cannot prove a useful chatbot: returning `cannot_answer` to everything would preserve many safety invariants while failing the product. Gate C evaluates actual configured decision and generation models with reproducible evidence and explicit denominators.

**R-QUAL-01** The project MUST maintain at least 20 calibration cases and 40 separate held-out synthetic evaluation cases with reviewed labels and fixed evidence snapshots.

The held-out set includes at least 16 answerable domain cases (at least eight contextual follow-ups), 12 non-answerable cases split across missing/insufficient/conflicting evidence, four clarification cases, four conversation-meta cases, two smalltalk cases and two out-of-scope cases. At least eight cases overlay adversarial KB/history instructions; Turkish and English each appear in at least 12 cases. At least four session sequences exercise summarization and preserved user constraints.

**R-QUAL-02** Every evaluated case MUST identify expected action, answerability, allowed source/message references, required facts, forbidden unsupported claims and expected locale.

**R-QUAL-03** Gate C MUST use the real selected Jev and LLM profiles, fixed prompt/policy versions and frozen KB evidence, not fake decisions/generation.

Frozen evidence can come from a reproducible KB test corpus or a local protocol-conforming fixture. That choice is recorded; using a fixture does not certify real retrieval quality. Gate B separately exercises the real KB integration.

**R-QUAL-04** The held-out set MUST run twice per release profile, preserving every response/error and reporting per-run and aggregate counts rather than cherry-picking the better run.

**R-QUAL-05** Each run MUST meet the following initial release floors, with errors counted as unsuccessful outcomes rather than removed from denominators.

| Measure | Required initial floor |
| --- | --- |
| Answer rate on labelled answerable domain cases | At least 80%. |
| Correct domain abstention on missing/conflicting/insufficient cases | At least 95%; zero unsupported consequential claims in the annotated critical subset. |
| Citation identifier validity on returned domain answers | 100%. |
| Supported factual claims among generated domain factual claims | At least 95%, with numerator/denominator and reviewed rubric. |
| Correct intent/action on clarification/meta/smalltalk/out-of-scope cases | At least 90% aggregate, with per-category results. |
| Required conversation facts/constraints preserved through summary | At least 90% overall and 100% of annotated critical constraints. |
| Requested response language | At least 95% for generated text; 100% for deterministic templates. |

These are pilot release targets, not statistical guarantees for all real-world conversations. Small denominators and raw failures remain visible. No price/latency win is asserted merely because a cache was enabled.

**R-QUAL-06** Groundedness and summary-fidelity scoring MUST have a documented human-review rubric or audited assessor, with human review of every critical failure and disputed machine score.

**R-QUAL-07** The report MUST show overall abstention, answerable-case errors, confidence/threshold behaviour, latency, usage and unresolved cost alongside quality scores.

**R-QUAL-08** A changed decision model, normalization threshold, core prompt, summary policy or generation model MUST trigger the relevant quality regression before that profile is promoted.

## 20. Contract closure and deployment inputs

### 20.1 Contract freeze before Gate A completion

**R-CONTRACT-01** The integration plan MUST close the following interface inputs before claiming the affected implementation and full Gate A are complete.

| Input | Selected baseline and required closure |
| --- | --- |
| KB wire contract | Actual method/path, schemas, auth/access propagation, corpus/filter mapping, byte/result limits, revision and failure/billing semantics. This is not yet supplied by the source material. |
| Principal transport | The application model and RS256 JWT profile are selected in Section 2; confirm issuer/gateway claim compatibility or approve a concrete mapping, with local signed fixtures. |
| Storage technology | PostgreSQL is selected; pin the version/image, schema/migrations and advisory-lock/fencing profile. This is not an open technology choice. |
| LLM protocols | Anthropic Messages and OpenAI-compatible Chat Completions are selected; pin protocol fixtures/capability schemas. Concrete account models may follow for live verification. |
| Decision input budgets | Select a conservative local test cap and documented estimator now; record missing provider ceilings rather than assume them. |
| Public/API and KB authorization policy | Freeze allowed metadata/filter mapping, historical-access policy and any authorization revision required for real data. |

Work on independent validated modules can continue while a contract is unresolved. An invented KB endpoint, incompatible JWT assumption or untested remote-store transaction is not a substitute for closure.

### 20.2 Environment and live-verification inputs

**R-CONTRACT-02** Gate B/C and real-data activation MUST remain blocked or explicitly unverified for any missing applicable input below.

| Input | Required evidence |
| --- | --- |
| Actual KB location/access | Endpoint, configured corpus, integration credentials, safe test content and protocol acceptance. |
| Jev account/model | Credential delivery, available concrete returned model, approved alias mapping if unavoidable, observed limits/quota/error behaviour and policy profile. |
| Generation/summary models | Real endpoint/model IDs, capability/retention evidence, price profile and test authorization. |
| Second local/hosted LLM integration | Separately provisioned compatible endpoint and model access when live support is claimed; not needed to test its protocol offline. |
| Production identity/storage | Issuer/keys or gateway mapping, database connection/secrets and writer/deploy profile. |
| Privacy and retention | Data categories, approved processors/locations/transfers, retention and historical-access decision. |
| Native caching | Script exceeding the selected cache minimum, repeated within its verified lifetime, and actual reported read evidence. |

**R-CONTRACT-03** Unknown credentials, limits, prices, URLs or returned model IDs MUST NOT be replaced with fabricated production values or claimed live success.

The repository name is fixed as `chat-orchestrator`; the GitHub owner and host-accessible brief location are separate repository-bootstrap inputs, not chat runtime configuration.

## 21. Delivery gates and definition of done

**R-GATE-01** Delivery MUST include source, migrations, all selected adapters, OpenAPI/approved wire contracts, configuration examples, operational/privacy profiles, deterministic fixtures, quality fixtures, traceability and reproducible gate scripts.

**R-GATE-02** Gate A MUST pass all deterministic software/configuration/contract acceptance tests with real local PostgreSQL and pre-provisioned offline dependencies.

**R-GATE-03** Gate B MUST separately exercise the actual KB, pinned Jev profile and at least one real LLM using sanitized reproducible integration evidence.

**R-GATE-04** A live native-cache claim MUST include at least one provider-reported positive cache read from a scripted, eligible repeated-prefix case; otherwise that cache profile remains `unverified`.

An expired or too-short prompt is not a valid cache proof. A no-hit run may leave core integration passed but cannot make caching passed. A separate adapter's live status is recorded independently; passing fake-backed protocol tests is not real-account access.

**R-GATE-05** Gate C MUST meet the frozen model-quality thresholds before the selected model/policy profile is presented as product-ready.

**R-GATE-06** Repository bootstrap/setup verification and external execution of a repository gate MUST be reported separately from product completeness and live integration/quality acceptance.

A bootstrap pilot can validly demonstrate repository setup without implementing the entire service. Conversely, a generated repository or green scaffold does not prove any chat requirement beyond its actual tests. Applicable bootstrap templates and fact/answer records are validated in that workflow, not invented inside the product specification.

**R-GATE-07** The service MUST NOT be marked fully complete when required contracts, durability/safety tests, live cache evidence or quality gates remain blocked, failed or unverified.

The final release package identifies the exact source/configuration/model profiles, Gate A/B/C outcomes, known deployment limitations and evidence locations. It distinguishes an implemented adapter, a verified live integration and an approved data-processing deployment.

## 22. Technical sources

Sources consulted on 2026-10-04. They substantiate external protocol/platform facts; the product rules, chosen profiles, state machine, limits and acceptance thresholds above are project requirements. Pin the tested versions because provider behaviour can change.

[S1] RFC Editor — BCP 14: RFC 2119 and RFC 8174, normative keywords.  
https://www.rfc-editor.org/rfc/rfc2119  
https://www.rfc-editor.org/rfc/rfc8174

[S2] RFC Editor — RFC 7519, JSON Web Token.  
https://www.rfc-editor.org/rfc/rfc7519

[S3] TypeSafe AI — Introduction, primitives and independent typed questions.  
https://docs.typesafe.ai/introduction

[S4] TypeSafe AI — OpenAPI contract, reviewed API version 0.2.0.  
https://api.typesafe.ai/openapi.json

[S5] TypeSafe AI — Confidence, probability and derived Noul metric.  
https://docs.typesafe.ai/confidence

[S6] PostgreSQL — Explicit locking and session advisory locks.  
https://www.postgresql.org/docs/current/explicit-locking.html

[S7] RFC Editor — RFC 9457, Problem Details for HTTP APIs.  
https://www.rfc-editor.org/rfc/rfc9457

[S8] Go — encoding/json, deterministic map ordering and v1/v2 semantics.  
https://pkg.go.dev/encoding/json

[S9] Go — net/http, incoming request context and timeout controls.  
https://pkg.go.dev/net/http

[S10] OpenAI — Prompt caching, model/API controls and token accounting.  
https://developers.openai.com/api/docs/guides/prompt-caching

[S11] Anthropic — Prompt caching, isolation, cache accounting and pre-warming.  
https://platform.claude.com/docs/en/build-with-claude/prompt-caching

[S12] Google AI — Context caching and Interactions API boundary.  
https://ai.google.dev/gemini-api/docs/caching

[S13] OpenAI — Data controls, retention and endpoint-specific properties.  
https://developers.openai.com/api/docs/guides/your-data

[S14] KVKK — International transfers under Article 9 and official standard-contract resources.  
https://www.kvkk.gov.tr/Icerik/2053/Yurtdisina-Aktarim  
https://www.kvkk.gov.tr/Icerik/7929/Standart-Sozlesmeler

[S15] EUR-Lex — Regulation (EU) 2016/679, including processor and international-transfer provisions.  
https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX:32016R0679

[S16] Kubernetes — Pod lifecycle and termination grace behaviour.  
https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/

[S17] Go — Data race detector requirements.  
https://go.dev/doc/articles/race_detector
