from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware

from app.schemas import AnalyzeRequest, ExitInterviewAnalysis
from app.nlp_processor import analyze_raw_text
from app.yandex_client import call_yandex_gpt
from app.database import init_db, save_interview, get_all_interviews

app = FastAPI(title="HR Exit Engine API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.on_event("startup")
def on_startup():
    init_db()

@app.get("/health")
def health_check():
    return {"status": "ok"}

@app.get("/history")
def get_history():
    try:
        return get_all_interviews()
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/analyze", response_model=ExitInterviewAnalysis)
def analyze_interview(request: AnalyzeRequest):
    try:
        nlp_stats = analyze_raw_text(request.text)
        result = call_yandex_gpt(request.text, nlp_stats)
        save_interview(raw_text=request.text, result_dict=result.model_dump())
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))