# AI System

## Goals
Bangla/English construction assistant, drawing analysis, material estimation assistance and BOQ help. AI is **advisory**, never an authority for measurements or structural safety.

## Provider abstraction
```
abstract class AiProvider {
  Future<AiResponse> complete(AiRequest request, {Duration timeout});
  Stream<AiResponseChunk> stream(AiRequest request);
  bool get supportsImages;
  bool get supportsPdf;
}
```
- Providers are configurable by the user (base URL, model, key entered in app settings). No production secrets in source, no committed keys.
- Default provider is `NullAiProvider` (returns a clear "not configured" message) so the app is fully functional offline.
- Timeouts, malformed JSON, HTTP errors and refusals are normal, handled cases.

## Assistant behaviour
- Explain every calculation step by step with units and assumptions.
- Distinguish `measured`, `estimated`, and `AI_DETECTED` values in prose.
- State uncertainty explicitly; never invent missing inputs — ask for them.
- Include the standard warning for load-bearing/structural topics: estimation only, qualified engineer review required.
- Language: `en` and `bn`; user can switch per conversation.

## Drawing analysis pipeline
1. Input: JPG/JPEG/PNG/PDF. File is read locally; user opts in before any upload.
2. Provider receives image/PDF and a strict JSON schema request (rooms, walls, dimensions, doors, windows, openings, stairs, balcony, labels, boundary, scale, confidence).
3. Response validated against schema; invalid fields dropped with warnings.
4. Draft floor plan is created with every element tagged `AI_DETECTED` or `ESTIMATED` (or `UNCERTAIN` when confidence is low).
5. User edits in the floor plan editor → status becomes `USER_EDITED`; explicit confirmation → `USER_VERIFIED`.
6. Only `USER_VERIFIED`/`USER_EDITED` geometry may be labelled as measured. AI drafts are never silently promoted.

## Status enum
`AI_DETECTED`, `ESTIMATED`, `UNCERTAIN`, `USER_VERIFIED`, `USER_EDITED`.

## Security & privacy
- API key stored via platform secure storage; never logged.
- Raw AI responses stored locally in `ai_analyses` for audit, not sent to third parties.
- Drawing upload requires explicit user action and connectivity; offline analysis queue is only created after consent.

## Tests
Mock provider tests: success, timeout, HTTP 500, invalid JSON, low-confidence values, wrong schema, no-provider case, and verification-status transitions.
