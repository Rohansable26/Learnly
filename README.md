# Learnly AI 🚀
### Intelligent Adaptive Learning, Live Web Scraping & Multi-Modal RAG Platform

**Learnly** is a cross-platform learning application built with **Flutter 3.x** and an **Agentic Python FastAPI Backend**. It dynamically constructs curriculums grounded in current industry standards, scrapes live web data and academic research to update roadmaps in real time, adapts to each student's preferred format (ChatGPT-style Socratic Tutor, YouTube Masterclasses, Technical Articles, or ArXiv Papers), and verifies topic mastery through adaptive diagnostic quizzes.

---

## 🌟 Key Features

1. **Student-Preferred Multi-Modal Learning**:
   - 💬 **Conversational AI Tutor (Socratic Mode)**: Step-by-step dialogue, thought experiments, interactive code walkthroughs, and conceptual analogies.
   - 🎬 **Video Masterclasses**: Curated YouTube video tutorials with key takeaways, timestamps, and direct link launches.
   - 📄 **Research & Paper Hub**: ArXiv papers, academic abstracts, theoretical intuition, and empirical scaling notes.
   - 📖 **Deep Article & Code Reader**: Comprehensive engineering blog-style deep dives with copyable, syntax-highlighted code.
   - 🤖 **Contextual Doubts Copilot**: RAG assistant grounded in the topic context and cited web resources.

2. **Dynamic Industry-Standard Syllabus Generator**:
   - Decomposes any topic (e.g., *"Production RAG with Graph Databases"*, *"Modern Flutter Clean Architecture"*, *"Agentic Workflows"*) into progressive modules and subtopics.
   - Aligns the curriculum with modern 2025/2026 industry standards and production patterns.

3. **Continuous Web Scraping & Trend Diff Engine**:
   - Background crawler scrapes DuckDuckGo, ArXiv API, and tech publications for new framework releases and emerging paradigms.
   - Proposes syllabus updates with live trend badges without wiping the student's existing progress.

4. **End-of-Topic Adaptive Quizzes & Mastery Verification**:
   - Every module ends with an adaptive quiz testing real-world architectural tradeoffs and code reasoning.
   - Instant scoring with diagnostic AI feedback and remediation recommendations.
   - Gated progression: Passing the quiz unlocks the next module in the roadmap!

---

## 🏗️ Project Architecture

```
d:/Learnly/
├── learnly_app/                     # Flutter Mobile / Cross-Platform Client
│   ├── lib/
│   │   ├── core/theme/              # Modern Neo-Glass Dark Theme (Outfit & Inter fonts)
│   │   ├── core/constants/          # API endpoints & connection config
│   │   ├── models/                  # Syllabus, Module, Subtopic, Lesson, Quiz, Trend models
│   │   ├── services/                # API Client with offline resilient simulation fallback
│   │   ├── providers/               # Riverpod 3 Notifiers (Syllabus, Learning, Quiz)
│   │   ├── features/
│   │   │   ├── home/                # Dashboard, streak tracker, enrolled courses
│   │   │   ├── onboarding/          # Topic creator & learning style selector sheet
│   │   │   ├── syllabus/            # Interactive roadmap with live web sync badges
│   │   │   ├── learning_studio/     # Multi-modal studio (Chat, Video, Paper, Article)
│   │   │   ├── quiz/                # End-of-topic adaptive assessment & diagnostic feedback
│   │   │   └── trends/              # Live Trend Radar sheet
│   │   └── main.dart                # ProviderScope & MaterialApp entry point
│   ├── test/widget_test.dart        # Flutter test suite (Verified passing)
│   └── pubspec.yaml
│
└── backend/                         # FastAPI AI & RAG Backend Engine
    ├── app/
    │   ├── api/endpoints.py         # REST routes for syllabus, lessons, trends, quizzes
    │   ├── agents/                  # Syllabus Architect, Trend Diff, Tutor, Quiz Agents
    │   ├── services/                # Web Scraper (DuckDuckGo, ArXiv, YouTube), Gemini API, RAG
    │   ├── models/schemas.py        # Pydantic models
    │   ├── core/config.py           # Environment settings & LLM configuration
    │   └── main.py                  # FastAPI application with CORS
    ├── run.py                       # Server launcher
    ├── requirements.txt             # Backend dependencies
    └── .env.example                 # Environment configuration template
```

---

## 🚀 Getting Started

### 1. Launching the Backend Engine

1. Navigate to the `backend` folder:
   ```bash
   cd backend
   ```
2. Create and activate a virtual environment (optional but recommended):
   ```bash
   python -m venv venv
   # Windows:
   venv\Scripts\activate
   # macOS/Linux:
   source venv/bin/activate
   ```
3. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```
4. (Optional) Set your Gemini API key:
   - Copy `.env.example` to `.env`
   - Add your key: `GEMINI_API_KEY=your_key_here`
   - *Note: If no API key is provided, the backend seamlessly runs in smart offline simulation mode with realistic data!*
5. Start the server:
   ```bash
   python run.py
   ```
   Interactive Swagger documentation will be available at: `http://localhost:8000/docs`

---

### 2. Running the Flutter App

1. Navigate to the `learnly_app` directory:
   ```bash
   cd learnly_app
   ```
2. Fetch Flutter packages (already resolved):
   ```bash
   flutter pub get
   ```
3. Run the application:
   - **On Android / iOS Simulator**:
     ```bash
     flutter run
     ```
   - **On Chrome (Web)**:
     ```bash
     flutter run -d chrome
     ```
   - **On Windows Desktop**:
     ```bash
     flutter run -d windows
     ```

*Tip: If running on an Android Emulator, the app automatically supports connection via `10.0.2.2:8000` or fallback offline simulation!*
