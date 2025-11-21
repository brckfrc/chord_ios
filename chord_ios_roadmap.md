# 🎯 CHORD iOS - FAZ ROADMAP

## 📋 Temel Yapı

- **Repo**: Ayrı repo (`chord-ios`)
- **Backend**: Mevcut .NET API (FAZ 1-6 tamamlandı)
- **Frontend Referans**: React UI (FAZ 4-6 tamamlandı)
- **Platform**: iOS (Flutter), gelecekte Android

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

**Süre**: ~1 hafta
**Backend Bağımlılığı**: ✅ FAZ 3 tamamlandı (PresenceHub hazır)
**Frontend Referans**: `MemberList.tsx`, `PresenceHub` events

### Görevler

- [ ] PresenceHub event listeners (UserOnline, UserOffline, UserStatusChanged)
- [ ] MemberList widget (guild members, online/offline status)
- [ ] User status display (Online, Idle, DND, Invisible, Offline)
- [ ] Read/unread indicators (badge count)
- [ ] Status update UI (quick status change)

### Deliverables

✅ Online kullanıcılar görünüyor
✅ User status güncelleniyor
✅ Read/unread indicators çalışıyor

---

## 🏗️ FAZ 6: VOICE CHANNEL UI & WEBRTC TEMEL

**Süre**: ~1.5 hafta
**Backend Bağımlılığı**: ✅ FAZ 3 tamamlandı (Voice channel presence hazır)
**Frontend Referans**: `VoiceBar.tsx`, `VoiceChannelUsers.tsx`, `UserProfileBar.tsx`

### Görevler

- [ ] Voice channel UI (join/leave butonları)
- [ ] VoiceBar widget (connection status, disconnect button)
- [ ] VoiceChannelUsers widget (active participants list)
- [ ] ChatHub voice methods (JoinVoiceChannel, LeaveVoiceChannel, UpdateVoiceState)
- [ ] Voice channel SignalR events (UserJoinedVoiceChannel, UserLeftVoiceChannel, UserVoiceStateChanged)
- [ ] `flutter_webrtc` package kurulumu
- [ ] WebRTC temel setup (RTCPeerConnection, local/remote streams)
- [ ] 1-1 P2P bağlantı testi
- [ ] **Not**: Backend RtcSignalingHub hazır değilse, alternatif olarak SignalR üzerinden signaling yapılabilir (geçici çözüm)

### Deliverables

✅ Voice channel UI hazır
✅ Voice channel'a join/leave çalışıyor (presence)
✅ 1-1 WebRTC bağlantı kuruluyor

---

## 🏗️ FAZ 7: WEBRTC MULTI-USER & MUTE/UNMUTE

**Süre**: ~1.5 hafta
**Backend Bağımlılığı**: ⏳ FAZ 8 (RtcSignalingHub) - iOS önce yapılabilir (frontend'teki gibi)
**Frontend Referans**: WebRTC P2P logic (FAZ 8'de yapılacak)

### Görevler

- [ ] Multi-user WebRTC (≤5 kişi, mesh topology)
- [ ] Mute/unmute controls (local audio track enable/disable)
- [ ] Deafen controls (remote audio tracks mute)
- [ ] Connection retry logic (bağlantı hatası durumunda)
- [ ] Voice room UI (participants grid, mute indicators)
- [ ] Background audio handling (iOS background modes)
- [ ] **Alternatif Plan**: Backend RtcSignalingHub hazır değilse, SignalR ChatHub üzerinden signaling implementasyonu (ICE candidates, offers/answers)

### Deliverables

✅ 3-5 kişilik odada stabil ses
✅ Mute/unmute çalışıyor
✅ Connection retry çalışıyor

---

## 🏗️ FAZ 8: FILE UPLOAD & VIDEO SUPPORT

**Süre**: ~1 hafta
**Backend Bağımlılığı**: ⏳ FAZ 7 (File upload endpoints) - iOS önce yapılabilir
**Frontend Referans**: File upload logic (FAZ 7'de yapılacak)

### Görevler

- [ ] `image_picker` package kurulumu
- [ ] `video_player` package kurulumu
- [ ] File upload UI (gallery picker, camera)
- [ ] Upload API client (multipart/form-data, progress indicator)
- [ ] Video thumbnail generation
- [ ] Video player widget (inline playback)
- [ ] Image viewer (full screen, zoom)
- [ ] File size/duration validation
- [ ] Upload progress indicator

### Deliverables

✅ Dosya yükleme çalışıyor
✅ Video inline oynatılıyor
✅ Resim full screen görüntüleniyor
✅ Boyut/süre limitleri kontrol ediliyor

---

## 🏗️ FAZ 9: PUSH NOTIFICATIONS

**Süre**: ~1 hafta
**Backend Bağımlılığı**: ⏳ FAZ 6.5 (Mentions) - iOS önce yapılabilir (genel notifications)
**Frontend Referans**: Browser notifications (FAZ 6.5'te yapılacak)

### Görevler

- [ ] `firebase_messaging` package kurulumu
- [ ] APNs sertifikaları/key'leri yapılandırma
- [ ] Firebase Cloud Messaging (FCM) setup
- [ ] Push notification handler (foreground/background)
- [ ] Notification payload parsing (mention, DM, message)
- [ ] Deep linking (notification'dan channel'a yönlendirme)
- [ ] Notification badge count
- [ ] Notification settings UI (mute/unmute channels)

### Deliverables

✅ Push notifications çalışıyor
✅ Mention/DM geldiğinde bildirim
✅ Deep linking çalışıyor

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
3. **FAZ 4**: Messaging + SignalR (Backend hazır ✅) - ⏳ SIRADA
4. **FAZ 5**: Presence (Backend hazır ✅)
5. **FAZ 6-7**: Voice channels + WebRTC (Backend FAZ 8'de yapılacak, iOS önce başlayabilir)
6. **FAZ 8**: File upload (Backend FAZ 7'de yapılacak, iOS önce başlayabilir)
7. **FAZ 9**: Push notifications (Backend FAZ 6.5'te mentions yapılacak)
8. **FAZ 10-12**: Polish, testing, store

---

## 📝 BACKEND/Frontend SENKRONİZASYON NOTLARI

**iOS bağımsız yapılabilir:**

- FAZ 1-5: Backend hazır ✅
- FAZ 6-7 (WebRTC): iOS önce yapılabilir, backend sonra RtcSignalingHub ekler
- FAZ 8 (File Upload): iOS önce yapılabilir, backend sonra upload endpoints ekler

**Backend beklenmesi gereken:**

- FAZ 9 (Push): Backend'de mentions (FAZ 6.5) hazır olmalı (genel notifications için gerekli değil)

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
