<div align="center">
  
# 🚀 BINDE

### Aplicație mobilă all-in-one pentru chat, învățare, video-uri, shopping, sporturi și jocuri

[![Flutter](https://img.shields.io/badge/Flutter-3.38.7-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev/)
[![Dart](https://img.shields.io/badge/Dart-3.10.7-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev/)
[![Supabase](https://img.shields.io/badge/Supabase-Backend-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)](https://supabase.com/)
[![License](https://img.shields.io/badge/License-MIT-yellow?style=for-the-badge)](LICENSE)

**Versiune actuală: 1.0.0 (MVP)**

[Funcționalități](#-funcționalități) •
[Tehnologii](#-tehnologii-utilizate) •
[Instalare](#-instalare) •
[Structură](#-structura-proiectului) •
[Roadmap](#-roadmap)

</div>

---

## 📱 Despre Proiect

**Binde** este o aplicație mobilă cross-platform (iOS & Android) dezvoltată cu Flutter și Supabase. Aplicația oferă o experiență completă utilizatorilor, combinând multiple funcționalități într-o singură platformă:

- 💬 **Chat** - Comunicare în timp real
- 📚 **Learn** - Platformă educațională cu lecții și cursuri
- 🎬 **Videos** - Feed video cu player integrat
- 🛒 **Shop** - Magazin online cu coș de cumpărături
- ⚽ **Sports** - Știri sportive și streaming live
- 🎮 **Games** - Mini-jocuri și divertisment

---

## ✨ Funcționalități

### 🔐 Autentificare
| Funcționalitate | Status | Descriere |
|-----------------|--------|-----------|
| Login cu Email/Parolă | ✅ Implementat | Autentificare securizată prin Supabase Auth |
| Înregistrare cont nou | ✅ Implementat | Creare cont cu nume, email și parolă |
| Resetare parolă | ✅ Implementat | Trimitere email pentru resetare |
| Logout | ✅ Implementat | Deconectare cu confirmare |
| Sesiune persistentă | ✅ Implementat | Utilizatorul rămâne logat |

### 💬 Chat
| Funcționalitate | Status | Descriere |
|-----------------|--------|-----------|
| Listă conversații | 🔄 În dezvoltare | Vizualizare conversații active |
| Chat 1-la-1 | 🔄 În dezvoltare | Mesaje private între utilizatori |
| Mesaje realtime | 📋 Planificat | Actualizare instantanee cu Supabase Realtime |
| Timestamp & Seen | 📋 Planificat | Ora trimiterii și status citire |

### 📚 Learn
| Funcționalitate | Status | Descriere |
|-----------------|--------|-----------|
| Listă lecții | ✅ Implementat | Afișare lecții din baza de date |
| Filtrare pe categorii | ✅ Implementat | Basics, Features, Shopping, Games |
| Pagină detalii lecție | ✅ Implementat | Conținut complet și durată |
| Pull-to-refresh | ✅ Implementat | Reîncărcare date |

### 🎬 Videos
| Funcționalitate | Status | Descriere |
|-----------------|--------|-----------|
| Feed video | ✅ Implementat | Listă video-uri cu thumbnail |
| Player video | ✅ Implementat | Redare video cu controale complete |
| Filtrare pe categorii | ✅ Implementat | Welcome, Tutorial, News |
| Progress bar | ✅ Implementat | Navigare în video |
| Like/Share | ✅ Implementat | Interacțiuni sociale (UI) |

### 🛒 Shop
| Funcționalitate | Status | Descriere |
|-----------------|--------|-----------|
| Grid produse | ✅ Implementat | Afișare produse în format grid |
| Filtrare pe categorii | ✅ Implementat | Îmbrăcăminte, Accesorii, Genți |
| Pagină detalii produs | ✅ Implementat | Descriere, preț, stoc |
| Coș de cumpărături | ✅ Implementat | Adăugare/eliminare produse |
| Modificare cantități | ✅ Implementat | +/- în coș |
| Checkout mock | ✅ Implementat | Simulare plasare comandă |
| State management | ✅ Implementat | Riverpod pentru coș |

### ⚽ Sports
| Funcționalitate | Status | Descriere |
|-----------------|--------|-----------|
| Tab News | ✅ Implementat | Știri sportive |
| Tab Live | ✅ Implementat | Evenimente live |
| Filtrare pe sport | ✅ Implementat | Fotbal, Formula 1, Tenis |
| Detalii știre | ✅ Implementat | Conținut complet |
| Live streaming | ✅ Implementat | Player video pentru evenimente live |
| Scor live | ✅ Implementat | Afișare scor în timp real |

### 🎮 Games
| Funcționalitate | Status | Descriere |
|-----------------|--------|-----------|
| Listă jocuri | ✅ Implementat | Grid cu jocuri disponibile |
| Filtrare pe categorii | ✅ Implementat | Quiz, Puzzle, Words |
| Pagină detalii | ✅ Implementat | Descriere și status |
| Notificare disponibilitate | ✅ Implementat | Alertă când jocul e gata |
| Jocuri funcționale | 📋 Planificat | Implementare efectivă |

### 👤 Profil
| Funcționalitate | Status | Descriere |
|-----------------|--------|-----------|
| Vizualizare profil | ✅ Implementat | Nume, email, avatar |
| Logout cu confirmare | ✅ Implementat | Dialog de confirmare |
| Editare profil | 📋 Planificat | Modificare date |
| Upload avatar | 📋 Planificat | Poză de profil |

### 🎨 UI/UX
| Funcționalitate | Status | Descriere |
|-----------------|--------|-----------|
| Dark Theme | ✅ Implementat | Temă întunecată |
| Light Theme | ✅ Implementat | Temă luminoasă |
| Tema automată | ✅ Implementat | Preia tema sistemului |
| Toggle temă manual | 📋 Planificat | Selector în setări |
| Material Design 3 | ✅ Implementat | UI modern |
| Responsive | ✅ Implementat | Adaptare la ecran |

---

## 🛠 Tehnologii Utilizate

### Frontend
| Tehnologie | Versiune | Utilizare |
|------------|----------|-----------|
| **Flutter** | 3.38.7 | Framework UI cross-platform |
| **Dart** | 3.10.7 | Limbaj de programare |
| **Riverpod** | Latest | State management |
| **Go Router** | Latest | Navigare |
| **Video Player** | Latest | Redare video |
| **Cached Network Image** | Latest | Cache imagini |

### Backend
| Tehnologie | Utilizare |
|------------|-----------|
| **Supabase** | Backend-as-a-Service |
| **PostgreSQL** | Bază de date |
| **Supabase Auth** | Autentificare |
| **Supabase Storage** | Stocare fișiere |
| **Supabase Realtime** | Actualizări live |

---

## 📱 Capturi de Ecran

### Autentificare
| Login | Register | Reset Password |
|-------|----------|----------------|
| ![Login](screenshots/login.png) | ![Register](screenshots/register.png) | ![Reset](screenshots/reset.png) |

### Secțiuni principale
| Learn | Videos | Shop |
|-------|--------|------|
| ![Learn](screenshots/learn.png) | ![Videos](screenshots/videos.png) | ![Shop](screenshots/shop.png) |

| Sports News | Sports Live | Games |
|-------------|-------------|-------|
| ![Sports News](screenshots/sports_news.png) | ![Sports Live](screenshots/sports_live.png) | ![Games](screenshots/games.png) |

> **Notă:** Adaugă capturile de ecran în folderul `screenshots/`

---

## 🗺 Roadmap

### ✅ Versiunea 1.0.0 (MVP) - Completată
- [x] Setup proiect Flutter + Supabase
- [x] Sistem autentificare complet
- [x] Navigare cu 6 tab-uri
- [x] Secțiunea Learn cu lecții
- [x] Secțiunea Videos cu player
- [x] Secțiunea Shop cu coș
- [x] Secțiunea Sports (News + Live)
- [x] Secțiunea Games (placeholder)
- [x] Profil utilizator (vizualizare)
- [x] Teme Dark/Light (auto)

### 🔄 Versiunea 1.1.0 - În dezvoltare
- [ ] Profil editabil (nume, bio, avatar)
- [ ] Localizare (RO, EN)
- [ ] Toggle temă manual
- [ ] Îmbunătățiri UI/UX

### 📋 Versiunea 1.2.0 - Planificat
- [ ] Chat realtime complet
- [ ] Notificări push
- [ ] Upload media în chat

### 🔮 Versiuni viitoare
- [ ] Jocuri funcționale
- [ ] Plăți reale în Shop
- [ ] Admin panel
- [ ] Grupuri în chat
- [ ] Streaming live real pentru Sports

---

## 📄 Licență

Acest proiect este licențiat sub Licența MIT - vezi fișierul [LICENSE](LICENSE) pentru detalii.

---

## 👨‍💻 Autor

**Alexandru Fistis**

- GitHub: [@alexfistis](https://github.com/alexfistis)

---