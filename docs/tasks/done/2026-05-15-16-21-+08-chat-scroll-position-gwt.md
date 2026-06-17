# Chat Scroll Position GWT

## Background

The chat message list needs a precise scroll contract for three related cases:
new user messages, assistant streaming updates, and initial entry into a channel
or section with existing history.

Current branch work tried to prevent assistant streaming from repeatedly moving
the viewport, while still focusing the latest user message after sends and
history entry. The expected behavior is more nuanced: sending a message should
make a one-time decision from the current viewport, not from a persistent
"locked" flag or from whether the user ever scrolled earlier. Historical entry
must also be based only on the initial recent batch, not on an assumption that
all history has been loaded.

Chinese message rendering introduces an additional test and UX risk. If the
runtime downloads fonts after the first frame, the message layout can change
after the first scroll calculation, which makes scroll positioning appear
correct in tests but wrong after fonts finish loading. This repository does not
currently show an obvious app-level `google_fonts` or explicit runtime font
loader dependency, so the font-download behavior may come from Flutter web,
CanvasKit, or platform fallback behavior. It should be investigated before it is
treated as part of the scroll fix scope.

## Goals

- Define user-observable scroll behavior before changing implementation code.
- Preserve the user's reading position whenever the current viewport indicates
  the user is still reading older assistant output.
- Anchor new or historical conversation views around the latest relevant user
  message when the send-time viewport indicates the user has already reached
  the end of the current assistant output.
- Treat initial historical entry as a recent-batch problem: the app initially
  loads only the latest 20 messages, and older history is loaded only after user
  scroll/pull actions.
- Avoid relying on every history item being loaded, laid out, or mounted.
- Track Chinese runtime font downloads as a scroll-test risk, but do not treat
  the font pipeline as committed implementation scope until ownership is known.

## Implementation Plan

1. Classify the viewport at the moment of sending.
   - Do not model this as a durable locked/unlocked flag.
   - The decision depends on the viewport at send time.
   - If the current viewport does not show the end of the current assistant
     response, preserve the reading position after the follow-up send.
   - If the user previously scrolled but the current viewport now shows the end
     of the assistant response, anchor the next sent user message near the top
     again.
   - Keep assistant streaming updates from changing the viewport while the
     current viewport is preserving older content.

2. Define the send-message anchoring behavior.
   - When a new conversation starts, or when the send-time viewport shows the
     end of the current assistant response, anchor the newly sent user message
     near the top of the viewport.
   - For long user messages, align so only approximately the final two lines of
     the user message remain visible and the earlier text may be above the
     viewport.
   - When the send-time viewport does not show the end of the current assistant
     response, do not scroll after the follow-up message is sent.

3. Define initial historical entry behavior.
   - On channel switch, section switch, or page refresh restore, load the latest
     20 messages as the initial history batch.
   - Search only that initial batch for the latest user message.
   - If the initial batch contains a user message, anchor the latest user
     message near the top of the viewport and show subsequent assistant, tool,
     and status messages below it.
   - If the initial batch contains no user message, naturally show the end of
     the initial batch without applying user-message top anchoring or extra
     waiting-space offset.

4. Add focused regression coverage.
   - Verify actual message visibility and placement, not only that scroll
     pixels are greater than zero.
   - Cover long user messages, assistant streaming updates, send-time viewport
     preservation for follow-up sends, and initial history batches with and
     without user messages.
   - Include a large-history scenario that proves behavior does not depend on
     all history being loaded or mounted.

5. Investigate Chinese font loading as a risk, not as a committed fix.
   - Identify whether runtime font downloads are caused by app code, Flutter
     web rendering, CanvasKit, or platform fallback behavior.
   - If the cause is controlled by this repository, decide whether to use
     bundled app fonts or platform/system font fallback.
   - If the cause is outside this repository's practical control, keep it as a
     known validation risk and avoid adding it as a hard acceptance criterion
     for the scroll fix.
   - Use Chinese long-message scenarios in visual validation so font-related
     layout shifts are visible even if the font pipeline is not solved here.

6. Update code maps if implementation changes touch feature entry points,
   business logic, tests, or documentation indexes.

## Acceptance Criteria

### GWT 1: New conversation with a short user message

Given the user opens a new conversation with no existing messages  
When the user sends a short user message  
Then the user message is automatically positioned near the top of the viewport  
And the area below it is available for assistant streaming output  
And assistant streaming updates do not repeatedly change the user message
position

### GWT 2: New conversation with a long user message

Given the user opens a new conversation with no existing messages  
When the user sends a long, multi-line user message  
Then the viewport is positioned around that user message  
And earlier text in the message may be above the viewport  
And approximately the final two lines of the message remain visible  
And the area below remains available for assistant streaming output

### GWT 3: Follow-up send when the assistant response end is visible

Given the conversation already has a previous assistant response  
And the end of the current assistant response is visible in the conversation
viewport  
When the user sends a follow-up message  
Then the new user message is automatically positioned near the top of the
viewport  
And long follow-up messages follow the same final-two-lines visibility rule  
And assistant streaming updates do not repeatedly take over the scroll position

### GWT 4: Follow-up send while the assistant response end is not visible

Given the user is reading a previous long assistant response  
And at the moment of sending, the viewport does not show the end of that
assistant response  
When the user sends a follow-up message while reading  
Then the conversation viewport does not automatically scroll to the new user
message  
And the current reading position remains stable  
And subsequent assistant streaming updates do not disturb the current reading
position

### GWT 5: Initial history batch contains at least one user message

Given the user switches channel, switches section, or refreshes into a section  
And the section has existing history  
And the app initially loads the latest 20 messages  
And those 20 messages contain at least one user message  
When the initial history batch finishes loading  
Then the viewport is positioned at the latest user message within that initial
batch  
And that user message is near the top of the viewport  
And the user can see assistant, tool, and status messages that follow that user
message  
And the behavior is the same whether the full history has fewer than 20,
hundreds, or thousands of messages

### GWT 6: Initial history batch contains no user message

Given the user switches channel, switches section, or refreshes into a section  
And the section has existing history  
And the app initially loads the latest 20 messages  
And those 20 messages contain no user message  
When the initial history batch finishes loading  
Then the viewport does not apply user-message top anchoring  
And the viewport naturally shows the end of the initial batch  
And the final assistant, tool, or status message is visible near the bottom of
the viewport  
And no extra waiting-space offset is forced

### GWT 7: Initial batch last round contains many assistant, tool, or status messages

Given the latest 20 loaded messages include a final round started by one user
message  
And that user message is followed by multiple assistant, tool, or status
messages  
When the initial history batch finishes loading  
Then the viewport uses the latest user message in the initial batch as the
anchor  
And it does not treat the latest assistant, tool, or status message as the start
of the final round  
And the user can review the final question and the subsequent execution flow

### GWT 8: Very large history

Given a channel or section has a very large full history, such as hundreds or
thousands of messages  
When the user enters that channel or section  
Then the app initially loads only the latest 20 messages  
And initial positioning is based only on those 20 messages  
And the behavior does not depend on all historical messages being loaded,
rendered, laid out, or mounted  
And older history participates only after the user explicitly scrolls or pulls
to load more

### GWT 9: Assistant streaming updates

Given the viewport has already been positioned by a send-message or initial
history-entry rule  
When assistant output is appended or updated during streaming  
Then the streaming update itself does not trigger a new user-message anchoring
operation  
And changes such as messageId hydration, taskState changes, content deltas, or
tail message field changes do not cause viewport jumps  
And only explicit user actions, such as tapping Jump to latest, may move the
viewport to the latest area while the viewport is preserving older content

### GWT 10: Send-time protection when the assistant response end is not visible

Given the viewport does not show the end of the current assistant response at
the moment a follow-up message is sent  
When follow-up user messages, assistant appends, streaming updates, or tool
status updates occur  
Then the app preserves the user's current reading position  
And it does not automatically pull the viewport back to the latest message area

### GWT 11: User scrolled before but has read through to the assistant response end

Given the user previously scrolled while reading a long assistant response  
And the user later scrolls or reads down until the end of that assistant
response is visible  
When the user sends a follow-up message  
Then the app bases the decision on the current viewport, not on earlier scroll
history  
And the new user message is automatically positioned near the top of the
viewport  
And the long-message final-two-lines visibility rule applies when relevant

### Investigation 1: Chinese runtime font downloads

Given the conversation contains Chinese user and assistant messages  
When the chat screen renders in the target runtime  
Then record whether font packages are downloaded after the first frame  
And identify whether the download is controlled by app code, Flutter web,
CanvasKit, or platform fallback behavior  
And do not require the scroll fix to eliminate this download unless ownership
and a reliable fix are confirmed

## Validation Commands

- `cd apps/mobile_chat_app && flutter test test/message_list_test.dart`
- `cd apps/mobile_chat_app && flutter analyze`
