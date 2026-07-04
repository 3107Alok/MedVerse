# MedVerse 🩺

AI-powered healthcare platform connecting **Patients**, **Doctors**, **Laboratories**, and **Admins** — built with **Flutter**, **Flask**, **Firebase**, **MongoDB GridFS**, and **Google Gemini AI**.

---

## 🏗️ Architecture

```
[ Flutter App ] ──► [ Flask API ] ──► Firebase Auth (Token Verify)
                                  ──► MongoDB GridFS (File Storage)
                                  ──► Firestore (Profiles & Appointments)
                                  ──► Google Gemini AI (Document Analysis)
```

---

## 🚀 Key Features

### Multi-Role Platform
- **Patient** — Book appointments, upload documents, view reports, AI chatbot
- **Doctor** — Manage appointments, review patient records & lab reports
- **Laboratory** — Upload lab reports for patients
- **Admin** — Verify doctor/lab registrations, platform management

### Smart Booking System
- Doctor appointment & lab test booking with time-slot selection
- Duplicate request blocker (1 active request per doctor/lab per day)
- Status flow: `Pending → Approved → Checked-In → Completed`
- Real-time sync across patient & provider dashboards

### AI-Powered Features
- **MediDoc Analyze** — Classifies & extracts data from prescriptions, lab reports, bills, discharge summaries
- **AI Health Chatbot** — Symptom queries, medicine info, nutrition guidance (Gemini 2.5 Flash)
- Persistent chat sessions with full conversation history

### Secure Document Storage
- All files are stored in **MongoDB GridFS** (not Firestore)
- Token-based API auth (`Bearer <Firebase ID Token>`)
- Doctors can only access patient files if an active appointment exists
- Patients can upload, view, download & delete their own documents

### Premium UI/UX
- Glassmorphism design with light/dark theme support
- Interactive card-first doctor dashboard
- Inline loading spinners & anti-double-click guards
- Collapsible medical history timeline
- Real-time push notifications (FCM)

### Auth & Security
- Firebase Authentication with mandatory email verification
- Role-based access control
- Lazy Firestore document creation (post-verification only)
- Secure password reset flow

---

## 🛠️ Tech Stack

| Layer | Technology |
|-------|-----------|
| Frontend | Flutter (Dart), Google Fonts, Syncfusion PDF Viewer |
| Backend | Python, Flask |
| AI | Google Gemini 2.5 Flash |
| Auth | Firebase Authentication |
| Database | MongoDB Atlas (GridFS), Cloud Firestore |
| Notifications | Firebase Cloud Messaging (FCM) |
| Hosting | Render |

---

## 📂 Project Structure

```
MedVerse/
├── backend/
│   ├── app.py                    # Main Flask server
│   ├── ai_engine.py              # Gemini AI document analyzer
│   ├── firebase_config.py        # Firebase Admin SDK config
│   ├── db.py                     # MongoDB connection
│   ├── routes/
│   │   ├── __init__.py           # Core API routes
│   │   └── storage_routes.py     # GridFS storage endpoints
│   └── services/
│       └── storage_service.py    # GridFS CRUD operations
├── frontend/
│   └── lib/
│       ├── main.dart             # App entry & routing
│       ├── screens/              # Patient, Doctor, Lab, Admin UIs
│       ├── services/             # API & Firebase services
│       ├── widgets/              # Reusable glass components
│       └── theme/                # Glassmorphism & app themes
└── README.md
```

---

## 🔌 API Endpoints

> All routes require `Authorization: Bearer <ID_TOKEN>` header.

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/api/storage/upload` | Upload file (multipart) |
| `GET` | `/api/storage/patient` | Get own documents |
| `GET` | `/api/storage/patient/<id>/documents` | Doctor: view patient docs |
| `GET` | `/api/storage/patient/<id>/lab-reports` | Doctor: view lab reports |
| `GET` | `/api/storage/file/<fileId>` | Download file |
| `DELETE` | `/api/storage/delete/<fileId>` | Delete file |

---

## ⚙️ Setup

### Backend
```bash
cd backend
python -m venv venv
venv\Scripts\activate          # Linux/Mac: source venv/bin/activate
pip install -r requirements.txt
```

Create `backend/.env`:
```env
PORT=5000
MONGO_URI=mongodb+srv://<user>:<pass>@cluster.mongodb.net/
DB_NAME=medverse
FIREBASE_CREDENTIALS_PATH=your-firebase-adminsdk.json
GEMINI_API_KEY=your_gemini_key
```

```bash
python app.py
```

### Frontend
```bash
cd frontend
flutter pub get
```

Update `lib/config/api_config.dart` with your backend URL, then:
```bash
flutter run
```

### Production (Render)
- Store Firebase credentials as Base64 in `FIREBASE_CREDENTIALS_JSON` env var
- Whitelist `0.0.0.0/0` in MongoDB Atlas Network Access
