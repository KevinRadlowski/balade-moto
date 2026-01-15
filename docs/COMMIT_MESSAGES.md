# Messages de Commit - Group Calendar & Advanced Chat

## PHASE 1 - Group Calendar

```
feat(group): add group calendar and ICS export

- Add groupId field to Ride model (backward compatible)
- Add GET /api/groups/:groupId/rides endpoint for calendar view
- Add GET /api/groups/:groupId/calendar.ics endpoint for ICS export
- Extend ics.service to support multiple rides
- Add GroupCalendarRideItem model in Flutter
- Add group calendar screen with month view
- Add ICS export functionality in Flutter
- Auto-associate rides created/selected from group chat

BREAKING CHANGE: None (backward compatible)
```

## PHASE 2 - Mentions

```
feat(chat): add mentions and user suggestions

- Add mention parsing service (parseAndResolveMentions)
- Add mentions field to Message model
- Add GET /api/groups/:groupId/members/suggest endpoint
- Create mention notifications for mentioned users
- Add MentionAutocomplete widget in Flutter
- Add MentionText widget for rendering mentions
- Integrate mentions in chat input and message display

BREAKING CHANGE: None (backward compatible)
```

## PHASE 3 - Threads

```
feat(chat): add threads support

- Add parentMessageId, threadRootId, threadReplyCount to Message model
- Add indexes for efficient thread queries
- Add GET /api/messages/:messageId/thread endpoint
- Update sendMessage to handle thread replies
- Add ThreadScreen in Flutter
- Display thread reply count in message bubble
- Handle thread updates via Socket.io

BREAKING CHANGE: None (backward compatible)
```

## PHASE 4 - Message Pinning

```
feat(chat): add message pinning

- Add pinned, pinnedAt, pinnedBy fields to Message model
- Update togglePin permissions (owner/admin/mod)
- Add GET /api/groups/:groupId/messages/pins endpoint
- Add message-pinned Socket.io event
- Add PinnedMessagesScreen in Flutter
- Add pin icon in ChatHeader
- Update MessageContextMenu with pin/unpin option

BREAKING CHANGE: None (backward compatible)
```

## PHASE 5 - Advanced Search

```
feat(chat): add advanced search filters

- Add text index on Message.contenu for text search
- Add compound indexes for media and poll filtering
- Add GET /api/groups/:groupId/messages/search endpoint
- Support filters: text, media, poll, date range
- Add MessageSearchScreen in Flutter
- Add search icon in ChatHeader
- Implement debounced search with filters

BREAKING CHANGE: None (backward compatible)
```

## PHASE 6 - Moderation

```
feat(mod): add report and mute moderation tools

- Add MessageReport model for message reporting
- Add GroupMute model for user muting
- Add GroupModerationLog model for audit trail
- Add POST /api/groups/:groupId/messages/:messageId/report endpoint
- Add POST /api/groups/:groupId/members/:userId/mute endpoint
- Add POST /api/groups/:groupId/members/:userId/unmute endpoint
- Add GET /api/groups/:groupId/mutes endpoint (mods only)
- Enforce mute in sendMessage (HTTP and Socket.io)
- Add ReportMessageScreen in Flutter
- Add report option in MessageContextMenu
- Add message_reported notification type

BREAKING CHANGE: None (backward compatible)
```

## Tests

```
test(api): add coverage for calendar/chat/moderation

- Add group-calendar-chat.test.js with integration tests
- Test calendar endpoints (rides list, ICS export)
- Test mentions parsing and notifications
- Test thread creation and fetching
- Test message pinning permissions
- Test search filters and pagination
- Test message reporting
- Test user muting and enforcement

BREAKING CHANGE: None
```

## Documentation

```
docs: add QA checklist and commit messages

- Add QA_CHECKLIST_CHAT_CALENDAR.md
- Add COMMIT_MESSAGES.md
- Document all new features and endpoints

BREAKING CHANGE: None
```

