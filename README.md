# MediNexa - Universal AI Medical Document Analyzer 🩺

MediNexa is a modern, premium healthcare application built with **Flutter** (frontend) and **Flask** (backend). The core feature, **Medoc Analyze**, has been upgraded from a simple prescription reader into a universal medical document analyzer powered by **Google Gemini AI (Gemini 2.5 Flash)**. It automatically classifies uploaded images and presents custom, interactive layouts based on the document type.

---

## 🚀 Key Features

### 1. 🩺 Medoc Analyze
Automatically classifies and parses 5 different types of medical documents:
*   **Prescription:** Extracts doctor details, patient name, date, diagnosis, and fully structured medicines list.
*   **Laboratory Report (Gen-Z Hinglish Style):**
    *   Detects report types (e.g., CBC, LFT, Lipid Profile, Urine Test).
    *   Extracts test parameters, values, reference ranges, and abnormal status flags (`Normal`, `High`, `Low`, `Borderline`, `Unknown`).
    *   **Friendly Tone:** Translates complex parameters into short, conversational Hinglish (Roman Hindi + English) explanations (e.g., `💡 Khoon ki kami indicate karta hai.`).
    *   Displays explanations **only for abnormal parameters** to minimize scrolling.
    *   Presents a consolidated summary, lifestyle recommendations, and doctor advice card at the bottom.
*   **Medical Bill:** Extracts hospital name, billing date, charges breakdown, and total billing amount.
*   **Discharge Summary:** Highlights the patient summary, discharge diagnosis, treatments received, discharge medicines, and follow-up advice.
*   **Unknown Medical Document:** Shows a friendly warning card if the document is not readable or isn't a medical document.

### 2. 💬 AI Health Chatbot
An interactive healthcare chatbot (MediNexa AI) for asking health, lifestyle, medicine safety, and nutritional queries in plain text.

---

## 🛠️ Technology Stack

*   **Frontend:** Flutter, Dart, Google Fonts (Outfit, Inter)
*   **Backend:** Python, Flask, PyTesseract (OCR fallback)
*   **AI Engine:** Google Generative AI (Gemini 2.5 Flash) with deterministic settings (`temperature: 0.2`)
*   **Database:** MongoDB & Firebase integration

---

## 📂 Project Structure

```
MediNexa/
├── backend/                  # Flask Python Server
│   ├── app.py                # Server entry point
│   ├── routes.py             # API route handlers
│   ├── ai_engine.py          # Gemini AI Prompt and logic
│   ├── db.py                 # Database config
│   ├── requirements.txt      # Python dependencies
│   └── venv/                 # Virtual environment
├── frontend/                 # Flutter Application
│   ├── lib/
│   │   ├── main.dart
│   │   ├── models/           # Data models (prescription_model.dart)
│   │   ├── screens/          # UI Screens (prescription_reader_screen.dart)
│   │   └── services/         # API Service layers
│   └── pubspec.yaml          # Flutter dependencies
└── README.md                 # Project documentation
```

---

## ⚙️ Setup & Installation

### 1. Backend Configuration
1. Navigate to the backend directory:
   ```bash
   cd backend
   ```
2. Set up a Python virtual environment:
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```
3. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```
4. Create a `.env` file in the `backend/` folder and add your credentials:
   ```env
   PORT=5000
   MONGO_URI=your_mongodb_connection_string
   FIREBASE_CREDENTIALS_PATH=path/to/firebase-adminsdk.json
   GEMINI_API_KEY=AIzaSy...your_gemini_api_key_here
   ```
5. Start the backend server:
   ```bash
   python app.py
   ```

### 2. Frontend Configuration
1. Navigate to the frontend directory:
   ```bash
   cd ../frontend
   ```
2. Get Flutter packages:
   ```bash
   flutter pub get
   ```
3. Configure the backend API host endpoint in `lib/config/api_config.dart`.
4. Run the application:
   ```bash
   flutter run
   ```

---

## 🔬 Local Testing & Verification
A test validation script is included in the project artifacts to verify JSON schema parsing and fallback parsing mechanisms.
To run the validation test:
```bash
python -m unittest backend/tests/test_analyzer.py  # or run direct scratch scripts
```
