# AGENTS.md

## Repository Structure

```
H:/test/
├── pythonBack/     # Flask backend API (port 8880)
└── vue3Model/      # Vue 3 + Vite frontend
```

## Quick Start

### Backend Setup & Run

```bash
cd H:/test/pythonBack
python -m venv .venv
.venv\Scripts\activate  # Windows
pip install -r requirements.txt
python app.py
```

**Database**: MySQL required. Run `init_db.sql` first. Default: `mysql+pymysql://root:root@localhost:3306/contact_mail`

**Environment Variables** (optional, defaults provided in `config.py`):
- `SECRET_KEY`, `JWT_SECRET_KEY`
- `DATABASE_URI`
- `AWS_REGION`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `SES_SENDER_EMAIL` (for AWS SES email)

### Frontend Setup & Run

```bash
cd H:/test/vue3Model
npm install
npm run dev
```

## Architecture Notes

**Backend** (`pythonBack/`):
- Flask app factory pattern in `app.py`
- Blueprints in `routes/`: `auth`, `contacts`, `groups`, `templates`, `email`, `workflow`
- JWT auth via `flask-jwt-extended`
- AWS SES for email sending
- CORS enabled for `/api/*`

**Frontend** (`vue3Model/`):
- Vue 3 + Vite + Pinia + Vue Router
- Element Plus UI
- `@antv/x6` + `@vue-flow/*` for workflow visualization

## API Endpoints

- `/api/auth/*` - Authentication
- `/api/contacts/*` - Contact management
- `/api/groups/*` - Group management  
- `/api/templates/*` - Email templates
- `/api/email/*` - Email sending
- `/api/workflow/*` - Workflow management
