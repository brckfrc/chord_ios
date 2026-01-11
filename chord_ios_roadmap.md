# 🎯 CHORD iOS - FAZ ROADMAP

## 📋 Temel Yapı

- **Repo**: Ayrı repo (`chord-ios`)
- **Backend**: Mevcut .NET API (FAZ 1-6 tamamlandı)
- **Frontend Referans**: React UI (FAZ 4-6 tamamlandı)
- **Platform**: iOS (Flutter), gelecekte Android

---

## 📍 Şu An Neredeyiz

**Son Tamamlanan**: FAZ 7.5 - WebRTC Connection Stability & Friends Feature + Bug Fixes (DM Unread Count & Pending Requests)

**Aktif Çalışılan**: FAZ 10 - UX Polish & Accessibility

**Son Düzeltilen Sorunlar** (2025-01-XX):

- ✅ **DM Unread Count Güncelleme Sorunu ÇÖZÜLDÜ**: 
  - `DMMarkAsRead` SignalR event listener eklendi (MessageProvider, ChatHub'dan)
  - `updateDMUnreadCount()` ve `incrementDMUnreadCount()` metodları DMProvider'a eklendi
  - Yeni DM mesajı geldiğinde unread count otomatik artırılıyor (sadece DM görüntülenmiyorsa)
  - DM açıldığında unread count backend'den gelen event ile güncelleniyor

- ✅ **Pending Friend Requests UI Sorunu ÇÖZÜLDÜ**: 
  - Friend request event listener'ları PresenceHub'a taşındı (ChatHub yerine)
  - `FriendRequestReceived` ve `FriendRequestAccepted` event'leri artık PresenceHub'dan dinleniyor
  - Real-time friend request güncellemeleri çalışıyor
  - Pending requests listesi FriendsHome'da Pending tab'ında görünüyor

**Sıradaki Çözülecek Sorunlar**:

- ⚠️ **Chat Açılınca Emülatör Kapanma Sorunu**: 
  - Chat açılınca emülatör kapanıyor (crash)
  - Log'larda görülen hata: `AutoJoin Error leaving channels: Bad state: Cannot use "ref" after the widget was disposed.`
  - Widget dispose edildikten sonra `ref` kullanılmaya çalışılıyor
  - AutoJoin işlemi sırasında lifecycle yönetimi düzeltilmeli

---

## 🏗️ FAZ 1: PROJE ŞABLONU & TEMEL YAPI

**Durum**: ✅ TAMAMLANDI (2025-01-XX)
**Not**: Isar yerine Hive kullanıldı (Android Gradle uyumluluk sorunu nedeniyle)

**Süre**: ~1 hafta
**Backend Bağımlılığı**: Yok (sadece API base URL)
**Frontend Referans**: Genel yapı

### Görevler

- [x] Flutter proje oluştur (`flutter create chord_ios`)
- [x] Paketler: `dio`, `riverpod`, `go_router`, `flutter_secure_storage`, `signalr_flutter` (veya `signalr_core`) - **signalr_core kullanıldı**
- [x] Local database setup (`hive` veya `isar` - mesajlar, guild listesi cache için) - **Hive kullanıldı**
- [x] Error tracking setup (`sentry_flutter` veya `firebase_crashlytics`) - **Sentry kullanıldı**
- [x] Tema yapılandırması (dark mode, Discord-like colors)
- [x] Navigasyon iskeleti (go_router setup)
- [x] Base widgets (Button, Input, Loading, Toast)
- [x] API client setup (dio interceptor, base URL, error handling)
- [x] Secure storage setup (Keychain için flutter_secure_storage)
- [x] Splash screen eklendi

### Deliverables

✅ Çalışan boş uygulama + temel navigasyon
✅ API client hazır (base URL configurable)
✅ Secure storage hazır
✅ Local database hazır (cache için)
✅ Error tracking aktif

---

## 🏗️ FAZ 2: AUTH UI & ENTEGRASYON

**Durum**: ✅ TAMAMLANDI (2025-01-XX)

**Süre**: ~1 hafta
**Backend Bağımlılığı**: ✅ FAZ 1 tamamlandı (Auth endpoints hazır)
**Frontend Referans**: `Login.tsx`, `Register.tsx`

### Görevler

- [x] Login ekranı (form validation, error handling)
- [x] Register ekranı (form validation)
- [x] Auth repository (login, register, refresh token, getCurrentUser)
- [x] Token yönetimi (secure storage, auto-refresh)
- [x] Protected route wrapper
- [x] Auth state management (Riverpod Provider)
- [x] Auto-login (token varsa otomatik giriş)

### Deliverables

✅ Login/register çalışıyor
✅ Token secure storage'da saklanıyor
✅ Auto-refresh token logic aktif
✅ Protected routes çalışıyor

---

## 🏗️ FAZ 3: GUILD & CHANNEL UI

**Durum**: ✅ TAMAMLANDI (2025-01-XX)
**Not**:

- DM (Direct Messages) yapısı da eklendi (FriendsSidebar, DMView, FriendsLayout). Mock data ile test edilecek.
- Invite modal eklendi (guild header'a invite butonu, mock data ile çalışıyor)
- Empty state handling eklendi (channel olmayan guild için)
- Fetch optimization: `fetchedGuilds` tracking ile sürekli fetch döngüsü önlendi
- Channel sidebar dropdown eklendi (section'ları collapse/expand yapabilme)

**Süre**: ~1 hafta
**Backend Bağımlılığı**: ✅ FAZ 2 tamamlandı (Guild/Channel endpoints hazır)
**Frontend Referans**: `GuildSidebar.tsx`, `ChannelSidebar.tsx`, `MainLayout.tsx`

### Görevler

- [x] MainLayout (GuildSidebar | ChannelSidebar - full screen layout)
- [x] GuildSidebar widget (guild listesi, create guild butonu, home button)
- [x] ChannelSidebar widget (channel listesi, text/voice ayrımı)
- [x] Guild repository (fetchGuilds, createGuild)
- [x] Channel repository (fetchChannels, createChannel)
- [x] CreateGuildModal (Dialog modal with overlay barrier)
- [x] CreateChannelModal (Dialog modal with overlay barrier)
- [x] Navigation logic (guild/channel seçme, full screen transitions)
- [x] Active state styling
- [x] FriendsSidebar widget (DM listesi)
- [x] FriendsHome screen (placeholder)
- [x] DMView screen (placeholder)
- [x] DM repository (fetchDMs, createDM - mock data ile test edilecek)
- [x] DM provider (Riverpod state management)
- [x] FriendsLayout (GuildSidebar + FriendsSidebar - full screen)
- [x] Invite modal (guild invite link oluşturma ve kopyalama - mock data ile)
- [x] Empty state handling (channel olmayan guild için)
- [x] Fetch optimization (fetchedGuilds tracking ile sürekli fetch döngüsü önlendi)
- [x] Channel sidebar dropdown (section'ları collapse/expand yapabilme)

### Deliverables

✅ Guild listesi görünüyor
✅ Channel listesi görünüyor
✅ Guild/channel oluşturma çalışıyor
✅ Navigasyon doğru çalışıyor (full screen transitions)
✅ DM yapısı hazır (UI placeholder, mock data ile test edilecek - backend endpoint'leri bekleniyor)
✅ Invite modal çalışıyor (mock data ile)
✅ Empty state'ler kullanıcı dostu
✅ Fetch döngüsü sorunu çözüldü
✅ Channel sidebar dropdown çalışıyor

---

## 🏗️ FAZ 4: MESSAGING UI & SIGNALR

**Durum**: ✅ TAMAMLANDI (2025-01-XX)
**Not**:

- Temel messaging sistemi hazır. Offline mode ve cache sync logic eklendi.
- Channel type 2 (announcement) enum'u hem backend'de hem frontend'de eklendi ve tamamlandı.
- Ghost message (pending message) özelliği eklendi: Mesaj gönderilirken hemen gösteriliyor (optimistic update), yarı saydam görünüm ve loading indicator ile. SignalR'dan gerçek mesaj geldiğinde pending mesaj gerçek mesajla değiştiriliyor.

**Süre**: ~1.5 hafta
**Backend Bağımlılığı**: ✅ FAZ 3 tamamlandı (Message endpoints + SignalR hazır)
**Frontend Referans**: `ChannelView.tsx`, `MessageList.tsx`, `MessageComposer.tsx`

### Görevler

- [x] SignalR client setup (`signalr_core` package kullanıldı)
- [x] ChatHub connection manager (Riverpod Provider)
- [x] PresenceHub connection manager
- [x] MessageList widget (infinite scroll, pagination)
- [x] MessageItem widget (Discord-like grouping, avatar, timestamp)
- [x] MessageComposer widget (TextField, send button, typing trigger)
- [x] ChannelView page (AppBar + MessageList + Composer)
- [x] SignalR event listeners (ReceiveMessage, MessageEdited, MessageDeleted, UserTyping)
- [x] JoinChannel/LeaveChannel invoke (route değişiminde)
- [x] Typing indicator UI
- [x] Message grouping logic (same user consecutive messages)
- [x] Channel type 2 (announcement) enum düzeltmesi (backend ve frontend'de tamamlandı)
- [x] Offline mode / cache stratejisi (mesajları local DB'ye kaydet, offline'da göster)
- [x] Cache sync logic (online olduğunda sync, conflict resolution)
- [x] Connectivity service (network durumu kontrolü)
- [x] Pending messages queue (offline'da gönderilecek mesajlar)
- [x] Ghost message (pending message) özelliği (optimistic update, yarı saydam görünüm, loading indicator)

### Deliverables

✅ Mesajlar listeleniyor (infinite scroll)
✅ Gerçek zamanlı mesaj gönderme/alma çalışıyor
✅ Edit/delete çalışıyor (SignalR instant updates)
✅ Typing indicator görünüyor
✅ Offline mode çalışıyor (mesajlar cache'leniyor, offline'da görüntüleniyor)
✅ Cache sync logic çalışıyor (online olduğunda otomatik sync)
✅ Pending messages queue çalışıyor (offline'da gönderilen mesajlar online olduğunda gönderiliyor)
✅ Ghost message (pending message) çalışıyor (Discord benzeri, mesaj gönderilirken hemen görünüyor)

---

## 🏗️ FAZ 5: PRESENCE & MEMBER LIST

**Durum**: ✅ TAMAMLANDI (2025-01-XX)

**Süre**: ~1 hafta
**Backend Bağımlılığı**: ✅ FAZ 3 tamamlandı (PresenceHub hazır)
**Frontend Referans**: `MemberList.tsx`, `PresenceHub` events

**Not**:

- PresenceProvider, PresenceHub event listeners, MemberList, StatusUpdateModal tamamlandı
- Tüm user status'ları destekleniyor: Online, Idle, DND, Invisible, Offline
- StatusUpdateModal ile kullanıcılar status değiştirebiliyor (Offline hariç - Invisible zaten offline gibi görünüyor)
- MemberList'te kullanıcılar status'lere göre gruplandırılıyor (Online, Idle, DND tek "ONLINE" kategorisinde, Offline ayrı)
- Status indicator'lar doğru renklerde gösteriliyor (yeşil=online, turuncu=idle, kırmızı=dnd, gri=offline/invisible)
- GuildSidebar'a kullanıcı profil butonu eklendi (avatar'a tıklayınca status değiştirme modal'ı açılıyor)
- PresenceHub event handler'ları backend formatına göre düzeltildi (UserOnline, UserOffline, UserStatusChanged)

### Görevler

- [x] PresenceProvider oluştur (PresenceState, PresenceNotifier, state management)
- [x] PresenceHub event listeners (UserOnline, UserOffline, UserStatusChanged)
- [x] MemberList widget (guild members, online/offline/idle/dnd status)
- [x] UserStatusIndicator widget (renkli badge: green=online, yellow=idle, red=dnd, gray=offline/invisible)
- [x] User status display (Online, Idle, DND, Invisible, Offline)
- [x] StatusUpdateModal (quick status change UI, Offline hariç tüm status'lar destekleniyor)
- [x] PresenceHub başlatma ve listener registration (app startup'ta)
- [x] GuildSidebar'a kullanıcı profil butonu (status değiştirme için)

### Deliverables

✅ Online kullanıcılar görünüyor
✅ Idle, DND, Invisible status'ları destekleniyor
✅ User status güncelleniyor (StatusUpdateModal ile)
✅ MemberList'te kullanıcılar status'lere göre gruplandırılıyor (Online/Idle/DND tek kategoride)
✅ Status indicator'lar doğru renklerde gösteriliyor
✅ GuildSidebar'da kullanıcı profil butonu çalışıyor

---

## 🏗️ FAZ 5.5: MENTIONS & NOTIFICATIONS ⭐

**Durum**: ✅ TAMAMLANDI (2025-01-XX)

**Süre**: ~1-2 gün

**Backend Bağımlılığı**: ✅ TAMAMLANDI (Backend'de mentions API'leri ve SignalR event'leri hazır)
**Frontend Referans**: `MentionsPanel.tsx`, `MessageComposer.tsx` (React frontend'deki implementasyon)

**Not**:

- Backend'de mentions özelliği tamamlandı (MessageMention entity, API endpoints, ChatHub UserMentioned event). Mobil app'te frontend implementasyonu yapıldı.
- Self-mention ignore özelliği eklendi: Kullanıcı kendisini mention edemez (autocomplete'te görünmez) ve kendi mention'ları için notification gösterilmez.

### Görevler

- [x] Mention DTO model (`MessageMentionDto`, `UnreadMentionCountDto`)
- [x] Mentions API client (`getUserMentions`, `getUnreadMentionCount`, `markMentionAsRead`)
- [x] Mentions repository (API çağrıları)
- [x] Mentions provider (Riverpod state management)
- [x] MessageComposer: @ mention autocomplete (guild members listesi, dropdown, self-mention filter)
- [x] MessageItem: Mention highlight (mavi arka plan, @username pattern matching)
- [x] MentionsPanel widget (unread/read mentions listesi, scrollable)
- [x] Badge on user avatar/header (unread mention count)
- [x] ChatHub: UserMentioned event listener (SignalR'dan mention geldiğinde state güncelle, self-mention ignore)
- [x] Click to jump (mention'a tıklayınca ilgili mesaja scroll)
- [x] Local notification (foreground'da mention geldiğinde in-app notification - state-based)

### Deliverables

✅ @mention autocomplete çalışıyor (MessageComposer'da @ yazınca guild members dropdown)
✅ Mention edilen kullanıcıya bildirim gidiyor (SignalR UserMentioned event)
✅ Unread mentions listesi çalışıyor (MentionsPanel widget)
✅ Mention highlight çalışıyor (MessageItem'da @username mavi arka plan)
✅ Badge count çalışıyor (unread mention sayısı gösteriliyor)
✅ Click to jump çalışıyor (mention'a tıklayınca mesaja scroll)
✅ Local notification çalışıyor (foreground'da mention geldiğinde bildirim)

---

## 🏗️ FAZ 6: VOICE CHANNEL UI & WEBRTC TEMEL

**Durum**: ✅ TAMAMLANDI (2025-01-XX)
**Süre**: ~1.5 hafta
**Backend Bağımlılığı**: ✅ FAZ 3 tamamlandı (Voice channel presence hazır)
**Frontend Referans**: `VoiceBar.tsx`, `VoiceChannelUsers.tsx`, `UserProfileBar.tsx`

**Not**:

- Voice channel users list below channels eklendi (Discord benzeri, her voice channel'ın altında kullanıcı listesi)
- Multi-channel participants support eklendi (`participantsByChannel` Map ile tüm channel'lar için participant tracking)
- Real-time updates düzeltildi (`getParticipantsForChannel` metodunda yeni liste kopyası döndürme, Riverpod state detection)
- Voice channel başlığına aktif channel göstergesi eklendi (yeşil renk ile icon ve başlık)
- VoiceBar global visibility eklendi (tüm protected route'larda görünüyor, Friends/DM sayfalarında da)
- Speaking indicators animasyonları eklendi (yeşil border ve background, smooth transitions)
- Channel list watcher eklendi (voice channel'lar değiştiğinde otomatik participant fetch)

### Görevler

- [x] Voice channel UI (join/leave butonları) ✅
- [x] VoiceBar widget (connection status, disconnect button) ✅
- [x] VoiceChannelUsers widget (active participants list) ✅
- [x] ChatHub voice methods (JoinVoiceChannel, LeaveVoiceChannel, UpdateVoiceState) ✅
- [x] Voice channel SignalR events (UserJoinedVoiceChannel, UserLeftVoiceChannel, UserVoiceStateChanged) ✅
- [x] WebRTC temel setup (LiveKit kullanılıyor - `livekit_client` package) ✅
- [x] Voice connection testi (LiveKit room connection) ✅
- [x] **Voice UI Real-Time Updates - Debugging & Fix**:
  - [x] Real-time participant list updates düzeltildi (multi-channel support, `participantsByChannel` Map) ✅
  - [x] Voice activity indicators düzeltildi (speaking indicators - yeşil border/avatar UI'da anlık güncelleniyor) ✅
  - [x] Voice state synchronization düzeltildi (mute/deafen durumları UI'da anlık görünüyor) ✅
  - [x] `VoiceChannelUsers` widget reactive updates düzeltildi (`getParticipantsForChannel` yeni liste döndürüyor) ✅
  - [x] `VoiceBar` widget real-time updates çalışıyor (connection status ve participant count anlık güncelleniyor) ✅
  - [x] SignalR event handler'lar düzeltildi (tüm channel'lar için çalışıyor, `participantsByChannel` güncelleniyor) ✅
  - [x] LiveKit speaking events state'e doğru yansıyor (aktif channel için speaking indicators çalışıyor) ✅
  - [x] Speaking state animasyonları eklendi (smooth transitions, yeşil border ve background) ✅
- [x] Voice channel users list below channels eklendi (her voice channel'ın altında participant listesi) ✅
- [x] Multi-channel participants support eklendi (`participantsByChannel` Map, `fetchAllVoiceChannelParticipants`) ✅
- [x] Voice channel başlığına aktif channel göstergesi eklendi (yeşil renk) ✅
- [x] VoiceBar global visibility eklendi (ProtectedRoute'da, tüm sayfalarda görünüyor) ✅
- [x] Channel list watcher eklendi (voice channel'lar değiştiğinde otomatik participant fetch) ✅
- [x] **Not**: LiveKit kullanılıyor (SignalR üzerinden token alınıyor, LiveKit room'a bağlanılıyor) ✅

### Deliverables

✅ Voice channel UI hazır
✅ Voice channel'a join/leave çalışıyor (presence + LiveKit)
✅ LiveKit room bağlantısı kuruluyor (WebRTC backend)
✅ Voice channel'daki kullanıcılar anlık görünüyor (SignalR event'leri UI'da yansıyor)
✅ Ses aktiviteleri (speaking indicators) anlık güncelleniyor (yeşil border/avatar UI'da görünüyor)
✅ Mute/deafen durumları anlık senkronize oluyor (UI'da görünüyor)
✅ VoiceBar ve VoiceChannelUsers reactive updates çalışıyor (`ref.watch` çalışıyor, state güncellemeleri UI'ya yansıyor)
✅ Voice channel users list below channels çalışıyor (Discord benzeri)
✅ Multi-channel participants support çalışıyor (tüm voice channel'lar için participant tracking)
✅ Voice channel başlığında aktif channel göstergesi çalışıyor (yeşil renk)
✅ VoiceBar global visibility çalışıyor (tüm sayfalarda görünüyor)

---

## 🏗️ FAZ 7: WEBRTC MULTI-USER & MUTE/UNMUTE

**Durum**: ✅ TAMAMLANDI (2025-01-XX)
**Süre**: ~1.5 hafta
**Backend Bağımlılığı**: ✅ FAZ 8 tamamlandı (LiveKit SFU hazır, backend'de voice token endpoint mevcut)
**Frontend Referans**: WebRTC LiveKit logic (FAZ 8'de yapıldı)

**Not**:

- LiveKit SFU mimarisi kullanılıyor (P2P mesh yerine, ölçeklenebilirlik için)
- Backend'de LiveKit token generation hazır (`/api/voice/token` endpoint)
- Temel LiveKit bağlantısı FAZ 6'da tamamlandı
- Mute/unmute temel kontrolleri mevcut, iyileştirme gerekiyor

### Görevler

- [x] Multi-user WebRTC (LiveKit SFU ile 10+ kişi desteği)
- [x] Mute/unmute controls iyileştirme (local audio track enable/disable, UI feedback)
- [x] Deafen controls iyileştirme (remote audio tracks mute, UI feedback)
- [x] Connection retry logic (bağlantı hatası durumunda, exponential backoff)
- [x] Voice room UI (participants grid, mute indicators)
- [x] Background audio handling (iOS background modes)
- [x] Speaking indicators iyileştirme (LiveKit active speakers events)
- [x] Audio quality optimization (bitrate, codec settings)
- [x] Network quality indicators (connection quality UI)
- [ ] Participant video support (camera toggle, video rendering) - Opsiyonel, sonraki faz için

### Deliverables

✅ 10+ kişilik odada stabil ses (LiveKit SFU)
✅ Mute/unmute çalışıyor (iyileştirilmiş UI feedback ile)
✅ Connection retry çalışıyor (exponential backoff ile)
✅ Voice room UI çalışıyor (participants grid view)
✅ Network quality indicators çalışıyor (connection quality UI)
✅ Haptic feedback eklendi (mute/unmute/deafen/disconnect)
✅ Visual feedback iyileştirildi (button animations, toast notifications)
✅ Speaking indicators iyileştirildi (glow effects, smooth animations)

**Detaylı Notlar**:

- **Connection Retry**: Exponential backoff algoritması iyileştirildi (2s, 4s, 8s, 16s, 32s), max retry 5'e çıkarıldı, retry reason tracking eklendi (network, token, livekit, unknown)
- **Haptic Feedback**: Mute/unmute için `lightImpact()`, deafen için `mediumImpact()`, disconnect için `heavyImpact()` eklendi
- **Visual Feedback**: Button animations (`AnimatedContainer`, `AnimatedDefaultTextStyle`), toast notifications (mute/unmute/deafen durumları için)
- **Network Quality**: `ConnectionQuality` enum eklendi (excellent, good, poor, disconnected), VoiceBar'da renkli quality indicator (nokta) gösteriliyor
- **Voice Room UI**: Yeni sayfa eklendi (`voice_room_view.dart`), participants grid layout (2 sütun), VoiceBar'dan tıklanarak açılıyor
- **Speaking Indicators**: Animasyon süresi 300ms'e çıkarıldı, glow effect (`boxShadow`) eklendi, border effect eklendi (speaking durumunda yeşil border)
- **Audio Quality**: LiveKit adaptive streaming zaten aktif, manuel bitrate ayarı API'de mevcut değil (LiveKit otomatik yönetiyor)
- **Background Audio**: Info.plist'te `UIBackgroundModes: audio` zaten mevcut, LiveKit client background audio'yu yönetiyor
- **Bug Fix**: VoiceBar'daki `InkWell` Material widget hatası düzeltildi (`GestureDetector` ile değiştirildi)
- **Connection State Monitoring**: Periyodik connection state check eklendi (2 saniyede bir), disconnect event handling iyileştirildi, otomatik reconnection eklendi
- **Leave Channel Bug Fix**: `leaveVoiceChannel` sırasında disconnect event'lerinin state'i değiştirmesini engellemek için `_isLeavingChannel` flag eklendi

**Bilinen Sorunlar**:

- ⚠️ **WebRTC Connection Stability**: WebRTC peer connection başarısız oluyor (`onConnectionChangeFAILED`), ses gelmiyor. LiveKit room event'leri gelmiyor, manuel reconnection gerekli. Detaylı çözüm planı: `webrtc_audio_fix_&_friends_feature_209fe5ac.plan.md`

---

## 🏗️ FAZ 7.5: WEBRTC CONNECTION STABILITY & FRIENDS FEATURE

**Durum**: ✅ TAMAMLANDI (2025-01-XX)
**Plan**: `webrtc_audio_fix_&_friends_feature_102256e4.plan.md`, `voice_disconnect_ui_fix_&_fetch_loop_fix_9d9fab6b.plan.md`, `voicebar_disconnect_state_fix_dcd1c9c7.plan.md`
**Süre**: ~1 hafta
**Backend Bağımlılığı**: ✅ Friends API'leri hazır (FAZ 9.5 backend'de tamamlandı)

**Not**:

- WebRTC connection stability iyileştirildi (connection state monitoring, otomatik reconnection, audio tracks check)
- VoiceBar disconnect sorunu çözüldü (null değerler doğru set ediliyor, VoiceState.copyWith sorunu giderildi)
- Participant fetch loop sorunu çözüldü (sadece yeni guild'ler eklendiğinde fetch yapılıyor)
- Friends özelliği tamamlandı (repository, provider, UI, SignalR events)
- Aktif arkadaş listesi eklendi (horizontal list, online/idle friends gösterimi, FriendsSidebar header altında)
- Aktif arkadaşa tıklayınca DM açma özelliği eklendi (mevcut DM varsa açılıyor, yoksa yeni DM oluşturuluyor)
- DM oluşturma endpoint düzeltmesi yapıldı (`/DMs/{userId}` → `/dms/users/{userId}`, backend route'u ile uyumlu)
- Error handling iyileştirildi (backend'den gelen error messages gösteriliyor, DioException handling eklendi)
- Türkçe mesajlar İngilizce'ye çevrildi (tüm user-facing mesajlar İngilizce)
- Overflow sorunu düzeltildi (aktif arkadaş listesi container height 80 → 85)
- **DM Unread Count sorunu çözüldü**: `DMMarkAsRead` SignalR event listener eklendi, yeni mesaj geldiğinde unread count otomatik artırılıyor
- **Pending Friend Requests sorunu çözüldü**: Friend request event listener'ları PresenceHub'a taşındı, real-time güncellemeler çalışıyor

### Görevler

- [x] WebRTC connection state monitoring iyileştirmesi (`onConnectionChangeFAILED`/`DISCONNECTED` event handling, periyodik connection check) ✅
- [x] LiveKit room options optimization (reconnection policy, audio track setup) ✅
- [x] Android background audio iyileştirmesi (`FOREGROUND_SERVICE_TYPE_MICROPHONE` permission kontrolü) ✅
- [x] Friends repository oluşturma (API client methods) ✅
- [x] Friends provider oluşturma (FriendsState, FriendsNotifier, SignalR events) ✅
- [x] FriendsHome UI (Add Friend butonu, friends listesi, Online/All/Pending tabs) ✅
- [x] Add Friend modal (username search, friend request gönderme) ✅
- [x] FriendsSidebar güncellemesi (friends provider entegrasyonu) ✅
- [x] VoiceBar disconnect state fix (null değerler doğru set ediliyor, VoiceState instance oluşturma) ✅
- [x] Participant fetch loop fix (sadece yeni guild'ler eklendiğinde fetch, voice channel kontrolü) ✅
- [x] Aktif arkadaş listesi eklendi (horizontal list, online/idle friends, FriendsSidebar header altında) ✅
- [x] Aktif arkadaşa tıklayınca DM açma özelliği eklendi (mevcut DM varsa açılıyor, yoksa yeni DM oluşturuluyor) ✅
- [x] DM oluşturma endpoint düzeltmesi (`/DMs/{userId}` → `/dms/users/{userId}`) ✅
- [x] Error handling iyileştirmesi (backend error messages, DioException handling, debug logging) ✅
- [x] Türkçe mesajlar İngilizce'ye çevrildi (tüm user-facing mesajlar İngilizce) ✅
- [x] Overflow sorunu düzeltildi (aktif arkadaş listesi container height artırıldı) ✅
- [x] DM Unread Count fix: DMMarkAsRead SignalR event listener eklendi (MessageProvider) ✅
- [x] DM Unread Count fix: updateDMUnreadCount ve incrementDMUnreadCount metodları eklendi (DMProvider) ✅
- [x] DM Unread Count fix: DMReceiveMessage handler'ında unread count artırılıyor ✅
- [x] Pending Friend Requests fix: Friend request event listener'ları PresenceHub'a taşındı ✅

### Deliverables

✅ WebRTC connection stability iyileştirildi (connection state monitoring, otomatik reconnection)
✅ Ses geliyor ve stabil çalışıyor
✅ Friends listesi görünüyor
✅ Friend request gönderme/kabul etme çalışıyor
✅ Add Friend butonu çalışıyor
✅ VoiceBar disconnect sonrası doğru şekilde kayboluyor (activeChannelId: null)
✅ Participant fetch döngüsü sorunu çözüldü (sadece yeni guild'ler için fetch)
✅ Aktif arkadaş listesi görünüyor (horizontal list, online/idle friends)
✅ Aktif arkadaşa tıklayınca DM açılıyor (mevcut DM varsa açılıyor, yoksa yeni DM oluşturuluyor)
✅ DM oluşturma endpoint doğru çalışıyor (backend route'u ile uyumlu)
✅ Backend error messages kullanıcıya gösteriliyor (DioException handling)
✅ Tüm mesajlar İngilizce (Türkçe mesajlar kaldırıldı)
✅ Overflow sorunu çözüldü (aktif arkadaş listesi düzgün render ediliyor)
✅ DM unread count real-time güncelleniyor (DMMarkAsRead SignalR event ile)
✅ Yeni DM mesajı geldiğinde unread count otomatik artırılıyor (DM görüntülenmiyorsa)
✅ Friend request event'leri real-time çalışıyor (PresenceHub entegrasyonu)
✅ Pending friend requests UI'da görünüyor ve real-time güncelleniyor

**Son Düzeltilen Sorunlar** (2025-01-XX):

- ✅ **DM Unread Count Güncelleme Sorunu ÇÖZÜLDÜ**: 
  - `DMMarkAsRead` SignalR event listener eklendi (MessageProvider, ChatHub'dan)
  - `updateDMUnreadCount()` ve `incrementDMUnreadCount()` metodları DMProvider'a eklendi
  - Yeni DM mesajı geldiğinde unread count otomatik artırılıyor (sadece DM görüntülenmiyorsa ve mesaj başkasından geliyorsa)
  - DM açıldığında unread count backend'den gelen event ile güncelleniyor

- ✅ **Pending Friend Requests UI Sorunu ÇÖZÜLDÜ**: 
  - Friend request event listener'ları PresenceHub'a taşındı (ChatHub yerine)
  - `FriendRequestReceived` ve `FriendRequestAccepted` event'leri artık PresenceHub'dan dinleniyor
  - Real-time friend request güncellemeleri çalışıyor
  - Pending requests listesi FriendsHome'da Pending tab'ında görünüyor

---

## 🏗️ FAZ 8: FILE UPLOAD & VIDEO SUPPORT

**Durum**: ✅ TAMAMLANDI (2025-01-XX)

**Süre**: ~1 hafta
**Backend Bağımlılığı**: ✅ FAZ 7 tamamlandı (File upload endpoints hazır)
**Frontend Referans**: File upload logic (FAZ 7'de yapıldı)

**Not**:

- Image, video ve document (PDF, Word, Excel, TXT, CSV, ZIP, RAR) upload desteği eklendi
- Video thumbnail aspect ratio düzeltmesi yapıldı (4:3, 16:9, 1:1 gibi farklı aspect ratio'lar doğru gösteriliyor)
- Upload sırasında dosya türüne göre doğru icon gösterimi eklendi (image/video/document)
- Production MinIO URL transform eklendi (reverse proxy path `/uploads` desteği)

### Görevler

- [x] `image_picker` package kurulumu ✅
- [x] `video_player` package kurulumu ✅
- [x] File upload UI (gallery picker, camera) ✅
- [x] Upload API client (multipart/form-data, progress indicator) ✅
- [x] Video thumbnail generation ✅
- [x] Video player widget (inline playback) ✅
- [x] Image viewer (full screen, zoom) ✅
- [x] File size/duration validation ✅
- [x] Upload progress indicator ✅

### Deliverables

✅ Dosya yükleme çalışıyor (image, video, document)
✅ Video inline oynatılıyor
✅ Resim full screen görüntüleniyor
✅ Boyut/süre limitleri kontrol ediliyor (25MB max)
✅ Video thumbnail aspect ratio doğru gösteriliyor
✅ Upload sırasında dosya türüne göre doğru icon gösteriliyor
✅ Production MinIO URL transform çalışıyor

---

## 🏗️ FAZ 9: LOCAL NOTIFICATIONS

**Durum**: ✅ TAMAMLANDI (2025-01-XX)
**Süre**: ~1 hafta
**Backend Bağımlılığı**: ✅ FAZ 5.5 (Mentions) - Backend'de mentions tamamlandı

**Not**:

- Local notifications (foreground) implementasyonu tamamlandı
- `flutter_local_notifications` package kullanılıyor
- Notification preferences sistemi eklendi (channel ve DM için ayrı ayarlar)
- UserSettingsModal'a notifications tab'ı eklendi
- Deep linking çalışıyor (notification tap → route navigation)
- StatusUpdateModal UserSettingsModal'a taşındı (status + notifications birleşik modal)

### Görevler

- [x] `flutter_local_notifications` package kurulumu ✅
- [x] NotificationService oluşturma (initialization, permissions) ✅
- [x] Notification preferences service (SharedPreferences) ✅
- [x] Notification preferences provider (Riverpod) ✅
- [x] Mention notification handler (SignalR UserMentioned event) ✅
- [x] DM notification handler (SignalR DMReceiveMessage event) ✅
- [x] Deep linking (notification tap → route navigation) ✅
- [x] Notification settings UI (UserSettingsModal - Notifications tab) ✅
- [x] StatusUpdateModal → UserSettingsModal'a taşındı ✅

### Deliverables

✅ Local notifications çalışıyor (foreground)
✅ Mention/DM geldiğinde bildirim gösteriliyor
✅ Deep linking çalışıyor (notification tap → ilgili sayfaya yönlendirme)
✅ Notification preferences çalışıyor (channel/DM ayrı ayarlar)
✅ UserSettingsModal çalışıyor (status + notifications birleşik)

---

## 🏗️ FAZ 9.5: PUSH NOTIFICATIONS (FCM/APNs)

**Durum**: ❌ YAPILMAYACAK ŞİMDİLİK
**Süre**: ~1 hafta (gelecekte)
**Backend Bağımlılığı**: ✅ FAZ 5.5 (Mentions) - Backend'de mentions tamamlandı

**Not**:

- Push notifications (FCM/APNs) şimdilik yapılmayacak
- Local notifications (FAZ 9) foreground için yeterli
- Gelecekte backend'de FCM token yönetimi ve push notification endpoint'leri eklendiğinde implement edilebilir

### Görevler (Gelecek)

- [ ] `firebase_messaging` package kurulumu
- [ ] APNs sertifikaları/key'leri yapılandırma
- [ ] Firebase Cloud Messaging (FCM) setup
- [ ] Push notification handler (foreground/background)
- [ ] FCM token yönetimi (backend'e token gönderme)
- [ ] Background notification handling
- [ ] Notification badge count (iOS)
- [ ] Backend entegrasyonu (FCM token endpoint'leri)

### Deliverables

⏳ Push notifications çalışıyor (background)
⏳ App kapalıyken bildirim geliyor
⏳ Badge count güncelleniyor

---

## 🏗️ FAZ 10: UX PARLATMA & ERİŞİLEBİLİRLİK

**Süre**: ~1 hafta

### Görevler

- [ ] Hata durumları (empty states, error screens)
- [ ] Loading states (skeleton screens)
- [ ] Pull-to-refresh
- [ ] Accessibility (VoiceOver, Dynamic Type)
- [ ] Dark mode support (iOS system theme)
- [ ] Haptic feedback
- [ ] Swipe gestures (message delete, channel mute)

### Deliverables

✅ Temel a11y kontrolleri geçer
✅ Hata durumları kullanıcı dostu
✅ Dark mode çalışıyor

---

## 🏗️ FAZ 11: TESTING & PERFORMANCE

**Süre**: ~1 hafta

### Görevler

- [ ] Widget testleri (kritik components)
- [ ] Integration testleri (login → guild → message flow)
- [ ] Performance profiling (Flutter DevTools)
- [ ] Memory leak kontrolü
- [ ] Battery usage optimization
- [ ] Network usage optimization

### Deliverables

✅ Kritik akışlar için otomasyon yeşil
✅ Performance metrikleri kabul edilebilir

---

## 🏗️ FAZ 12: APP STORE HAZIRLIĞI

**Süre**: ~1 hafta

### Görevler

- [ ] App icon & splash screen
- [ ] App Privacy manifest (iOS 17+)
- [ ] Store listing (screenshots, description)
- [ ] TestFlight beta testing
- [ ] Demo video kaydı
- [ ] Dokümantasyon (README, setup guide)

### Deliverables

✅ App Store'a yüklenmeye hazır
✅ TestFlight beta aktif
✅ Demo videosu hazır

---

## 🎯 ÖNCELİK SIRASI

1. **FAZ 1-2**: Temel yapı + Auth (Backend hazır ✅) - ✅ TAMAMLANDI
2. **FAZ 3**: Guild/Channel UI (Backend hazır ✅) - ✅ TAMAMLANDI
3. **FAZ 4**: Messaging + SignalR (Backend hazır ✅) - ✅ TAMAMLANDI
4. **FAZ 5**: Presence (Backend hazır ✅) - ✅ TAMAMLANDI
5. **FAZ 5.5**: Mentions & Notifications (Backend hazır ✅) - ✅ TAMAMLANDI
6. **FAZ 6**: Voice channels + WebRTC temel - ✅ TAMAMLANDI
7. **FAZ 7**: WebRTC Multi-User & Mute/Unmute - ✅ TAMAMLANDI
8. **FAZ 7.5**: WebRTC Connection Stability & Friends Feature + Bug Fixes - ✅ TAMAMLANDI
9. **FAZ 8**: File upload & Video support - ✅ TAMAMLANDI
10. **FAZ 9**: Local Notifications (Backend FAZ 5.5'te mentions tamamlandı ✅) - ✅ TAMAMLANDI
11. **FAZ 9.5**: Push Notifications (FCM/APNs) - ❌ YAPILMAYACAK ŞİMDİLİK
12. **FAZ 10-12**: Polish, testing, store

---

## 📝 BACKEND/Frontend SENKRONİZASYON NOTLARI

**iOS bağımsız yapılabilir:**

- FAZ 1-5.5: Backend hazır ✅
- FAZ 6-7 (WebRTC): iOS önce yapılabilir, backend sonra RtcSignalingHub ekler
- FAZ 8 (File Upload): ✅ TAMAMLANDI (Backend hazır, iOS implementasyonu tamamlandı)

**Backend beklenmesi gereken:**

- FAZ 9 (Local Notifications): Backend'de mentions (FAZ 5.5) hazır olmalı - ✅ TAMAMLANDI
- FAZ 9.5 (Push Notifications): Backend'de FCM token yönetimi ve push notification endpoint'leri gerekli - ❌ YAPILMAYACAK ŞİMDİLİK

**Frontend referans:**

- Tüm UI component'leri React'tan Flutter'a çevrilebilir
- SignalR logic aynı (signalr_flutter veya signalr_core package)
- State management benzer (Riverpod ≈ Redux Toolkit)

---

## 📦 PAKET NOTLARI & ALTERNATİFLER

### SignalR Paketleri

- **Önerilen**: `signalr_flutter` veya `signalr_core` (daha güncel ve aktif)
- **Alternatif**: `signalr_netcore` (eski, daha az bakım)

### Routing Paketleri

- **Önerilen**: `go_router` (Flutter'ın resmi önerisi)
- **Alternatifler**: `auto_route` (code generation), `beamer` (declarative)

### Local Database

- **Kullanılan**: `hive` + `hive_flutter` (Android uyumluluğu için seçildi)
- **Alternatif**: `isar` (daha hızlı ama Android Gradle uyumluluk sorunu var)
- **Not**: İlk implementasyonda Isar denendi ancak Android build hatası (namespace sorunu) nedeniyle Hive'a geçildi. Hive daha basit ve stabil.

### Error Tracking

- **Önerilen**: `sentry_flutter` (kapsamlı, ücretsiz tier mevcut)
- **Alternatif**: `firebase_crashlytics` (Firebase ekosistemi içinde)

### Cache & Offline

- Local database (Isar/Hive) ile mesajlar, guild listesi cache'lenir
- Dio interceptor ile offline request queue (online olduğunda sync)
- Riverpod ile cache state management

### Notification Paketleri

- **Kullanılan**: `flutter_local_notifications` (foreground local notifications için)
- **Not**: FAZ 9'da local notifications implementasyonu tamamlandı. Foreground'da mention ve DM bildirimleri gösteriliyor.
- **Gelecek (FAZ 9.5)**: `firebase_messaging` (push notifications için, şimdilik yapılmayacak)
- **Alternatif**: `awesome_notifications` (daha özellikli ama daha kompleks)
